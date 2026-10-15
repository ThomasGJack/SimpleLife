fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sl-economy'
author 'SimpleLife'
description 'SimpleLife economy — cash, bank, crypto, ATM, transfers'
version '0.1.0'

dependencies {
  'sl-core',
  'sl-interact',
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
  'server/atm.lua',
  'server/commands.lua',
}

client_scripts {
  'client/main.lua',
  'client/atm.lua',
}

ui_page 'html/index.html'

files {
  'sql/index.lua',
  'sql/001_transactions.sql',
  'sql/002_balances.sql',
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
