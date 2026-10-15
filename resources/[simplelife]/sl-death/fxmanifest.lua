fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-death'
author 'SimpleLife'
description 'SimpleLife death — etat mort/down/saignement/respawn hopital'
version '0.1.0'

dependencies {
  'sl-core',
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
  'server/commands.lua',
}

client_scripts {
  'client/main.lua',
}
