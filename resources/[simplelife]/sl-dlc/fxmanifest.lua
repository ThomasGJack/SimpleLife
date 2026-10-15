fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-dlc'
author 'SimpleLife'
description 'SimpleLife DLC enabler — load MP maps, IPLs, interiors'
version '0.1.0'

dependencies {
  'sl-core',
}

shared_scripts {
  'shared/config.lua',
}

server_scripts {
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}
