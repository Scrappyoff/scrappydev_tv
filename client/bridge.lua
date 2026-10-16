-- Framework adapter for the supported server cores.
ScrappyTV = ScrappyTV or {}
ScrappyTV.Framework = ScrappyTV.Framework or {}

local Framework = ScrappyTV.Framework
local selected = nil
local qbCore, esxCore = nil, nil

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

function Framework.GetName()
    if selected then return selected end

    local configured = (Config.Framework or 'auto'):lower()
    if configured ~= 'auto' then
        selected = configured
    elseif resourceStarted('qbx_core') then
        selected = 'qbx'
    elseif resourceStarted('qb-core') then
        selected = 'qb'
    elseif resourceStarted('es_extended') then
        selected = 'esx'
    elseif resourceStarted('ox_core') then
        selected = 'ox'
    else
        selected = 'standalone'
    end

    return selected
end

local function getQBCore()
    if qbCore then return qbCore end
    if not resourceStarted('qb-core') then return nil end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then qbCore = core end
    return qbCore
end

local function getESX()
    if esxCore then return esxCore end
    if not resourceStarted('es_extended') then return nil end
    local ok, core = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok then esxCore = core end
    return esxCore
end

function Framework.Notify(message, kind)
    local framework = Framework.GetName()
    if (framework == 'qb' or framework == 'qbx') and resourceStarted('qb-core') then
        TriggerEvent('QBCore:Notify', message, kind or 'error', 5000)
        return
    end

    if framework == 'esx' then
        local core = getESX()
        if core and core.ShowNotification then
            core.ShowNotification(message)
            return
        end
    end

    lib.notify({ title = 'Scrappy.Dev TV', description = message, type = kind or 'error' })
end

function Framework.SetImmersive(enabled)
    local integration = Config.Integrations and Config.Integrations.immersiveHud
    if not integration or not integration.enabled or not integration.resource or not integration.export then return end
    if not resourceStarted(integration.resource) then return end

    pcall(function()
        exports[integration.resource][integration.export](enabled, integration.duration or 15000)
    end)
end

RegisterNetEvent('scrappydev_tv:client:notify', function(message, kind)
    Framework.Notify(message, kind)
end)
