print('[sl-hunger/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, hunger, thirst, lastHungerAt, lastThirstAt, dirty }
-- ===========================================================================
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
    deps = { 'sl-core@^0.1', 'sl-inventory@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Chargement / création des stats au character selected
-- ===========================================================================
local function loadOrCreate(characterId)
  local row = SL:DB().single(
    'SELECT hunger, thirst FROM sl_hunger_stats WHERE character_id = ?',
    { characterId })
  if row then
    return tonumber(row.hunger) or Hunger.StartValue, tonumber(row.thirst) or Hunger.StartValue
  end
  SL:DB().insert(
    'INSERT INTO sl_hunger_stats (character_id, hunger, thirst) VALUES (?, ?, ?)',
    { characterId, Hunger.StartValue, Hunger.StartValue })
  return Hunger.StartValue, Hunger.StartValue
end

local function persistEntry(entry)
  if not entry or not entry.characterId then return end
  SL:DB().query(
    'UPDATE sl_hunger_stats SET hunger = ?, thirst = ? WHERE character_id = ?',
    { entry.hunger, entry.thirst, entry.characterId })
  entry.dirty = false
end

local function pushToClient(source, entry)
  if not entry then return end
  TriggerClientEvent('sl-hunger:sync', source, {
    hunger = entry.hunger,
    thirst = entry.thirst,
    max    = Hunger.MaxValue,
  })
end

function SyncToClient(source)
  pushToClient(source, Cache[source])
end

AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source = payload.source
  local characterId = payload.characterId
  local hunger, thirst = loadOrCreate(characterId)
  local now = os.time()
  Cache[source] = {
    characterId   = characterId,
    hunger        = hunger,
    thirst        = thirst,
    lastHungerAt  = now,
    lastThirstAt  = now,
    lastDamageAt  = now,
    dirty         = false,
  }
  print(('[sl-hunger] hydrated src=%d cid=%d hunger=%d thirst=%d')
    :format(source, characterId, hunger, thirst))
  pushToClient(source, Cache[source])
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    local entry = Cache[payload.source]
    if entry and entry.dirty then persistEntry(entry) end
    Cache[payload.source] = nil
  end
end)

-- ===========================================================================
-- Tick principal toutes les Hunger.ServerTickSec secondes
-- ===========================================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

local lastSaveCheck = os.time()

CreateThread(function()
  while true do
    Wait((Hunger.ServerTickSec or 30) * 1000)
    local now = os.time()

    for source, entry in pairs(Cache) do
      local changed = false

      -- Faim : décrémente d'autant de paliers qu'il s'est écoulé d'intervalles
      local hungerDelta = math.floor((now - entry.lastHungerAt) / Hunger.HungerIntervalSec)
      if hungerDelta > 0 then
        entry.hunger = clamp(entry.hunger - hungerDelta, 0, Hunger.MaxValue)
        entry.lastHungerAt = entry.lastHungerAt + (hungerDelta * Hunger.HungerIntervalSec)
        changed = true
      end

      -- Soif
      local thirstDelta = math.floor((now - entry.lastThirstAt) / Hunger.ThirstIntervalSec)
      if thirstDelta > 0 then
        entry.thirst = clamp(entry.thirst - thirstDelta, 0, Hunger.MaxValue)
        entry.lastThirstAt = entry.lastThirstAt + (thirstDelta * Hunger.ThirstIntervalSec)
        changed = true
      end

      -- Dégâts si une stat est à 0
      if (entry.hunger <= 0 or entry.thirst <= 0)
         and (now - entry.lastDamageAt) >= Hunger.DamageIntervalSec then
        TriggerClientEvent('sl-hunger:damage', source, { dmg = Hunger.DamagePerTick or 1 })
        entry.lastDamageAt = now
      end

      if changed then
        entry.dirty = true
        pushToClient(source, entry)
      end
    end

    -- Sauvegarde périodique des entrées dirty
    if (now - lastSaveCheck) >= (Hunger.SaveIntervalSec or 120) then
      lastSaveCheck = now
      for _, entry in pairs(Cache) do
        if entry.dirty then persistEntry(entry) end
      end
    end
  end
end)

-- Save sync au shutdown du resource
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for _, entry in pairs(Cache) do
    if entry.dirty then persistEntry(entry) end
  end
end)

-- ===========================================================================
-- Helpers exposés
-- ===========================================================================
function GetCache(source) return Cache[source] end

-- Pas de save publique exposée pour l'instant (gérée par tick + drop)
