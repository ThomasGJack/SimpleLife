fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-crafting'
author 'SimpleLife'
description 'SimpleLife crafting — etablis, recettes, NUI grunge'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-inventory',
  'sl-interact',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/recipes.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/api.lua',
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
