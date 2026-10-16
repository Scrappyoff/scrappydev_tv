-- Scrappy.Dev TV source manifest. escrow_ignore also supports optional Tebex packaging.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'scrappydev_tv'
author 'Scrappy.Dev'
description 'Synchronized televisions, video playback and an in-game browser'
version '1.0.0'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua',
    'locales/*.lua',
    'config.lua',
    'shared/urls.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/main.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/main.lua',
    'server/version.lua',
}

ui_page 'html/ui/index.html'

files {
    'html/ui/index.html',
    'html/ui/ui.css',
    'html/ui/ui.js',
    'html/i18n.js',
    'html/player.html',
    'html/player.css',
    'html/player.js',
    'html/img/*.png',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'install/*',
    'install/images/*',
    'docs/*',
}
