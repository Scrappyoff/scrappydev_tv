-- URL parsing and destination safety checks.
Urls = {}

local function trim(s)
    s = tostring(s or '')
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local VIDEO_EXT = { mp4 = true, webm = true, m4v = true, mov = true, ogv = true }
local AUDIO_EXT = { mp3 = true, ogg = true, oga = true, wav = true, m4a = true, aac = true, flac = true, opus = true }
local IMAGE_EXT = { png = true, jpg = true, jpeg = true, gif = true, webp = true, bmp = true, avif = true }

function Urls.Normalize(raw)
    local v = trim(raw)
    if v == '' or v:find('%s') then return nil end
    if not v:match('^%a[%w+.-]*://') then
        if v:match('^[%w%-%.]+%.%a%a+') then v = 'https://' .. v else return nil end
    end
    return v
end

function Urls.Parse(url)
    local scheme, rest = tostring(url or ''):match('^(%a[%w+.-]*)://(.*)$')
    if not scheme then return nil end
    scheme = scheme:lower()
    if scheme ~= 'http' and scheme ~= 'https' then return nil end

    local authority = rest:match('^([^/%?#]*)')
    if not authority or authority == '' or authority:find('@') or authority:find('%[') then return nil end

    local host, port = authority:match('^([^:]+):?(%d*)$')
    if not host then return nil end
    host = host:lower()
    if not host:match('^[%w%-%.]+$') or not host:find('%.') or host:find('%.%.') then return nil end
    if port ~= '' and #port > 5 then return nil end

    if host:match('^%d+%.%d+%.%d+%.%d+$') then return nil end
    if host == 'localhost' or host:match('%.local$') or host:match('%.internal$') or host:match('%.lan$') then return nil end
    if not host:match('%.%a%a+$') then return nil end

    local path = rest:match('^[^/%?#]*(/[^%?#]*)') or '/'
    local query = rest:match('%?([^#]*)') or ''
    return { scheme = scheme, host = host, port = port, path = path, query = query, rest = rest }
end

local function hostIs(host, domain)
    return host == domain or host:sub(-(#domain + 1)) == '.' .. domain
end

function Urls.IsBlacklisted(host, list)
    for _, b in ipairs(list or {}) do
        b = tostring(b):lower()
        if b ~= '' and hostIs(host, b) then return true end
    end
    return false
end

local function queryParam(query, name)
    return query:match('^' .. name .. '=([^&]*)') or query:match('&' .. name .. '=([^&]*)')
end

local function youtubeStart(query)
    local t = queryParam(query, 't') or queryParam(query, 'start')
    if not t then return 0 end
    local h, m, s = t:match('^(%d+)h(%d+)m(%d+)s$')
    if h then return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) end
    m, s = t:match('^(%d+)m(%d+)s$')
    if m then return tonumber(m) * 60 + tonumber(s) end
    local n = t:match('^(%d+)s?$')
    return n and tonumber(n) or 0
end

local function youtubeId(p)
    local id
    if hostIs(p.host, 'youtu.be') then
        id = p.path:match('^/([%w_%-]+)')
    elseif hostIs(p.host, 'youtube.com') or hostIs(p.host, 'youtube-nocookie.com') then
        if p.path == '/watch' then
            id = queryParam(p.query, 'v')
        else
            id = p.path:match('^/embed/([%w_%-]+)') or p.path:match('^/shorts/([%w_%-]+)')
                or p.path:match('^/live/([%w_%-]+)') or p.path:match('^/v/([%w_%-]+)')
        end
    end
    if id and #id == 11 and id:match('^[%w_%-]+$') then return id end
    return nil
end

function Urls.Classify(raw, blacklist, maxLength)
    local url = Urls.Normalize(raw)
    if not url then return nil, 'invalid' end
    if #url > (maxLength or 1800) then return nil, 'toolong' end

    local p = Urls.Parse(url)
    if not p then return nil, 'invalid' end
    if Urls.IsBlacklisted(p.host, blacklist) then return nil, 'blocked' end

    local info = { ok = true, url = url, host = p.host, kind = 'web', label = 'Site web' }

    local yt = youtubeId(p)
    if yt then
        info.kind = 'youtube'
        info.videoId = yt
        info.start = youtubeStart(p.query)
        info.label = 'YouTube'
        return info
    end

    if hostIs(p.host, 'vimeo.com') then
        local id = p.path:match('^/(%d+)') or p.path:match('^/video/(%d+)')
        if id then
            info.url = 'https://player.vimeo.com/video/' .. id .. '?autoplay=1'
            info.label = 'Vimeo'
            return info
        end
    end

    if hostIs(p.host, 'dailymotion.com') or hostIs(p.host, 'dai.ly') then
        local id = p.path:match('^/video/(x[%w]+)') or (hostIs(p.host, 'dai.ly') and p.path:match('^/(x[%w]+)'))
        if id then
            info.url = 'https://www.dailymotion.com/embed/video/' .. id .. '?autoplay=1'
            info.label = 'Dailymotion'
            return info
        end
    end

    local ext = p.path:match('%.(%w+)$')
    ext = ext and ext:lower() or nil
    if ext == 'm3u8' then
        info.kind, info.mediaType, info.label = 'media', 'hls', 'Flux HLS'
    elseif ext and VIDEO_EXT[ext] then
        info.kind, info.mediaType, info.label = 'media', 'video', 'Vidéo'
    elseif ext and AUDIO_EXT[ext] then
        info.kind, info.mediaType, info.label = 'media', 'audio', 'Audio'
    elseif ext and IMAGE_EXT[ext] then
        info.kind, info.label = 'image', 'Image'
    else
        local labels = { ['twitch.tv'] = 'Twitch', ['kick.com'] = 'Kick', ['facebook.com'] = 'Facebook', ['soundcloud.com'] = 'SoundCloud' }
        for domain, label in pairs(labels) do
            if hostIs(p.host, domain) then info.label = label break end
        end
    end
    return info
end

function Urls.Encode(text)
    return (tostring(text or ''):gsub('[^%w%-_%.~]', function(c) return ('%%%02X'):format(c:byte()) end))
end
