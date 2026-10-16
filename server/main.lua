-- Server-authoritative playback state, access checks and input validation.
local Framework = ScrappyTV.Framework

local TVs = {}
local Subs = {}
local SubOf = {}
local lastChange = {}
local lastVolume = {}
local lastKey = {}
local createLog = {}
local inputBucket = {}
local nextId = 0

local function now() return GetGameTimer() end

local modelByName = {}
for _, m in ipairs(Config.Models) do modelByName[tostring(m.model):lower()] = m end
local screenById = {}
for _, s in ipairs(Config.Screens or {}) do screenById['screen:' .. s.id] = s end

local function cfgFor(model)
    model = tostring(model or ''):lower()
    return modelByName[model] or screenById[model]
end

local function notify(src, msg, kind)
    Framework.Notify(src, msg, kind)
end

local function playerName(src)
    return Framework.GetCharacterName(src)
end

local function toVec(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z or math.abs(x) > 1e5 or math.abs(y) > 1e5 or math.abs(z) > 1e5 then return nil end
    return vector3(x, y, z)
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function bucketOf(src)
    return GetPlayerRoutingBucket(src) or 0
end

local function hasRemote(src)
    return Framework.HasItem(src, Config.Access and Config.Access.item)
end

local function itemRequired()
    local A = Config.Access
    return A and A.itemRequired and A.item and true or false
end

local function permitted(src)
    local permissions = Config.Permissions
    if not permissions or not permissions.enabled then return true end
    if permissions.ace and IsPlayerAceAllowed(src, permissions.ace) then return true end

    local job = Framework.GetJobName(src)
    for _, allowedJob in ipairs(permissions.jobs or {}) do
        if allowedJob == job then return true end
    end

    return false
end

local function controlDenied(src)
    if itemRequired() and not hasRemote(src) then return 'item' end
    if not permitted(src) then return 'perm' end
    return nil
end

local function canControl(src) return controlDenied(src) == nil end

local function positionMs(tv)
    if not tv.startedAt then return 0 end
    local ref = tv.pausedAt or now()
    return math.max(0, ref - tv.startedAt)
end

local osdView
local function osd(tv, kind, text, value, sub)
    tv.osd = { kind = kind, text = text, value = value, sub = sub, seq = ((tv.osd and tv.osd.seq) or 0) + 1, at = now() }
end

osdView = function(tv)
    local o = tv.osd
    if not o then return nil end
    local age = now() - o.at
    if age > 3500 then tv.osd = nil return nil end
    return { kind = o.kind, text = o.text, value = o.value, sub = o.sub, seq = o.seq, ageMs = age }
end

local function view(tv)
    return {
        key = tv.key, coords = tv.coords, model = tv.model,
        kind = tv.kind, url = tv.url, videoId = tv.videoId, mediaType = tv.mediaType, label = tv.label,
        positionMs = positionMs(tv), paused = tv.pausedAt ~= nil,
        volume = tv.volume, version = tv.version, playSeq = tv.playSeq or 0,
        controller = tv.controllerName, locked = tv.locked or false, preset = tv.preset or false,
        on = tv.on == true, muted = tv.muted == true, channel = tv.channel,
        menu = tv.menu and { page = tv.menu.page, sel = tv.menu.sel } or nil,
        osd = osdView(tv),
    }
end

local function releaseIfExpired(tv)
    if tv.controller and tv.controllerUntil and now() > tv.controllerUntil then
        tv.controller, tv.controllerName, tv.controllerUntil = nil, nil, nil
    end
end

local function push(tv)
    tv.version = (tv.version or 0) + 1
    local subs = Subs[tv.key]
    if not subs then return end
    local payload = view(tv)
    for src in pairs(subs) do
        if pedCoords(src) and bucketOf(src) == tv.bucket then
            TriggerClientEvent('scrappydev_tv:client:state', src, payload)
        else
            subs[src] = nil
            if SubOf[src] then SubOf[src][tv.key] = nil end
        end
    end
end

local function findTV(bucket, coords, radius)
    local best, bestDist
    for _, tv in pairs(TVs) do
        if tv.bucket == bucket then
            local d = #(tv.coords - coords)
            if d <= radius and (not bestDist or d < bestDist) then best, bestDist = tv, d end
        end
    end
    return best
end

local function newTV(bucket, coords, model)
    nextId = nextId + 1
    local tv = {
        key = ('tv%d'):format(nextId), bucket = bucket, coords = coords, model = model,
        volume = Config.Audio.defaultVolume, version = 0,
    }
    TVs[tv.key] = tv
    return tv
end

local function throttleCreate(src)
    local t = now()
    local e = createLog[src]
    if not e or t > e.resetAt then e = { count = 0, resetAt = t + 60000 } createLog[src] = e end
    e.count = e.count + 1
    return e.count <= Config.Limits.maxTvPerPlayerCreate
end

local function resolve(src, model, rawCoords, mode)
    local cfg = cfgFor(model)
    local coords = toVec(rawCoords)
    if not cfg or not coords then return nil, 'invalid' end

    local me = pedCoords(src)
    if not me then return nil, 'invalid' end
    local limit = (mode == 'control' and (cfg.controldistance or 15.0) or (cfg.maxdistance or 30.0)) + 8.0
    if #(me - coords) > limit then return nil, 'far' end

    local bucket = bucketOf(src)
    local tv = findTV(bucket, coords, 2.0)
    if tv then
        if not tv.model then tv.model = tostring(model):lower() end
        return tv
    end
    if not throttleCreate(src) then return nil, 'toomany' end
    return newTV(bucket, coords, tostring(model):lower())
end

local function subscribe(src, tv)
    Subs[tv.key] = Subs[tv.key] or {}
    Subs[tv.key][src] = true
    SubOf[src] = SubOf[src] or {}
    SubOf[src][tv.key] = true
end

local function hasSubs(key)
    return Subs[key] and next(Subs[key]) ~= nil
end

local function unsubscribe(src, key)
    if Subs[key] then Subs[key][src] = nil end
    if SubOf[src] then SubOf[src][key] = nil end
    local tv = TVs[key]
    if tv and tv.controller == src then tv.controller, tv.controllerName, tv.controllerUntil = nil, nil, nil end
    if tv and not tv.url and not tv.preset and not tv.exported and not hasSubs(key) then TVs[key] = nil end
end

local function guardControl(src, model, coords)
    local denied = controlDenied(src)
    if denied then notify(src, denied == 'item' and Config.Text.needRemote or Config.Text.noPermission) return nil end
    local tv, err = resolve(src, model, coords, 'control')
    if not tv then
        if err == 'far' then notify(src, Config.Text.noTvNearby) elseif err == 'toomany' then notify(src, Config.Text.tooFast) end
        return nil
    end
    if tv.locked then notify(src, Config.Text.locked) return nil end
    releaseIfExpired(tv)
    if tv.controller and tv.controller ~= src then notify(src, Config.Text.tvBusy:format(tv.controllerName or 'Another player')) return nil end
    subscribe(src, tv)
    return tv
end

local function applyUrl(tv, info)
    tv.url, tv.kind, tv.videoId, tv.mediaType, tv.label = info.url, info.kind, info.videoId, info.mediaType, info.label
    tv.startedAt = now() - math.floor((info.start or 0) * 1000)
    tv.pausedAt = nil
    tv.channel = nil
    tv.on, tv.menu, tv.digits = true, nil, nil
    tv.playSeq = (tv.playSeq or 0) + 1
end

local function clearTV(tv)
    tv.url, tv.kind, tv.videoId, tv.mediaType, tv.label = nil, nil, nil, nil, nil
    tv.startedAt, tv.pausedAt = nil, nil
    tv.channel, tv.digits = nil, nil
    tv.playSeq = (tv.playSeq or 0) + 1
end

lib.callback.register('scrappydev_tv:getState', function(src, model, coords)
    local tv, err = resolve(src, model, coords, 'view')
    if not tv then return nil end
    releaseIfExpired(tv)
    subscribe(src, tv)
    return view(tv)
end)

lib.callback.register('scrappydev_tv:canOpen', function(src)
    if itemRequired() then return hasRemote(src) end
    return true
end)

RegisterNetEvent('scrappydev_tv:server:unsubscribe', function(key)
    if type(key) == 'string' then unsubscribe(source, key) end
end)

RegisterNetEvent('scrappydev_tv:server:play', function(model, coords, raw)
    local src = source
    local t = now()
    if lastChange[src] and t - lastChange[src] < Config.Limits.changeCooldownMs then notify(src, Config.Text.tooFast) return end

    local info, err = Urls.Classify(raw, Config.BlacklistedHosts, Config.Limits.maxUrlLength)
    if not info then
        notify(src, err == 'blocked' and Config.Text.blockedUrl or Config.Text.badUrl)
        return
    end

    local tv = guardControl(src, model, coords)
    if not tv then return end

    lastChange[src] = t
    applyUrl(tv, info)
    if tv.controller == src then tv.controllerUntil = t + Config.Pointer.lockSeconds * 1000 end
    push(tv)
end)

RegisterNetEvent('scrappydev_tv:server:stop', function(model, coords)
    local src = source
    local tv = guardControl(src, model, coords)
    if not tv then return end
    clearTV(tv)
    if tv.on then tv.menu = { page = 'home', sel = 1 } end
    push(tv)
    notify(src, Config.Text.tvStopped, 'success')
end)

RegisterNetEvent('scrappydev_tv:server:volume', function(model, coords, value)
    local src = source
    local v = tonumber(value)
    if not v then return end
    local t = now()
    if lastVolume[src] and t - lastVolume[src] < 120 then return end
    local tv = guardControl(src, model, coords)
    if not tv then return end
    lastVolume[src] = t
    tv.muted = false
    tv.volume = math.max(0, math.min(100, math.floor(v + 0.5)))
    push(tv)
end)

local function isTimed(tv) return tv.url and tv.startedAt and (tv.kind == 'youtube' or tv.kind == 'media') end

local function setPaused(tv, paused)
    if not isTimed(tv) then return false end
    local t = now()
    if paused and not tv.pausedAt then
        tv.pausedAt = t
    elseif not paused and tv.pausedAt then
        tv.startedAt = tv.startedAt + (t - tv.pausedAt)
        tv.pausedAt = nil
    else
        return false
    end
    return true
end

local function seekTo(tv, ms)
    if not isTimed(tv) then return false end
    ms = math.max(0, ms)
    tv.startedAt = (tv.pausedAt or now()) - ms
    return true
end

RegisterNetEvent('scrappydev_tv:server:pause', function(model, coords, paused)
    local src = source
    local tv = guardControl(src, model, coords)
    if not tv then return end
    if setPaused(tv, paused) then push(tv) end
end)

RegisterNetEvent('scrappydev_tv:server:seek', function(model, coords, seconds, relative)
    local src = source
    local s = tonumber(seconds)
    if not s or math.abs(s) > 86400 then return end
    local tv = guardControl(src, model, coords)
    if not tv then return end
    if seekTo(tv, relative and (positionMs(tv) + s * 1000) or (s * 1000)) then push(tv) end
end)

local broadcastInput

local KEYS = {
    power = true, mute = true, vol_up = true, vol_down = true, ch_up = true, ch_down = true,
    info = true, menu = true, home = true, guide = true, back = true, exit = true,
    up = true, down = true, left = true, right = true, ok = true,
    red = true, green = true, yellow = true, blue = true,
    d0 = true, d1 = true, d2 = true, d3 = true, d4 = true, d5 = true, d6 = true, d7 = true, d8 = true, d9 = true,
}

local function appById(id)
    for i, a in ipairs(Config.Apps or {}) do
        if a.id == id then return a, i end
    end
end

local function menuSize(tv)
    if not tv.menu then return 0 end
    if tv.menu.page == 'channels' then return #(Config.Channels or {}) end
    return #(Config.Apps or {})
end

local function openMenu(tv, page, sel)
    tv.menu = { page = page, sel = sel or 1 }
    tv.digits = nil
end

local function playUrl(tv, url)
    local info = Urls.Classify(url, Config.BlacklistedHosts, Config.Limits.maxUrlLength)
    if not info then return false end
    applyUrl(tv, info)
    return true
end

local function tune(tv, n)
    local ch = Config.Channels and Config.Channels[n]
    if not ch or not playUrl(tv, ch.url) then
        osd(tv, 'channel', 'Chaîne introuvable', n)
        return
    end
    tv.channel = n
    osd(tv, 'channel', ch.name, n)
end

local function openApp(tv, app)
    if not app then return end
    if app.page then
        openMenu(tv, app.page, app.page == 'channels' and (tv.channel or 1) or 1)
    elseif app.url then
        playUrl(tv, app.url)
    end
end

local function commitDigits(tv)
    local n = tonumber(tv.digits or '')
    tv.digits = nil
    if n then tune(tv, n) end
end

local function stepChannel(tv, dir)
    local total = #(Config.Channels or {})
    if total == 0 then return end
    local n = ((tv.channel or (dir > 0 and 0 or total + 1)) - 1 + dir) % total + 1
    tune(tv, n)
end

local function changeVolume(tv, delta)
    tv.muted = false
    tv.volume = math.max(0, math.min(100, (tv.volume or 0) + delta))
    osd(tv, 'volume', nil, tv.volume)
end

local function navigate(tv, key)
    local size = menuSize(tv)
    if size == 0 then return end
    local sel = tv.menu.sel or 1
    local horizontal = tv.menu.page ~= 'channels'
    if (horizontal and (key == 'left' or key == 'right')) or (not horizontal and (key == 'up' or key == 'down')) then
        local dir = (key == 'left' or key == 'up') and -1 or 1
        tv.menu.sel = (sel - 1 + dir) % size + 1
    end
end

local function activate(tv)
    if tv.menu.page == 'channels' then
        tune(tv, tv.menu.sel or 1)
    else
        openApp(tv, Config.Apps[tv.menu.sel or 1])
    end
end

local function handleKey(tv, key)
    if key == 'power' then
        tv.on = not tv.on
        tv.menu, tv.digits = nil, nil
        if tv.on then
            if tv.url then
                osd(tv, 'info', tv.channel and Config.Channels[tv.channel] and Config.Channels[tv.channel].name or nil, tv.channel)
            else
                openMenu(tv, 'home')
            end
        else
            tv.osd = nil
        end
        return
    end
    if not tv.on then return end

    local step = Config.Keys
    local digit = key:match('^d(%d)$')
    if digit then
        local maxDigits = math.max(1, #tostring(#(Config.Channels or {})))
        tv.digits = ((tv.digits or '') .. digit):sub(1, maxDigits)
        tv.digitSeq = (tv.digitSeq or 0) + 1
        osd(tv, 'digits', tv.digits)
        if #tv.digits >= maxDigits then
            commitDigits(tv)
        else
            local seq = tv.digitSeq
            SetTimeout(step.digitTimeoutMs, function()
                if tv.digitSeq == seq and tv.digits then commitDigits(tv) push(tv) end
            end)
        end
    elseif key == 'mute' then
        tv.muted = not tv.muted
        osd(tv, 'mute', nil, tv.volume)
    elseif key == 'vol_up' then changeVolume(tv, step.volumeStep)
    elseif key == 'vol_down' then changeVolume(tv, -step.volumeStep)
    elseif key == 'ch_up' then stepChannel(tv, 1)
    elseif key == 'ch_down' then stepChannel(tv, -1)
    elseif key == 'info' then
        local ch = tv.channel and Config.Channels[tv.channel]
        osd(tv, 'info', ch and ch.name or tv.label or Config.Text.notificationTitle, tv.channel, tv.url and (tv.label or 'Link') or 'No content')
    elseif key == 'menu' or key == 'home' then
        if key == 'menu' and tv.menu then tv.menu = nil else openMenu(tv, 'home') end
    elseif key == 'guide' then
        openMenu(tv, 'channels', tv.channel or 1)
    elseif key == 'exit' then
        tv.menu, tv.digits = nil, nil
    elseif key == 'back' then
        if tv.menu and tv.menu.page ~= 'home' then openMenu(tv, 'home')
        elseif tv.menu then tv.menu = nil
        else openMenu(tv, 'home') end
    elseif key == 'red' or key == 'green' or key == 'yellow' or key == 'blue' then
        openApp(tv, appById(Config.ColorKeys and Config.ColorKeys[key]))
    elseif key == 'ok' then
        if tv.digits then commitDigits(tv)
        elseif tv.menu then activate(tv)
        elseif setPaused(tv, not tv.pausedAt) then osd(tv, 'pause', tv.pausedAt and 'Pause' or 'Lecture') end
    else
        if tv.menu then
            navigate(tv, key)
        elseif isTimed(tv) then
            if key == 'left' or key == 'right' then
                local sec = key == 'left' and -step.seekSeconds or step.seekSeconds
                if seekTo(tv, positionMs(tv) + sec * 1000) then osd(tv, 'seek', (sec > 0 and '+' or '') .. sec .. ' s') end
            else
                changeVolume(tv, key == 'up' and step.volumeStep or -step.volumeStep)
            end
        elseif tv.url and tv.kind == 'web' then
            if key == 'up' or key == 'down' then broadcastInput(tv, { t = 'w', dy = key == 'down' and step.scrollPixels or -step.scrollPixels }) end
        end
    end
end

RegisterNetEvent('scrappydev_tv:server:key', function(model, coords, key)
    local src = source
    if type(key) ~= 'string' or not KEYS[key] then return end
    local t = now()
    if lastKey[src] and t - lastKey[src] < 80 then return end
    local tv = guardControl(src, model, coords)
    if not tv then return end
    lastKey[src] = t
    handleKey(tv, key)
    push(tv)
end)

lib.callback.register('scrappydev_tv:pointerStart', function(src, model, coords)
    local denied = controlDenied(src)
    if denied then return { ok = false, reason = denied } end
    local tv, err = resolve(src, model, coords, 'control')
    if not tv then return { ok = false, reason = err } end
    if tv.locked then return { ok = false, reason = 'locked' } end
    releaseIfExpired(tv)
    if tv.controller and tv.controller ~= src then
        return { ok = false, reason = 'busy', name = tv.controllerName }
    end
    subscribe(src, tv)
    tv.on, tv.menu = true, nil
    tv.controller, tv.controllerName = src, playerName(src)
    tv.controllerUntil = now() + Config.Pointer.lockSeconds * 1000
    return { ok = true, view = view(tv) }
end)

RegisterNetEvent('scrappydev_tv:server:pointerStop', function(key)
    local src = source
    local tv = type(key) == 'string' and TVs[key] or nil
    if tv and tv.controller == src then tv.controller, tv.controllerName, tv.controllerUntil = nil, nil, nil end
end)

broadcastInput = function(tv, ev)
    local subs = Subs[tv.key]
    if not subs then return end
    for target in pairs(subs) do
        if bucketOf(target) == tv.bucket then TriggerClientEvent('scrappydev_tv:client:input', target, tv.key, ev) end
    end
end

local BUTTONS = { left = true, right = true, middle = true }

local function allowInput(src)
    local t = now()
    local b = inputBucket[src]
    local rate = Config.Limits.maxInputPerSecond
    if not b then b = { tokens = rate, at = t } inputBucket[src] = b end
    b.tokens = math.min(rate, b.tokens + (t - b.at) * rate / 1000)
    b.at = t
    if b.tokens < 1 then return false end
    b.tokens = b.tokens - 1
    return true
end

RegisterNetEvent('scrappydev_tv:server:input', function(key, ev)
    local src = source
    local tv = type(key) == 'string' and TVs[key] or nil
    if not tv or tv.controller ~= src or type(ev) ~= 'table' then return end
    if not allowInput(src) then return end

    local kind = ev.t
    local clean
    if kind == 'm' or kind == 'd' or kind == 'u' then
        local x, y = tonumber(ev.x), tonumber(ev.y)
        if not x or not y then return end
        clean = { t = kind, x = math.max(0.0, math.min(1.0, x)), y = math.max(0.0, math.min(1.0, y)) }
        if kind ~= 'm' then
            if not BUTTONS[ev.b] then return end
            clean.b = ev.b
        end
    elseif kind == 'w' then
        local dy = tonumber(ev.dy)
        if not dy then return end
        clean = { t = 'w', dy = math.max(-1200, math.min(1200, dy)) }
    else
        return
    end

    tv.controllerUntil = now() + Config.Pointer.lockSeconds * 1000
    local subs = Subs[key]
    if not subs then return end
    for target in pairs(subs) do
        if target ~= src and bucketOf(target) == tv.bucket then
            TriggerClientEvent('scrappydev_tv:client:input', target, key, clean)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for key in pairs(SubOf[src] or {}) do
        if Subs[key] then Subs[key][src] = nil end
        local tv = TVs[key]
        if tv then
            if tv.controller == src then tv.controller, tv.controllerName, tv.controllerUntil = nil, nil, nil end
            if not tv.url and not tv.preset and not tv.exported and not hasSubs(key) then TVs[key] = nil end
        end
    end
    SubOf[src], lastChange[src], lastVolume[src], lastKey[src], createLog[src], inputBucket[src] = nil, nil, nil, nil, nil, nil
end)

local function useRemote(src)
    TriggerClientEvent('scrappydev_tv:client:useRemote', src)
end

CreateThread(function()
    local access = Config.Access
    if not (access and access.item) then return end

    local registered = Framework.RegisterUsableItem(access.item, function(source)
        useRemote(source)
    end)

    if not registered then
        print(('^3[Scrappy.Dev TV]^0 Could not register item "%s" for framework "%s". Use the useRemote export or configure your inventory item.'):format(access.item, Framework.GetName()))
    end
end)

exports('useRemote', useRemote)

CreateThread(function()
    for _, preset in ipairs(Config.Presets or {}) do
        local coords = toVec(preset.coords)
        local info = coords and Urls.Classify(preset.url, nil, 4000)
        if coords and info then
            local tv = newTV(0, coords, nil)
            tv.preset = true
            applyUrl(tv, info)
            tv.on = true
        else
            print(('^1[Scrappy.Dev TV]^0 Skipped a preset with invalid coordinates or URL: %s'):format(tostring(preset.url)))
        end
    end
end)

local function exportTV(coords, bucket, create)
    coords = toVec(coords)
    if not coords then return nil end
    bucket = tonumber(bucket) or 0
    local tv = findTV(bucket, coords, 2.0)
    if not tv and create then
        tv = newTV(bucket, coords, nil)
    end
    if tv then tv.exported = true end
    return tv
end

exports('StartTelevision', function(coords, tvtypeid, volume, bucket, controldisabled)
    local tv = exportTV(coords, bucket, true)
    if not tv then return false end
    if tonumber(volume) then tv.volume = math.max(0, math.min(100, math.floor(tonumber(volume)))) end
    tv.locked = controldisabled == true
    tv.on = true
    push(tv)
    return true
end)

exports('PlayVideoOnTelevision', function(coords, bucket, a, b)
    local tv = exportTV(coords, bucket, true)
    if not tv then return false end
    local url, volume = b, a
    if b == nil and type(a) == 'string' then url, volume = a, nil end
    local info = Urls.Classify(url, Config.BlacklistedHosts, Config.Limits.maxUrlLength)
    if not info then return false end
    if tonumber(volume) then tv.volume = math.max(0, math.min(100, math.floor(tonumber(volume)))) end
    applyUrl(tv, info)
    push(tv)
    return true
end)

exports('ChangeVolumeTelevision', function(coords, volume, bucket)
    local tv = exportTV(coords, bucket, false)
    if not tv or not tonumber(volume) then return false end
    tv.volume = math.max(0, math.min(100, math.floor(tonumber(volume))))
    push(tv)
    return true
end)

exports('StopTelevision', function(coords, bucket)
    local tv = exportTV(coords, bucket, false)
    if not tv then return false end
    clearTV(tv)
    tv.locked = false
    tv.on, tv.menu = false, nil
    push(tv)
    return true
end)
