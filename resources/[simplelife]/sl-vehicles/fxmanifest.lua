fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-vehicles'
author 'SimpleLife'
description 'SimpleLife vehicles -- concession NPC, garage perso, cles, verrouillage, hotwire'
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
  'shared/vehicles.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/api.lua',
  'server/commands.lua',
}

client_scripts {
  'client/main.lua',
  'client/concession.lua',
  'client/garage.lua',
}

ui_page 'html/index.html'

files {
  'sql/index.lua',
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
