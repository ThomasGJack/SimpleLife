print('[sl-economy/client] main.lua loaded')

ClientEconomy = ClientEconomy or { balances = { cash = 0, bank = 0, crypto = 0 } }

local function syncNativeStats()
  local b = ClientEconomy.balances or {}
  local cash = math.floor(b.cash or 0)
  local bank = math.floor(b.bank or 0)
  pcall(function() StatSetInt(`MP0_WALLET_BALANCE`, cash, true) end)
  pcall(function() StatSetInt(`MP0_BANK_BALANCE`, bank, true) end)
  pcall(function() StatSetInt(`BANK_BALANCE`, bank, true) end)
end

local function notifyChange(account, delta, balance, reason)
  local sign = delta >= 0 and '+' or ''
  local color = delta >= 0 and 'success' or 'error'
  local title = account == 'cash' and 'Liquide' or (account == 'bank' and 'Banque' or 'Crypto')
  lib.notify({
    type = color,
    title = title .. ' ' .. sign .. Economy.FormatMoney(delta),
    description = ('Solde : %s%s'):format(Economy.FormatMoney(balance), reason and (' • ' .. reason) or ''),
    duration = 4000,
    position = 'top-right',
  })
end

AddEventHandler('sl:economy:hydrated', function(payload)
  if payload and payload.balances then
    ClientEconomy.balances = payload.balances
    print(('[sl-economy/client] hydrated cash=%s bank=%s'):format(tostring(payload.balances.cash), tostring(payload.balances.bank)))
    syncNativeStats()
  end
end)

AddEventHandler('sl:economy:moneyChanged', function(payload)
  if not payload or not payload.account then return end
  ClientEconomy.balances[payload.account] = payload.balance
  print(('[sl-economy/client] %s %s%d -> %s'):format(payload.account, payload.delta >= 0 and '+' or '', payload.delta, tostring(payload.balance)))
  syncNativeStats()
  notifyChange(payload.account, payload.delta, payload.balance, payload.reason)
end)

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(1000)
  local b = lib.callback.await('sl-economy:getBalances', false)
  if b then
    ClientEconomy.balances = b
    syncNativeStats()
    print(('[sl-economy/client] initial fetch: cash=%s bank=%s'):format(tostring(b.cash), tostring(b.bank)))
  end
end)

exports('GetClientBalances', function()
  return ClientEconomy.balances
end)

RegisterCommand('balance', function()
  local b = ClientEconomy.balances
  lib.notify({
    type = 'inform',
    title = 'Tes soldes',
    description = ('Liquide : %s\nBanque : %s\nCrypto : %s'):format(
      Economy.FormatMoney(b.cash or 0),
      Economy.FormatMoney(b.bank or 0),
      Economy.FormatMoney(b.crypto or 0)
    ),
    duration = 6000,
    position = 'top-right',
  })
end, false)

RegisterCommand('pay', function(source, args)
  local target = tonumber(args[1])
  local amount = tonumber(args[2])
  if not target or not amount or amount <= 0 then
    lib.notify({ type = 'error', title = 'Usage', description = '/pay <id> <montant>' })
    return
  end
  local res = lib.callback.await('sl-economy:transferToPlayer', false, target, 'cash', amount, 'p2p:cash')
  if res == true then
    lib.notify({ type = 'success', title = 'Paiement', description = ('Envoyé : %s à ID %d'):format(Economy.FormatMoney(amount), target) })
  else
    lib.notify({ type = 'error', title = 'Paiement refusé', description = tostring(res) })
  end
end, false)
