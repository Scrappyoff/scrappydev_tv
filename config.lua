-- Scrappy.Dev TV configuration.
Config = {}

-- Interface language: 'en' or 'fr'.
Config.Locale = 'en'
-- Framework: 'auto', 'qb', 'qbx', 'esx', 'ox', or 'standalone'.
Config.Framework = 'auto'
-- Keep this value in sync with fxmanifest.lua when publishing a release.
Config.Version = '1.0.0'
-- url must be a public HTTPS URL returning JSON with version, download, and optional notes fields.
Config.VersionCheck = { enabled = false, url = '', intervalMinutes = 360 }
-- Optional HUD bridge. Enable only if the named resource exports the configured function.
Config.Integrations = { immersiveHud = { enabled = false, resource = '', export = 'SetImmersive', duration = 15000 } }

-- Command names are written without a leading slash.
Config.Command = 'tv'
Config.StreamerCommand = 'streamermode'

-- Set target=true to use ox_target. item/itemRequired are optional framework inventory gates.
Config.Access = {
    command = true,
    target = false,
    item = false,         -- Example: 'tv_remote' (definitions and icon are in the install folder)
    itemRequired = false, -- true = players must carry that item to control a TV
}

-- Interaction range and icon. Text labels come from the selected locale file.
Config.Target = {
    distance = 2.5,
    icon = 'fa-solid fa-tv',
    label = 'Use television',
}

-- When enabled, a matching ACE OR a matching job name grants control.
Config.Permissions = {
    enabled = false,
    ace = 'scrappydev_tv.control',
    jobs = { 'police', 'cinema' },
}

-- Optional extra blocked domains. Subdomains are blocked too; local/private hosts are always rejected.
Config.BlacklistedHosts = {
    -- 'example.com',
}

-- Home page, available search engines, and one-click shortcuts in the remote UI.
Config.Home = 'https://duckduckgo.com/'
Config.SearchEngines = {
    { id = 'youtube', label = 'YouTube',    url = 'https://www.youtube.com/results?search_query=%s' },
}
Config.QuickSites = {
    { label = 'YouTube', url = 'https://www.youtube.com/' },
    { label = 'Twitch', url = 'https://www.twitch.tv/' },
}

-- Audio defaults and attenuation. Volumes are percentages; distances are meters.
Config.Audio = {
    defaultVolume = 50,
    referenceDistance = 2.5,
    otherRoomFactor = 0.35,
}

-- Small light around a playing television. RGB values range from 0 to 255.
Config.Ambient = {
    enabled = true,
    range = 4.5,
    intensity = 0.55,
    color = { 190, 205, 255 },
    maxPlayerDistance = 14.0,
}

-- Mouse browsing controller lease and input behavior.
Config.Pointer = {
    lockSeconds = 25,
    invertWheel = false,
    hideImmersiveHud = false,
}

-- Server-side input limits. Keep these values positive; milliseconds are used where named.
Config.Limits = {
    changeCooldownMs = 1200,
    maxUrlLength = 1800,
    maxInputPerSecond = 90,
    maxTvPerPlayerCreate = 25,
}

local function tv(model, rt, maxdistance, controldistance)
    return { model = model, rt = rt or 'tvscreen', maxdistance = maxdistance or 30.0, controldistance = controldistance or 15.0 }
end

-- Supported world TV props. Each entry has model, render-target name, scan range, and control range.
Config.Models = {
    tv('prop_tv_flat_01'),
    tv('v_ilev_cin_screen', 'cinscreen', 40.0, 20.0),
    tv('vw_prop_vw_cinema_tv_01'),
    tv('2094206603'),
    tv('prop_tv_flat_michael'),
    tv('prop_trev_tv_01'),
    tv('prop_tv_flat_03b'),
    tv('prop_tv_flat_03'),
    tv('prop_tv_flat_02b'),
    tv('prop_tv_flat_02'),
    tv('hei_heist_str_avunitl_03'),
    tv('mp_b_str_avunitl_03'),
    tv('mp_b_str_avunits_01'),
    tv('mp_b_str_avunitl_01'),
    tv('hei_heist_str_avunitl_01'),
    tv('hei_heist_str_avunits_01'),
    tv('apa_mp_h_str_avunitl_04'),
    tv('apa_mp_h_str_avunitl_01_b'),
    tv('apa_mp_h_str_avunits_01'),
    tv('apa_mp_h_str_avunits_04'),
    tv('prop_tv_01'),
    tv('prop_tv_02'),
    tv('prop_tv_03'),
    tv('prop_tv_04'),
    tv('prop_tv_05'),
    tv('prop_tv_06'),
    tv('prop_tv_07'),
    tv('ex_prop_ex_tv_flat_01', 'ex_tvscreen'),
    tv('sm_prop_smug_tv_flat_01', 'tv_flat_01'),
    tv('prop_tv_test'),
    tv('des_tvsmash_root'),
    tv('des_tvsmash_start'),
}

-- Leave disabled for the built-in polygon screen renderer.
Config.Scaleform = {
    enabled = false,
    name = 'generic_texture_renderer',
    metersPerScale = 12.8,
}

-- Optional free-standing screens. Add entries here; see README.md for a complete example.
Config.Screens = {
    -- { id = 'lobby_screen', coords = vec3(0.0, 0.0, 0.0), width = 4.0, height = 2.25, heading = 0.0, pitch = 0.0, maxdistance = 40.0, controldistance = 15.0, renderer = 'poly' },
}

-- Optional numbered channels. Empty means the remote's channel guide has no entries.
Config.Channels = {
    -- { name = 'Local News', url = 'https://www.youtube.com/watch?v=abcdefghijk' },
}

-- Apps shown on the remote home screen. ColorKeys below refers to these IDs.
Config.Apps = {
    { id = 'channels', label = 'Channels', icon = 'tv',      page = 'channels' },
    { id = 'youtube',  label = 'YouTube',  icon = 'youtube', url = 'https://www.youtube.com/' },
    { id = 'twitch',   label = 'Twitch',   icon = 'twitch',  url = 'https://www.twitch.tv/' },
    { id = 'browser',  label = 'Browser',  icon = 'globe',   url = 'https://duckduckgo.com/' },
}

-- Each value must match an Apps.id; 'channels' opens the channel guide.
Config.ColorKeys = { red = 'youtube', green = 'twitch', yellow = 'channels', blue = 'browser' }

-- Remote adjustment increments and navigation timing.
Config.Keys = { volumeStep = 5, seekSeconds = 10, scrollPixels = 260, digitTimeoutMs = 1500 }

-- In-hand remote prop/animation. Set enabled=false to hide the prop while the UI is open.
Config.Remote = {
    enabled = true,
    model = 'prop_cs_remote_01',
    bone = 28422,
    pos = vec3(-0.020000, 0.000000, -0.010000), rot = vec3(91.833961, 0.000000, 0.900000),
    dict = 'cellphone@', clip = 'cellphone_text_read_base',
}

-- Optional fixed TVs that start playing a URL automatically at resource startup.
Config.Presets = {
    -- { coords = vec3(0.0, 0.0, 0.0), url = 'https://www.youtube.com/watch?v=abcdefghijk' },
}

-- Optional client-local props. Leave disabled unless you need this resource to create TVs.
Config.SpawnProps = {
    enabled = false,
    list = {
        -- { model = 'prop_tv_flat_01', coords = vec3(0.0, 0.0, 0.0), heading = 0.0 },
    },
}

Config.Locale = Locales[Config.Locale] and Config.Locale or 'en'
Config.Text = Locales[Config.Locale]
Config.Target.label = Config.Text.targetLabel
Config.Target.screenLabel = Config.Text.targetScreenLabel

for _, app in ipairs(Config.Apps) do
    if Config.Text.apps[app.id] then app.label = Config.Text.apps[app.id] end
end

for index, channel in ipairs(Config.Channels) do
    if not channel.name or channel.name == '' then channel.name = Config.Text.channelName:format(index) end
end
