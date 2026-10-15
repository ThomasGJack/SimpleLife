fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-clothing'
author 'SimpleLife'
description 'SimpleLife clothing — appearance persistence + shops'
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
  'server/shop.lua',
}

client_scripts {
  'client/main.lua',
  'client/shop.lua',
  'client/editor.lua',
}

ui_page 'html/index.html'

files {
  'sql/index.lua',
  'sql/001_appearance.sql',
  'html/index.html',
  'html/style.css',
  'html/script.js',
  'data/besttorso_male.json',
  'data/besttorso_female.json',
}
