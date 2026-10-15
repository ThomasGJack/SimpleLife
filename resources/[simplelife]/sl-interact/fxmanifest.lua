fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-interact'
author 'SimpleLife'
description 'SimpleLife interact — interactions par visée (entité ou zone) + touche E'
version '0.1.0'

dependencies {
  -- ox_lib non requis : ce module est volontairement standalone
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
