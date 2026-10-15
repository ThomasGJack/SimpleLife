fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-core'
author 'SimpleLife'
description 'SimpleLife core — event bus, module registry, player state, DB layer'
version '0.1.0'

dependencies {
  'oxmysql',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/version.lua',
  'shared/config.lua',
  'shared/utils.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/bus.lua',
  'server/db.lua',
  'server/identifiers.lua',
  'server/modules.lua',
  'server/migrations.lua',
  'server/player.lua',
  'server/persistence.lua',
  'server/save_manager.lua',
  'server/exports.lua',
  'server/commands.lua',
  'server/main.lua',
}

client_scripts {
  'client/bus.lua',
  'client/state.lua',
  'client/world.lua',
  'client/main.lua',
}

files {
  'sql/index.lua',
  'sql/001_init.sql',
}
