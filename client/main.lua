-- Client-side TV detection, synchronized rendering and remote controls.
local RESOURCE = GetCurrentResourceName()
local PLAYER_URL = ('https://cfx-nui-%s/html/player.html?locale=%s'):format(RESOURCE, Config.Locale)
local TXD = 'scrappydev_tv_txd'
local DUI_W, DUI_H = 1280, 720

local S = {
    dui = nil, duiMode = nil, duiUrl = nil, texName = nil, texCounter = 0, txd = nil,
    duiGen = 0, ready = false,
    active = nil,
    drawing = false,
    streamer = false,
    remoteOpen = false,
    pointer = nil,
    lastVolSent = nil,
    lastSyncedSeq = nil,
    pendingMove = nil, lastMoveSent = 0, flushScheduled = false,
    props = {},
}

local models = {}
for _, m in ipairs(Config.Models) do
    local hash = tonumber(m.model) or joaat(m.model)
    models[#models + 1] = { model = m.model, hash = hash, rt = m.rt, maxdistance = m.maxdistance, controldistance = m.controldistance }
end

local modelCfgByHash = {}
for _, m in ipairs(models) do modelCfgByHash[m.hash] = m end

local function notify(msg, kind)
    ScrappyTV.Framework.Notify(msg, kind)
end

local function nowMs() return GetGameTimer() end

local function sameTV(a, b)
    return a and b and a.model == b.model and #(a.coords - b.coords) < 0.6
end

local function setImmersive(on)
    if not (Config.Pointer and Config.Pointer.hideImmersiveHud) then return end
    ScrappyTV.Framework.SetImmersive(on)
end

local function ensureDui()
    if S.dui then return true end
    S.duiGen = S.duiGen + 1
    S.dui = CreateDui(PLAYER_URL, DUI_W, DUI_H)
    if not S.dui then return false end
    S.txd = S.txd or CreateRuntimeTxd(TXD)
    S.texCounter = S.texCounter + 1
    S.texName = ('tex%d'):format(S.texCounter)
    CreateRuntimeTextureFromDuiHandle(S.txd, S.texName, GetDuiHandle(S.dui))
    S.duiMode, S.duiUrl, S.ready = 'player', PLAYER_URL, false
    return true
end

local function destroyDui()
    if S.dui then DestroyDui(S.dui) end
    S.dui, S.duiMode, S.duiUrl, S.ready, S.lastVolSent, S.lastSyncedSeq = nil, nil, nil, false, nil, nil
end

local function scheduleDuiDestroy()
    local gen = S.duiGen
    SetTimeout(15000, function()
        local off = S.active and S.active.view and S.active.view.on == false
        if S.duiGen == gen and (not S.active or off) and not S.pointer then destroyDui() end
    end)
end

local function duiSend(payload)
    if S.dui then SendDuiMessage(S.dui, json.encode(payload)) end
end

local function setDuiPage(url, mode)
    if not S.dui then return end
    if S.duiUrl ~= url or S.duiMode ~= mode then
        SetDuiUrl(S.dui, url)
        S.duiUrl, S.duiMode = url, mode
        if mode == 'player' then S.ready = false end
    end
end

local function volumeFor(a)
    if S.streamer or not a or not a.view or a.view.muted or a.view.on == false then return 0 end
    local base = a.view.volume or 0
    local d = S.pointer and 0.0 or (a.dist or 0.0)
    local ref = Config.Audio.referenceDistance
    local maxd = (a.info.cfg and a.info.cfg.maxdistance) or 30.0
    local f = 1.0
    if d > ref then
        local t = math.min(1.0, (d - ref) / math.max(1.0, maxd * 0.75 - ref))
        f = (1.0 - t) ^ 2
    end
    if not S.pointer and (a.interior or 0) ~= GetInteriorFromEntity(PlayerPedId()) then
        f = f * Config.Audio.otherRoomFactor
    end
    return math.floor(base * f + 0.5)
end

local function currentPosition(a)
    local v = a.view
    local pos = v.positionMs or 0
    if not v.paused then pos = pos + (nowMs() - (a.recvAt or nowMs())) end
    return pos / 1000.0
end

local function sendVolumeIfChanged(force)
    local a = S.active
    if not a or not a.view or not a.view.url or a.view.kind == 'web' then return end
    local vol = volumeFor(a)
    if force or S.lastVolSent == nil or math.abs(vol - S.lastVolSent) >= 2 or (vol == 0) ~= (S.lastVolSent == 0) then
        S.lastVolSent = vol
        duiSend({ type = 'volume', volume = vol })
    end
end

local function channelList()
    local out = {}
    for i, c in ipairs(Config.Channels or {}) do out[i] = { n = i, name = c.name } end
    return out
end

local function appList()
    local out = {}
    for i, app in ipairs(Config.Apps or {}) do out[i] = { id = app.id, label = app.label, icon = app.icon } end
    return out
end

local function pageUi(v)
    local ui = { type = 'ui', on = v.on ~= false, muted = v.muted == true, channel = v.channel, osd = v.osd }
    if v.menu then
        ui.menu = { page = v.menu.page, sel = v.menu.sel }
        ui.channels, ui.apps = channelList(), appList()
    end
    return ui
end

local function sendSync(a)
    local v = a.view
    duiSend({
        type = 'sync', kind = v.kind, src = v.url, videoId = v.videoId, mediaType = v.mediaType,
        position = currentPosition(a), paused = v.paused, volume = volumeFor(a),
    })
    S.lastVolSent = volumeFor(a)
end

local function renderTargetId(cfg)
    if not IsNamedRendertargetRegistered(cfg.rt) then RegisterNamedRendertarget(cfg.rt, false) end
    if not IsNamedRendertargetLinked(cfg.hash) then LinkNamedRendertarget(cfg.hash) end
    if IsNamedRendertargetRegistered(cfg.rt) then return GetNamedRendertargetRenderId(cfg.rt) end
    return -1
end

local function drawOnRenderTarget(a)
    local id = renderTargetId(a.info.cfg)
    if not id or id == -1 then return end
    SetTextRenderId(id)
    SetScriptGfxDrawOrder(4)
    SetScriptGfxDrawBehindPausemenu(true)
    local ok = pcall(DrawSprite, TXD, S.texName, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
    local default = GetDefaultScriptRendertargetRenderId and GetDefaultScriptRendertargetRenderId() or 1
    SetTextRenderId(default ~= 0 and default or 1)
    SetScriptGfxDrawBehindPausemenu(false)
    return ok
end

local SF = { handle = nil, loading = false, failed = false, bound = nil }

local function scaleformReady()
    if SF.handle and HasScaleformMovieLoaded(SF.handle) then return true end
    if SF.failed or SF.loading or not (Config.Scaleform and Config.Scaleform.enabled) then return false end
    SF.loading = true
    CreateThread(function()
        local handle = RequestScaleformMovie(Config.Scaleform.name)
        local waited = 0
        while not HasScaleformMovieLoaded(handle) and waited < 6000 do
            Wait(50)
            waited = waited + 50
        end
        if HasScaleformMovieLoaded(handle) then
            SF.handle, SF.bound = handle, nil
        else
            SF.failed = true
            print(('^3[Scrappy.Dev TV]^0 Scaleform movie %s is unavailable; free screens will use polygon rendering.'):format(Config.Scaleform.name))
        end
        SF.loading = false
    end)
    return false
end

local function bindScaleformTexture()
    if SF.bound == S.texName then return end
    PushScaleformMovieFunction(SF.handle, 'SET_TEXTURE')
    PushScaleformMovieMethodParameterString(TXD)
    PushScaleformMovieMethodParameterString(S.texName)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(DUI_W)
    PushScaleformMovieFunctionParameterInt(DUI_H)
    PopScaleformMovieFunctionVoid()
    SF.bound = S.texName
end

local function releaseScaleform()
    if SF.handle then pcall(SetScaleformMovieAsNoLongerNeeded, SF.handle) end
    SF.handle, SF.bound = nil, nil
end

local function drawScreenScaleform(sc)
    local per = Config.Scaleform.metersPerScale
    local c = sc.coords
    local rz = -(sc.heading or 0.0) + (sc.flip and 180.0 or 0.0)
    DrawScaleformMovie_3dSolid(SF.handle, c.x, c.y, c.z, sc.pitch or 0.0, 0.0, rz,
        2.0, 2.0, 2.0, sc.width / per, sc.height / per, 1.0, 2)
end

local function drawScreenQuad(sc)
    local h, p = math.rad(sc.heading or 0.0), math.rad(sc.pitch or 0.0)
    local fx, fy = -math.sin(h), math.cos(h)
    local r = vector3(math.cos(h), math.sin(h), 0.0)
    local u = vector3(fx * math.sin(p), fy * math.sin(p), math.cos(p))
    local hw, hh = sc.width / 2.0, sc.height / 2.0
    local c = sc.coords
    local tl, tr = c - r * hw + u * hh, c + r * hw + u * hh
    local bl, br = c - r * hw - u * hh, c + r * hw - u * hh
    local tex = S.texName
    DrawTexturedPoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, TXD, tex, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(tr.x, tr.y, tr.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, TXD, tex, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(tl.x, tl.y, tl.z, bl.x, bl.y, bl.z, tr.x, tr.y, tr.z, 255, 255, 255, 255, TXD, tex, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0)
    DrawTexturedPoly(tr.x, tr.y, tr.z, bl.x, bl.y, bl.z, br.x, br.y, br.z, 255, 255, 255, 255, TXD, tex, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
end

local function drawOff(a)
    if a.info.screen then return end
    local id = renderTargetId(a.info.cfg)
    if not id or id == -1 then return end
    SetTextRenderId(id)
    SetScriptGfxDrawOrder(4)
    pcall(DrawRect, 0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
    local default = GetDefaultScriptRendertargetRenderId and GetDefaultScriptRendertargetRenderId() or 1
    SetTextRenderId(default ~= 0 and default or 1)
end

local function drawWorld(a)
    if a.info.screen then
        local sc = a.info.cfg
        if sc.renderer ~= 'poly' and Config.Scaleform.enabled and not SF.failed then
            if scaleformReady() then
                bindScaleformTexture()
                drawScreenScaleform(sc)
            end
        else
            drawScreenQuad(sc)
        end
    else
        drawOnRenderTarget(a)
    end

    local amb = Config.Ambient
    if amb.enabled and (a.dist or 999.0) <= amb.maxPlayerDistance then
        local c = a.info.coords
        DrawLightWithRange(c.x, c.y, c.z + 0.15, amb.color[1], amb.color[2], amb.color[3], amb.range, amb.intensity)
    end
end

local function drawPointerStage()
    local r = S.pointer and S.pointer.rect
    if not r then return end
    DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 150)
    DrawRect(r.cx, r.cy, r.w, r.h, 0, 0, 0, 255)
    if S.dui then DrawSprite(TXD, S.texName, r.cx, r.cy, r.w, r.h, 0.0, 255, 255, 255, 255) end
end

local function startDrawLoop()
    if S.drawing then return end
    S.drawing = true
    CreateThread(function()
        while S.drawing do
            local a = S.active
            if not a or not a.view then break end
            if a.view.on == false then
                drawOff(a)
            elseif S.dui then
                drawWorld(a)
                if S.pointer then drawPointerStage() end
            end
            Wait(0)
        end
        S.drawing = false
    end)
end

local function sendPage(a)
    local v = a.view
    if v.on ~= false and v.url and v.kind ~= 'web' then
        sendSync(a)
    else
        duiSend({ type = 'idle' })
    end
    duiSend(pageUi(v))
end

local function showView(a)
    local v = a.view
    local on = v.on ~= false

    if not on then
        S.lastSyncedSeq = nil
        if S.dui then
            if S.duiMode == 'web' then setDuiPage(PLAYER_URL, 'player') end
            sendPage(a)
            scheduleDuiDestroy()
        end
        startDrawLoop()
        return
    end

    if not ensureDui() then return end
    startDrawLoop()

    if v.kind == 'web' and v.url and not v.menu then
        if S.duiMode ~= 'web' or S.duiUrl ~= v.url or S.lastSyncedSeq ~= v.playSeq then
            if S.duiMode == 'web' and S.duiUrl == v.url then SetDuiUrl(S.dui, 'about:blank') end
            SetDuiUrl(S.dui, v.url)
            S.duiUrl, S.duiMode = v.url, 'web'
        end
        S.lastSyncedSeq = v.playSeq
        return
    end

    setDuiPage(PLAYER_URL, 'player')
    S.lastSyncedSeq = v.playSeq
    if S.ready then
        sendPage(a)
    else
        local gen = S.duiGen
        for _, delay in ipairs({ 1200, 3000, 6000 }) do
            SetTimeout(delay, function()
                if S.duiGen == gen and S.active and S.active.view and S.duiMode == 'player' and not S.ready then
                    sendPage(S.active)
                end
            end)
        end
    end
end

local function applyView(v)
    local a = S.active
    if not a or not v then return end
    a.view, a.key, a.recvAt = v, v.key, nowMs()
    showView(a)
    if S.remoteOpen or S.pointer then
        SendNUIMessage({ type = 'state', view = v })
    end
end

local function scan()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local best
    for _, m in ipairs(models) do
        local ent = GetClosestObjectOfType(pc.x, pc.y, pc.z, m.maxdistance, m.hash, false, false, false)
        if ent and ent ~= 0 then
            local c = GetEntityCoords(ent)
            local d = #(pc - c)
            if not best or d < best.dist then
                best = { cfg = m, entity = ent, coords = c, dist = d, model = m.model }
            end
        end
    end
    for _, sc in ipairs(Config.Screens or {}) do
        local d = #(pc - sc.coords)
        if d <= sc.maxdistance and (not best or d < best.dist) then
            best = { cfg = sc, screen = true, coords = sc.coords, dist = d, model = 'screen:' .. sc.id }
        end
    end
    if best then
        best.interior = best.entity and GetInteriorFromEntity(best.entity) or GetInteriorAtCoords(best.coords.x, best.coords.y, best.coords.z)
    end
    return best
end

local function leaveTV()
    local a = S.active
    if not a then return end
    if a.key then TriggerServerEvent('scrappydev_tv:server:unsubscribe', a.key) end
    S.active = nil
    S.drawing = false
    if S.dui then
        if S.duiMode == 'web' then setDuiPage(PLAYER_URL, 'player') end
        duiSend({ type = 'idle' })
        scheduleDuiDestroy()
    end
end

local function enterTV(info)
    S.active = { info = info, dist = info.dist, interior = info.interior, since = nowMs() }
    local mine = S.active
    CreateThread(function()
        local v = lib.callback.await('scrappydev_tv:getState', false, info.model, info.coords)
        if S.active ~= mine then
            if v then TriggerServerEvent('scrappydev_tv:server:unsubscribe', v.key) end
            return
        end
        if v then applyView(v) end
    end)
end

CreateThread(function()
    while true do
        local wait = 1000
        if not S.pointer then
            local best = scan()
            local a = S.active
            if best then
                if a and sameTV(a.info, best) then
                    a.info.dist, a.dist, a.interior = best.dist, best.dist, best.interior
                    a.info.coords = best.coords
                    if not a.key and nowMs() - (a.since or 0) > 6000 then
                        leaveTV()
                        enterTV(best)
                    end
                else
                    if a then leaveTV() end
                    enterTV(best)
                end
            elseif a then
                leaveTV()
            end
        end
        if S.active then
            wait = 400
            if S.active.view then sendVolumeIfChanged(false) end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('scrappydev_tv:client:state', function(v)
    if S.active and S.active.key == v.key then applyView(v) end
end)

RegisterNetEvent('scrappydev_tv:client:input', function(key, ev)
    if not S.dui or not S.active or S.active.key ~= key or S.duiMode ~= 'web' or S.pointer then return end
    local t = ev.t
    if t == 'm' then
        SendDuiMouseMove(S.dui, math.floor(ev.x * DUI_W), math.floor(ev.y * DUI_H))
    elseif t == 'd' then
        SendDuiMouseMove(S.dui, math.floor(ev.x * DUI_W), math.floor(ev.y * DUI_H))
        SendDuiMouseDown(S.dui, ev.b)
    elseif t == 'u' then
        SendDuiMouseMove(S.dui, math.floor(ev.x * DUI_W), math.floor(ev.y * DUI_H))
        SendDuiMouseUp(S.dui, ev.b)
    elseif t == 'w' then
        local dy = ev.dy
        if Config.Pointer.invertWheel then dy = -dy end
        SendDuiMouseWheel(S.dui, -dy, 0)
    end
end)

RegisterNUICallback('playerReady', function(_, cb)
    cb('ok')
    S.ready = true
    if S.active and S.active.view and S.duiMode == 'player' then
        sendPage(S.active)
    end
end)

local function releaseRemoteProp()
    S.holdWanted = false
    local ped = PlayerPedId()
    if S.remoteAnim then
        StopAnimTask(ped, Config.Remote.dict, Config.Remote.clip, 2.0)
        S.remoteAnim = false
    end
    if S.remoteProp then
        if DoesEntityExist(S.remoteProp) then DeleteEntity(S.remoteProp) end
        S.remoteProp = nil
    end
end

local function holdRemote(want)
    local R = Config.Remote
    if not (R and R.enabled) then return end
    if not want then releaseRemoteProp() return end
    if S.holdWanted then return end
    S.holdWanted = true
    CreateThread(function()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then S.holdWanted = false return end
        local model = joaat(R.model)
        RequestModel(model)
        RequestAnimDict(R.dict)
        local waited = 0
        while (not HasModelLoaded(model) or not HasAnimDictLoaded(R.dict)) and waited < 3000 do Wait(50) waited = waited + 50 end
        if not S.holdWanted or not HasModelLoaded(model) or not HasAnimDictLoaded(R.dict) then
            S.holdWanted = false
            SetModelAsNoLongerNeeded(model)
            return
        end
        local c = GetEntityCoords(ped)
        local obj = CreateObject(model, c.x, c.y, c.z + 0.3, false, false, false)
        SetModelAsNoLongerNeeded(model)
        if obj and obj ~= 0 then
            AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, R.bone), R.pos.x, R.pos.y, R.pos.z, R.rot.x, R.rot.y, R.rot.z, true, true, false, true, 1, true)
            S.remoteProp = obj
        end
        TaskPlayAnim(ped, R.dict, R.clip, 3.0, 3.0, -1, 49, 0.0, false, false, false)
        S.remoteAnim = true
    end)
end

local function nuiConfig()
    return {
        home = Config.Home, engines = Config.SearchEngines, quick = Config.QuickSites, locale = Config.Locale,
        invertWheel = Config.Pointer.invertWheel, channels = channelList(), streamer = S.streamer,
    }
end

local function closeUi()
    local wasPointer = S.pointer
    S.remoteOpen = false
    if wasPointer then
        TriggerServerEvent('scrappydev_tv:server:pointerStop', wasPointer.key)
        S.pointer = nil
        setImmersive(false)
    end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
    holdRemote(false)
end

local function tvTarget()
    local a = S.active
    if not a then return nil end
    return a.info.model, a.info.coords
end

local function canUse(info)
    local cfg = info.cfg
    return info.dist <= (cfg.controldistance or 15.0)
end

local function openRemote(viaItem)
    local A = Config.Access or {}
    if A.itemRequired and A.item and not viaItem and not lib.callback.await('scrappydev_tv:canOpen', false) then
        notify(Config.Text.needRemote)
        return
    end
    local best = S.pointer and S.active and S.active.info or scan()
    if not best or not canUse(best) then notify(Config.Text.noTvNearby) return end
    if not S.active or not sameTV(S.active.info, best) then
        if S.active then leaveTV() end
        enterTV(best)
    else
        S.active.info.dist = best.dist
    end

    CreateThread(function()
        local mine = S.active
        local v = lib.callback.await('scrappydev_tv:getState', false, best.model, best.coords)
        if S.active ~= mine then return end
        if v then applyView(v) end
        S.remoteOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'remote', config = nuiConfig(), view = v or { volume = Config.Audio.defaultVolume } })
        holdRemote(true)
    end)
end

local function openPointer()
    local a = S.active
    if not a then return end
    local model, coords = tvTarget()
    local res = lib.callback.await('scrappydev_tv:pointerStart', false, model, coords)
    if not res or not res.ok then
        local text = Config.Text.noTvNearby
        if res and res.reason == 'busy' then text = Config.Text.tvBusy:format(res.name or "Another player")
        elseif res and res.reason == 'perm' then text = Config.Text.noPermission
        elseif res and res.reason == 'item' then text = Config.Text.needRemote
        elseif res and res.reason == 'locked' then text = Config.Text.locked end
        notify(text)
        return
    end
    if res.view then applyView(res.view) end
    ensureDui()
    startDrawLoop()

    S.pointer = { key = res.view and res.view.key or a.key, rect = { cx = 0.5, cy = 0.5, w = 0.8, h = 0.8 }, lastX = 0.5, lastY = 0.5 }
    S.remoteOpen = false
    holdRemote(false)
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'pointer', config = nuiConfig(), view = res.view or a.view })
    setImmersive(true)
    sendVolumeIfChanged(true)

    CreateThread(function()
        local lastKeep, lastImm = nowMs(), nowMs()
        while S.pointer do
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            local t = nowMs()
            if t - lastKeep > 10000 then
                lastKeep = t
                TriggerServerEvent('scrappydev_tv:server:input', S.pointer.key, { t = 'm', x = S.pointer.lastX, y = S.pointer.lastY })
            end
            if t - lastImm > 5000 then lastImm = t setImmersive(true) end
            if IsEntityDead(PlayerPedId()) then closeUi() break end
            Wait(0)
        end
    end)
end

RegisterNUICallback('close', function(_, cb) cb('ok') closeUi() end)

RegisterNUICallback('play', function(data, cb)
    cb('ok')
    local model, coords = tvTarget()
    if model and type(data.url) == 'string' then TriggerServerEvent('scrappydev_tv:server:play', model, coords, data.url) end
end)

RegisterNUICallback('stop', function(_, cb)
    cb('ok')
    local model, coords = tvTarget()
    if model then TriggerServerEvent('scrappydev_tv:server:stop', model, coords) end
end)

RegisterNUICallback('volume', function(data, cb)
    cb('ok')
    local model, coords = tvTarget()
    if model then TriggerServerEvent('scrappydev_tv:server:volume', model, coords, data.value) end
end)

RegisterNUICallback('pause', function(data, cb)
    cb('ok')
    local model, coords = tvTarget()
    if model then TriggerServerEvent('scrappydev_tv:server:pause', model, coords, data.paused == true) end
end)

RegisterNUICallback('seek', function(data, cb)
    cb('ok')
    local model, coords = tvTarget()
    if model then TriggerServerEvent('scrappydev_tv:server:seek', model, coords, data.seconds, data.relative == true) end
end)

RegisterNUICallback('key', function(data, cb)
    cb('ok')
    local model, coords = tvTarget()
    if model and type(data.key) == 'string' then TriggerServerEvent('scrappydev_tv:server:key', model, coords, data.key) end
end)

RegisterNUICallback('streamer', function(_, cb)
    cb('ok')
    S.streamer = not S.streamer
    notify(S.streamer and Config.Text.streamerOn or Config.Text.streamerOff, 'info')
    sendVolumeIfChanged(true)
    SendNUIMessage({ type = 'streamer', on = S.streamer })
end)

RegisterNUICallback('pointerOpen', function(_, cb) cb('ok') openPointer() end)

RegisterNUICallback('pointerClose', function(_, cb)
    cb('ok')
    if S.pointer then
        TriggerServerEvent('scrappydev_tv:server:pointerStop', S.pointer.key)
        S.pointer = nil
        setImmersive(false)
        S.remoteOpen = true
        SendNUIMessage({ type = 'remote', config = nuiConfig(), view = S.active and S.active.view or {} })
        holdRemote(true)
    end
end)

RegisterNUICallback('stage', function(data, cb)
    cb('ok')
    if S.pointer and tonumber(data.cx) and tonumber(data.cy) and tonumber(data.w) and tonumber(data.h) then
        S.pointer.rect = { cx = data.cx, cy = data.cy, w = data.w, h = data.h }
    end
end)

local function relay(ev)
    if S.pointer then TriggerServerEvent('scrappydev_tv:server:input', S.pointer.key, ev) end
end

local function flushMove()
    S.flushScheduled = false
    if S.pendingMove then
        local ev = S.pendingMove
        S.pendingMove, S.lastMoveSent = nil, nowMs()
        relay(ev)
    end
end

RegisterNUICallback('mouse', function(data, cb)
    cb('ok')
    if not S.pointer or not S.dui then return end
    local t = data.t
    local x = math.max(0.0, math.min(1.0, tonumber(data.x) or S.pointer.lastX))
    local y = math.max(0.0, math.min(1.0, tonumber(data.y) or S.pointer.lastY))

    if t == 'm' then
        S.pointer.lastX, S.pointer.lastY = x, y
        SendDuiMouseMove(S.dui, math.floor(x * DUI_W), math.floor(y * DUI_H))
        if nowMs() - S.lastMoveSent >= 50 then
            S.lastMoveSent, S.pendingMove = nowMs(), nil
            relay({ t = 'm', x = x, y = y })
        else
            S.pendingMove = { t = 'm', x = x, y = y }
            if not S.flushScheduled then S.flushScheduled = true SetTimeout(55, flushMove) end
        end
    elseif t == 'd' or t == 'u' then
        flushMove()
        S.pointer.lastX, S.pointer.lastY = x, y
        local b = (data.b == 'right' or data.b == 'middle') and data.b or 'left'
        SendDuiMouseMove(S.dui, math.floor(x * DUI_W), math.floor(y * DUI_H))
        if t == 'd' then SendDuiMouseDown(S.dui, b) else SendDuiMouseUp(S.dui, b) end
        relay({ t = t, x = x, y = y, b = b })
    elseif t == 'w' then
        flushMove()
        local dy = math.max(-1200, math.min(1200, tonumber(data.dy) or 0))
        local applied = Config.Pointer.invertWheel and -dy or dy
        SendDuiMouseWheel(S.dui, -applied, 0)
        relay({ t = 'w', dy = dy })
    end
end)

if Config.Access == nil or Config.Access.command ~= false then
    RegisterCommand(Config.Command, function() openRemote() end, false)
end

RegisterNetEvent('scrappydev_tv:client:useRemote', function() openRemote(true) end)
AddEventHandler('rtx_tv:TVRemote', function() openRemote() end)

RegisterCommand(Config.StreamerCommand, function()
    S.streamer = not S.streamer
    notify(S.streamer and Config.Text.streamerOn or Config.Text.streamerOff, 'info')
    sendVolumeIfChanged(true)
    SendNUIMessage({ type = 'streamer', on = S.streamer })
end, false)

RegisterCommand('tvcalib', function(_, args)
    local a = S.active
    if not (a and a.info.screen) then notify("Approche-toi d'un écran libre (Config.Screens).") return end
    local sc = a.info.cfg
    local field, raw = args[1], args[2]
    local allowed = { x = true, y = true, z = true, heading = true, pitch = true, width = true, height = true, flip = true }
    if field and allowed[field] and raw and tonumber(raw) then
        local value = tonumber(raw)
        local delta = raw:sub(1, 1) == '+' or raw:sub(1, 1) == '-'
        if field == 'x' or field == 'y' or field == 'z' then
            local c = sc.coords
            local nv = delta and (c[field] + value) or value
            sc.coords = vector3(field == 'x' and nv or c.x, field == 'y' and nv or c.y, field == 'z' and nv or c.z)
            a.info.coords = sc.coords
        elseif field == 'flip' then
            sc.flip = value ~= 0
        else
            sc[field] = delta and ((sc[field] or 0.0) + value) or value
        end
    end
    local c = sc.coords
    local line = ('coords = vec3(%.4f, %.4f, %.4f), heading = %.1f, pitch = %.1f, width = %.3f, height = %.3f, flip = %s,')
        :format(c.x, c.y, c.z, sc.heading or 0.0, sc.pitch or 0.0, sc.width, sc.height, tostring(sc.flip or false))
    print(('^2[Scrappy.Dev TV]^0 Screen %s: %s'):format(sc.id or '?', line))
    notify(('Screen %s: %s'):format(sc.id or '?', line), 'info')
end, true)

exports('HasVehicleTV', function() return false end)
exports('OpenTelevision', function() openRemote() end)

CreateThread(function()
    if not (Config.Access and Config.Access.target) or GetResourceState('ox_target') ~= 'started' then return end
    local hashes = {}
    for _, m in ipairs(models) do hashes[#hashes + 1] = m.hash end
    exports.ox_target:addModel(hashes, {
        {
            name = 'scrappydev_tv_use',
            icon = Config.Target.icon,
            label = Config.Target.label,
            distance = Config.Target.distance,
            onSelect = function() openRemote() end,
        },
    })
    for _, sc in ipairs(Config.Screens or {}) do
        exports.ox_target:addSphereZone({
            coords = sc.coords, radius = math.max(Config.Target.distance, 2.5),
            options = { { name = 'scrappydev_tv_screen_' .. sc.id, icon = Config.Target.icon, label = Config.Target.screenLabel, onSelect = function() openRemote() end } },
        })
    end
end)

CreateThread(function()
    local sp = Config.SpawnProps
    if not (sp and sp.enabled) then return end
    for _, p in ipairs(sp.list or {}) do
        local hash = tonumber(p.model) or joaat(p.model)
        RequestModel(hash)
        local waited = 0
        while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
        if HasModelLoaded(hash) then
            local obj = CreateObjectNoOffset(hash, p.coords.x, p.coords.y, p.coords.z, false, false, false)
            SetEntityHeading(obj, p.heading or 0.0)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(hash)
            S.props[#S.props + 1] = obj
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    S.drawing = false
    if S.pointer then setImmersive(false) end
    SetNuiFocus(false, false)
    releaseRemoteProp()
    releaseScaleform()
    destroyDui()
    for _, obj in ipairs(S.props) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
end)
