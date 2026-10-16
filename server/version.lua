-- Checks the public release manifest and reports updates to the server console.
local resourceName = GetCurrentResourceName()
local announcedVersion = nil
local warnedMissingUrl = false

local function versionParts(value)
    local parts = {}
    for part in tostring(value or ''):gmatch('%d+') do
        parts[#parts + 1] = tonumber(part) or 0
    end
    if #parts == 0 then return nil end
    return parts
end

local function isNewer(remote, localVersion)
    local remoteParts, localParts = versionParts(remote), versionParts(localVersion)
    if not remoteParts or not localParts then return false end

    local count = math.max(#remoteParts, #localParts)
    for index = 1, count do
        local current = localParts[index] or 0
        local latest = remoteParts[index] or 0
        if latest > current then return true end
        if latest < current then return false end
    end
    return false
end

local function checkVersion()
    local settings = Config.VersionCheck or {}
    if not settings.enabled then return end

    local url = tostring(settings.url or '')
    if not url:match('^https://') then
        if not warnedMissingUrl then
            warnedMissingUrl = true
            print('^3[Scrappy.Dev TV]^0 Version check is enabled, but Config.VersionCheck.url is not set to a public HTTPS version.json URL.')
        end
        return
    end

    local installed = GetResourceMetadata(resourceName, 'version', 0) or Config.Version or '0.0.0'
    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or type(body) ~= 'string' then
            print(('^3[Scrappy.Dev TV]^0 Version check failed (HTTP %s).'):format(tostring(status)))
            return
        end

        local ok, manifest = pcall(json.decode, body)
        if not ok or type(manifest) ~= 'table' or type(manifest.version) ~= 'string' then
            print('^3[Scrappy.Dev TV]^0 The remote version.json is invalid; expected a JSON object with a version string.')
            return
        end

        if isNewer(manifest.version, installed) then
            if announcedVersion == manifest.version then return end
            announcedVersion = manifest.version
            print('^3[Scrappy.Dev TV] UPDATE AVAILABLE^0')
            print(('^3[Scrappy.Dev TV]^0 Installed: %s | Latest: %s'):format(installed, manifest.version))
            if type(manifest.notes) == 'string' and manifest.notes ~= '' then
                print(('^3[Scrappy.Dev TV]^0 Notes: %s'):format(manifest.notes))
            end
            if type(manifest.download) == 'string' and manifest.download ~= '' then
                print(('^3[Scrappy.Dev TV]^0 Download: %s'):format(manifest.download))
            end
            print('^3[Scrappy.Dev TV]^0 Download the latest package from the project releases, then restart this resource.')
        end
    end, 'GET', '', { ['Accept'] = 'application/json' })
end

CreateThread(function()
    Wait(3000)
    checkVersion()

    local interval = math.max(30, tonumber(Config.VersionCheck and Config.VersionCheck.intervalMinutes) or 360)
    while true do
        Wait(interval * 60000)
        checkVersion()
    end
end)
