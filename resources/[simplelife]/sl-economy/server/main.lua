print('[sl-economy/server] main.lua loaded')

local SL = exports['sl-core']

Cache = Cache or {}

local function tryIsReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end

local registered = false
local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps = { 'sl-core@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)

CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

local function loadOrCreateBalances(characterId)
  local row = SL:DB().single(
    'SELECT cash, bank, crypto FROM sl_economy_balances WHERE character_id = ?',
    { characterId }
  )
  if row then
    return { cash = row.cash or 0, bank = row.bank or 0, crypto = row.crypto or 0 }
  end
  SL:DB().insert(
    'INSERT INTO sl_economy_balances (character_id, cash, bank, crypto) VALUES (?, ?, ?, ?)',
    { characterId, Economy.Starting.cash, Economy.Starting.bank, Economy.Starting.crypto }
  )
  return {
    cash = Economy.Starting.cash,
    bank = Economy.Starting.bank,
    crypto = Economy.Starting.crypto,
  }
end

AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source = payload.source
  local characterId = payload.characterId
  local balances = loadOrCreateBalances(characterId)
  Cache[source] = {
    characterId = characterId,
    cash = balances.cash,
    bank = balances.bank,
    crypto = balances.crypto,
  }
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:economy:hydrated', { balances = balances })
  print(('[sl-economy] hydrated src=%d cid=%d cash=%d bank=%d crypto=%d'):format(
    source, characterId, balances.cash, balances.bank, balances.crypto))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    Cache[payload.source] = nil
  end
end)

function GetCache(source)
  return Cache[source]
end
