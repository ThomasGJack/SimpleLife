fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-identity'
author 'SimpleLife'
description 'SimpleLife identity — création/sélection NUI grunge GTA V + preview 3D'
version '0.2.0'

dependencies {
  'sl-core',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/creation.lua',
  'server/selection.lua',
}

client_scripts {
  'client/main.lua',
  -- selector.lua et creation_ui.lua sont devenus des stubs legacy, non inclus
}

ui_page 'html/index.html'

files {
  'sql/index.lua',
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
