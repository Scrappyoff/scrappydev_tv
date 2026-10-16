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

function Framework.GetPlayer(source)
    local framework = Framework.GetName()
    if framework == 'qbx' and resourceStarted('qbx_core') then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        if ok then return player end
    elseif framework == 'qb' then
        local core = getQBCore()
        return core and core.Functions.GetPlayer(source) or nil
    elseif framework == 'esx' then
        local core = getESX()
        return core and core.GetPlayerFromId(source) or nil
    elseif framework == 'ox' and resourceStarted('ox_core') then
        local ok, player = pcall(function() return exports.ox_core:GetPlayer(source) end)
        if ok then return player end
    end
    return nil
end

function Framework.GetJobName(source)
    local framework = Framework.GetName()
    local player = Framework.GetPlayer(source)
    if not player then return nil end

    if framework == 'qb' or framework == 'qbx' then
        return player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    elseif framework == 'esx' then
        local job = player.getJob and player.getJob()
        return job and job.name
    elseif framework == 'ox' then
        local ok, group = pcall(function() return player:getGroupByType('job') end)
        if ok then return group end
    end

    return nil
end

function Framework.HasItem(source, itemName)
    if not itemName then return false end
    if resourceStarted('ox_inventory') then
        local ok, count = pcall(function() return exports.ox_inventory:GetItemCount(source, itemName) end)
        if ok then return (tonumber(count) or 0) > 0 end
    end

    local framework = Framework.GetName()
    local player = Framework.GetPlayer(source)
    if (framework == 'qb' or framework == 'qbx') and player and player.Functions then
        return player.Functions.GetItemByName(itemName) ~= nil
    elseif framework == 'esx' and player and player.getInventoryItem then
        local item = player.getInventoryItem(itemName)
        return item ~= nil and (tonumber(item.count) or 0) > 0
    end

    return false
end

function Framework.RegisterUsableItem(itemName, callback)
    local framework = Framework.GetName()
    if framework == 'qbx' and resourceStarted('qbx_core') then
        return pcall(function() exports.qbx_core:CreateUseableItem(itemName, callback) end)
    elseif framework == 'qb' then
        local core = getQBCore()
        if core and core.Functions then return pcall(core.Functions.CreateUseableItem, itemName, callback) end
    elseif framework == 'esx' then
        local core = getESX()
        if core and core.RegisterUsableItem then return pcall(core.RegisterUsableItem, itemName, callback) end
    end

    return false
end

function Framework.Notify(source, message, kind)
    if not source or source == 0 then return end
    TriggerClientEvent('scrappydev_tv:client:notify', source, message, kind or 'error')
end

function Framework.GetCharacterName(source)
    local framework = Framework.GetName()
    local player = Framework.GetPlayer(source)
    if framework == 'qb' or framework == 'qbx' then
        local info = player and player.PlayerData and player.PlayerData.charinfo
        if info and info.firstname then
            return ('%s %s'):format(info.firstname, info.lastname or '')
        end
    elseif framework == 'esx' and player and player.getName then
        return player.getName()
    elseif framework == 'ox' and player then
        return player.username
    end

    return GetPlayerName(source) or 'Player'
end
