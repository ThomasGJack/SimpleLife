fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-crime'
author 'SimpleLife'
description 'SimpleLife crime — braquages magasins + coffres + culture/packaging/vente drogue'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-economy',
  'sl-inventory',
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
  'client/robbery.lua',
  'client/drugs.lua',
}

files {
  'sql/index.lua',
}
