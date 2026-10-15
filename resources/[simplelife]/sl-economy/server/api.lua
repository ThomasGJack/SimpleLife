local SL = exports['sl-core']

local function getEntry(source)
  local entry = Cache[source]
  if not entry then return nil, 'economy not loaded for source ' .. tostring(source) end
  return entry, nil
end

local function persist(entry)
  SL:DB().update(
    'UPDATE sl_economy_balances SET cash = ?, bank = ?, crypto = ? WHERE character_id = ?',
    { entry.cash, entry.bank, entry.crypto, entry.characterId }
  )
end

local function logTransaction(characterId, account, delta, balanceAfter, reason, counterpartyId)
  if not characterId then return end
  pcall(function()
    SL:DB().insert(
      'INSERT INTO sl_transactions (character_id, account, delta, balance_after, reason, counterparty_id) VALUES (?, ?, ?, ?, ?, ?)',
      { characterId, account, delta, balanceAfter, reason or '', counterpartyId }
    )
  end)
end

local function emitChange(source, account, delta, balance, reason)
  local payload = { source = source, account = account, delta = delta, balance = balance, reason = reason }
  TriggerEvent('sl:economy:moneyChanged', payload)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:economy:moneyChanged', payload)
end

local function addMoney(source, account, amount, reason)
  if not Economy.IsValidAccount(account) then return false, 'invalid account' end
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return false, 'amount must be > 0' end

  local entry, err = getEntry(source)
  if not entry then return false, err end

  entry[account] = (entry[account] or 0) + amount
  persist(entry)
  logTransaction(entry.characterId, account, amount, entry[account], reason, nil)
  emitChange(source, account, amount, entry[account], reason)
  return true, entry[account]
end

local function removeMoney(source, account, amount, reason)
  if not Economy.IsValidAccount(account) then return false, 'invalid account' end
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return false, 'amount must be > 0' end

  local entry, err = getEntry(source)
  if not entry then return false, err end

  local current = entry[account] or 0
  if current < amount then return false, 'insufficient funds' end

  entry[account] = current - amount
  persist(entry)
  logTransaction(entry.characterId, account, -amount, entry[account], reason, nil)
  emitChange(source, account, -amount, entry[account], reason)
  return true, entry[account]
end

local function getMoney(source, account)
  local entry = Cache[source]
  if not entry then return 0 end
  return entry[account] or 0
end

local function getBalances(source)
  local entry = Cache[source]
  if not entry then return nil end
  return { cash = entry.cash or 0, bank = entry.bank or 0, crypto = entry.crypto or 0 }
end

local function transfer(fromSource, toSource, account, amount, reason)
  if not Economy.IsValidAccount(account) then return false, 'invalid account' end
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return false, 'amount must be > 0' end
  if amount > Economy.Limits.maxTransfer then return false, 'amount exceeds transfer limit' end
  if fromSource == toSource then return false, 'cannot transfer to self' end

  local fromEntry = Cache[fromSource]
  local toEntry = Cache[toSource]
  if not fromEntry then return false, 'sender economy not loaded' end
  if not toEntry then return false, 'recipient economy not loaded' end

  if (fromEntry[account] or 0) < amount then return false, 'insufficient funds' end

  fromEntry[account] = fromEntry[account] - amount
  toEntry[account] = (toEntry[account] or 0) + amount

  persist(fromEntry)
  persist(toEntry)

  logTransaction(fromEntry.characterId, account, -amount, fromEntry[account], reason or 'transfer-out', toEntry.characterId)
  logTransaction(toEntry.characterId, account, amount, toEntry[account], reason or 'transfer-in', fromEntry.characterId)

  emitChange(fromSource, account, -amount, fromEntry[account], reason or 'transfer')
  emitChange(toSource, account, amount, toEntry[account], reason or 'transfer')

  TriggerEvent('sl:economy:transferCompleted', {
    fromSource = fromSource, toSource = toSource,
    account = account, amount = amount, reason = reason,
  })
  return true
end

local function getRecentTransactions(source, limit)
  local entry = Cache[source]
  if not entry or not entry.characterId then return {} end
  limit = math.min(math.max(tonumber(limit) or 20, 1), 100)
  local rows = SL:DB().query(
    'SELECT id, account, delta, balance_after, reason, counterparty_id, created_at FROM sl_transactions WHERE character_id = ? ORDER BY created_at DESC LIMIT ' .. limit,
    { entry.characterId }
  )
  return rows or {}
end

exports('AddMoney', addMoney)
exports('RemoveMoney', removeMoney)
exports('GetMoney', getMoney)
exports('GetBalances', getBalances)
exports('Transfer', transfer)
exports('GetRecentTransactions', getRecentTransactions)

lib.callback.register('sl-economy:getBalances', function(source)
  local b = getBalances(source) or { cash = 0, bank = 0, crypto = 0 }
  print(('[sl-economy] cb getBalances src=%s -> cash=%s bank=%s crypto=%s'):format(
    tostring(source), tostring(b.cash), tostring(b.bank), tostring(b.crypto)))
  return b
end)

lib.callback.register('sl-economy:transactions', function(source, limit)
  return getRecentTransactions(source, limit or 20)
end)

lib.callback.register('sl-economy:transferToPlayer', function(source, targetServerId, account, amount, reason)
  return transfer(source, targetServerId, account, amount, reason or 'p2p')
end)

-- transferByNumber : virement depuis la NUI banque par numero de telephone.
-- Resout le destinataire via sl-phone GetCharacterByNumber puis trouve sa source active.
lib.callback.register('sl-economy:transferByNumber', function(source, phoneNumber, amount, reason)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return { ok = false, error = 'montant invalide' } end

  -- Resoudre le numero de telephone en characterId (via sl-phone si disponible).
  -- sl-phone:GetCharacterByNumber(num) retourne directement le characterId numerique
  -- (sl_characters.id) ou nil, PAS une table.
  local targetCharacterId = nil
  local ok, result = pcall(function()
    return exports['sl-phone']:GetCharacterByNumber(phoneNumber)
  end)
  if ok and result then
    targetCharacterId = tonumber(result) or result
  end

  if not targetCharacterId then
    return { ok = false, error = 'numero introuvable' }
  end

  -- Trouver la source du joueur cible parmi les joueurs connectes.
  -- SL:GetPlayers() renvoie un tableau d'OBJETS player (avec .source), pas des ids.
  local targetSource = nil
  local players = SL:GetPlayers()
  for _, p in ipairs(players) do
    local src = type(p) == 'table' and p.source or p
    local entry = Cache[src]
    if entry and (tostring(entry.characterId) == tostring(targetCharacterId)) then
      targetSource = src
      break
    end
  end

  if not targetSource then
    return { ok = false, error = 'joueur non connecte' }
  end

  if targetSource == source then
    return { ok = false, error = 'impossible de se virer a soi-meme' }
  end

  local senderEntry = Cache[source]
  if not senderEntry then return { ok = false, error = 'economy non chargee' } end

  local ok2, result2 = transfer(source, targetSource, 'bank', amount, reason ~= '' and reason or 'virement')
  if not ok2 then
    return { ok = false, error = result2 or 'echec virement' }
  end

  local newBank = senderEntry.bank or 0
  return { ok = true, newBank = newBank }
end)
