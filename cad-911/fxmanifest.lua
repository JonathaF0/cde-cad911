fx_version 'cerulean'
game 'gta5'

author 'CDE Inc'
description '911 Emergency Call Integration with CAD System'
version '2.1.0'
repository 'https://github.com/JonathaF0/cde-cad911'

-- Requires nearest-postal for location services
dependency 'nearest-postal'

client_scripts {
    'config.lua',
    'client/main.lua'
}

server_scripts {
    'config.lua',
    'server/main.lua'
}

shared_script 'config.lua'
