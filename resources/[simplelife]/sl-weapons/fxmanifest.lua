fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-weapons'
author 'SimpleLife'
description 'SimpleLife weapons — holster, draw, munitions depuis inventaire'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-inventory',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  '@sl-inventory/shared/items.lua',
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
