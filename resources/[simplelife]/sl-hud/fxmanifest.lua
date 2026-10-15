fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-hud'
author 'SimpleLife'
description 'SimpleLife HUD — NUI overlay (money, health, armor, ID)'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-economy',
  'ox_lib',
}

-- Soft dependency: sl-jobs (HUD adapte si présent)

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
}

server_scripts {
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
