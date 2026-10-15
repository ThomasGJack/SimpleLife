fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-admin'
author 'SimpleLife'
description 'SimpleLife admin — side panel grunge GTA V (debug, joueur, online)'
version '0.2.0'

dependencies {
  'sl-core',
  'ox_lib',     -- pour lib.notify quand le panel admin est fermé
}

shared_scripts {
  '@ox_lib/init.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
