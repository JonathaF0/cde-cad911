fx_version 'cerulean'
game 'gta5'

author 'CAD System Integration'
description '911 Emergency Call Integration with CAD System'
version '1.0.0'
repository 'https://github.com/yourusername/cad-911'

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
