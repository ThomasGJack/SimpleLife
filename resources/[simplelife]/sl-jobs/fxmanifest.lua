fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-jobs'
author 'SimpleLife'
description 'SimpleLife jobs — métiers, grades, duty, paie automatique'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-economy',
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/jobs.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/api.lua',
  'server/paycheck.lua',
  'server/commands.lua',
}

client_scripts {
  'client/main.lua',
}

files {
  'sql/index.lua',
}
