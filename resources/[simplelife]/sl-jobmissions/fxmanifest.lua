fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-jobmissions'
author 'SimpleLife'
description 'SimpleLife missions civiles : taxi, trucker, mecano, farmer'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-jobs',
  'sl-economy',
  'sl-inventory',
  'sl-interact',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
}

server_scripts {
  -- Pas d acces DB direct : ce module est runtime pur (aucune table SQL).
  -- La persistance eventuelle passe par les exports sl-economy / sl-inventory.
  'server/main.lua',
  'server/api.lua',
}

client_scripts {
  'client/main.lua',
  'client/taxi.lua',
  'client/trucker.lua',
  'client/mechanic.lua',
  'client/farmer.lua',
}
