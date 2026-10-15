fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-fuel'
author 'SimpleLife'
description 'SimpleLife fuel — jauge carburant, stations-service, bidon essence'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-economy',
  'sl-interact',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/api.lua',
}

client_scripts {
  'client/main.lua',
}
