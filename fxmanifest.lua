fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'shocks_vehiclekeys'
author 'SHOCKS Development'
description 'SHOCKS Vehicle Keys - standalone QBCore/Qbox vehicle key and lock system'
version '1.1.0'

provide 'qbx_vehiclekeys'
provide 'qb-vehiclekeys'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'bridge/client/hotwire.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'oxmysql'
}
