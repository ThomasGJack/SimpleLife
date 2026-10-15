fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-voice'
author 'SimpleLife'
description 'SimpleLife voice — chat de proximité 3 modes (chuchoter / normal / crier) via Mumble'
version '0.1.0'

dependencies {
  'sl-core',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
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
