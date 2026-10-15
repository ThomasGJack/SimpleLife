local SL = exports['sl-core']

lib.callback.register('sl-economy:atm:withdraw', function(source, amount)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return { ok = false, error = 'montant invalide' } end

  local entry = Cache[source]
  if not entry then return { ok = false, error = 'economy not loaded' } end

  local fee = Economy.ATM.withdrawFee or 0
  local total = amount + fee
  if (entry.bank or 0) < total then return { ok = false, error = 'fonds bancaires insuffisants' } end

  local removeOk, err = exports['sl-economy']:RemoveMoney(source, 'bank', total, 'atm:withdraw')
  if not removeOk then return { ok = false, error = err or 'echec retrait' } end

  exports['sl-economy']:AddMoney(source, 'cash', amount, 'atm:withdraw')

  return {
    ok = true,
    amount = amount,
    fee = fee,
    newCash = entry.cash,
    newBank = entry.bank,
  }
end)

lib.callback.register('sl-economy:atm:deposit', function(source, amount)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return { ok = false, error = 'montant invalide' } end

  local entry = Cache[source]
  if not entry then return { ok = false, error = 'economy not loaded' } end

  if (entry.cash or 0) < amount then return { ok = false, error = 'liquide insuffisant' } end

  local removeOk, err = exports['sl-economy']:RemoveMoney(source, 'cash', amount, 'atm:deposit')
  if not removeOk then return { ok = false, error = err or 'echec depot' } end

  exports['sl-economy']:AddMoney(source, 'bank', amount, 'atm:deposit')

  return {
    ok = true,
    amount = amount,
    newCash = entry.cash,
    newBank = entry.bank,
  }
end)
