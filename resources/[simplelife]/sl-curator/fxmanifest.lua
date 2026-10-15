fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-curator'
author 'SimpleLife'
description 'SimpleLife clothing curator — Tinder-style vote outfits'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-clothing',
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
  'server/generator.lua',
}

client_scripts {
  'client/main.lua',
}

ui_page 'html/index.html'

files {
  'sql/index.lua',
  'sql/001_compat.sql',
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
