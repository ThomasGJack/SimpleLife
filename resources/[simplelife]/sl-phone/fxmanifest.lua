fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-phone'
author 'SimpleLife'
description 'SimpleLife phone — téléphone perso (Messages, Contacts, Appels audio Mumble) iOS dark'
version '0.2.0'

dependencies {
  'sl-core',
  'sl-inventory',
  'sl-economy',
  'sl-jobs',
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
  'server/api_apps.lua',
  'server/commands.lua',
}

client_scripts {
  'client/main.lua',
}

ui_page 'html/index.html'

files {
  'sql/index.lua',
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
