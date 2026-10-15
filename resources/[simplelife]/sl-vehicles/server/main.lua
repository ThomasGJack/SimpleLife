print('[sl-vehicles/server] main.lua loaded')

-- Global volontairement : consomme aussi par server/api.lua et server/commands.lua
SL = exports['sl-core']

-- =============================================================================
-- Cache : source -> { characterId, keys = { [plate]=true }, dirty }
-- Cache vehicules charges en memoire (par plate)
-- VehicleCache : plate -> row DB (id, characterId, plate, model, props, fuel, body_health, engine_health, state, garage, position)
-- KeysCache    : source -> { [plate] = true }
-- =============================================================================
Cache        = Cache        or {}  -- source -> { characterId }
VehicleCache = VehicleCache or {}  -- plate  -> row
KeysCache    = KeysCache    or {}  -- source -> { [plate] = true }

-- =============================================================================
-- Registration sl-core
-- =============================================================================
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
    name    = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps    = { 'sl-core@^0.1', 'sl-economy@^0.1', 'sl-inventory@^0.1', 'sl-interact@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- =============================================================================
-- characterSelected : hydration
-- =============================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source      = payload.source
  local characterId = payload.characterId

  Cache[source]     = { characterId = characterId }
  KeysCache[source] = {}

  -- Charge les vehicules du perso (lecture legere : on stocke dans VehicleCache)
  local rows = SL:DB().query(
    'SELECT id, character_id, plate, model, props, fuel, body_health, engine_health, state, garage, position FROM sl_vehicles WHERE character_id = ?',
    { characterId })

  if rows then
    for _, row in ipairs(rows) do
      VehicleCache[row.plate] = row
      -- Donne les cles au proprio pour les vehicules qui ne sont pas sortis par quelqu'un d'autre
      KeysCache[source][row.plate] = true
    end
  end

  print(('[sl-vehicles] hydrated src=%d cid=%d vehicles=%d')
    :format(source, characterId, rows and #rows or 0))
end)

-- =============================================================================
-- playerDropped : cleanup
-- =============================================================================
AddEventHandler('sl:core:playerDropped', function(payload)
  if not payload or not payload.source then return end
  local source = payload.source
  Cache[source]     = nil
  KeysCache[source] = nil
end)

-- =============================================================================
-- Generateur de plaque unique
-- Global volontairement (consomme aussi par server/api.lua RegisterOwnership)
-- =============================================================================
function generatePlate()
  local charset = '0123456789'
  local attempts = 0
  while attempts < 100 do
    local digits = ''
    for _ = 1, 5 do
      local idx = math.random(1, #charset)
      digits = digits .. charset:sub(idx, idx)
    end
    local plate = Vehicles.PlatePrefix .. digits
    local existing = SL:DB().single('SELECT id FROM sl_vehicles WHERE plate = ?', { plate })
    if not existing then
      return plate
    end
    attempts = attempts + 1
  end
  -- Fallback : timestamp
  return Vehicles.PlatePrefix .. tostring(os.time() % 99999):sub(1, 5)
end

-- =============================================================================
-- Save sync au shutdown
-- =============================================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  -- Les vehicules sont persistes a chaque operation, rien de specifique ici
end)

-- =============================================================================
-- Callback : liste des vehicules (pour NUI garage)
-- =============================================================================
lib.callback.register('sl-vehicles:listOwned', function(source)
  local c = Cache[source]
  if not c then return {} end
  local rows = SL:DB().query(
    'SELECT id, plate, model, fuel, body_health, engine_health, state, garage FROM sl_vehicles WHERE character_id = ? ORDER BY created_at ASC',
    { c.characterId })
  return rows or {}
end)

-- =============================================================================
-- Callback : spawn owned (depuis garage NUI)
-- =============================================================================
lib.callback.register('sl-vehicles:spawnOwned', function(source, data)
  if not data or not data.plate then return nil, 'no plate' end
  local netId = SpawnOwned(source, data.plate)
  return netId
end)

-- =============================================================================
-- Callback : store vehicle
-- =============================================================================
lib.callback.register('sl-vehicles:storeVehicle', function(source, data)
  if not data or not data.plate then return false, 'no plate' end
  -- Verifie que le perso est proprio
  local c = Cache[source]
  if not c then return false, 'not loaded' end
  local row = SL:DB().single('SELECT id FROM sl_vehicles WHERE plate = ? AND character_id = ?', { data.plate, c.characterId })
  if not row then return false, 'not owner' end

  local ok, err = StoreVehicle(data.plate, source, data.fuel, data.bodyHealth, data.engineHealth)
  return ok, err
end)

-- =============================================================================
-- Callback : buy vehicle (depuis concession NUI)
-- =============================================================================
lib.callback.register('sl-vehicles:buyVehicle', function(source, data)
  if not data or not data.model then return false, 'no model' end
  local c = Cache[source]
  if not c then return false, 'not loaded' end

  local def = Vehicles.GetByModel(data.model)
  if not def then return false, 'unknown model' end

  local price = def.price or 0

  -- Paiement : d'abord cash, sinon bank
  if price > 0 then
    local cash = exports['sl-economy']:GetMoney(source, 'cash')
    if cash and cash >= price then
      local ok = exports['sl-economy']:RemoveMoney(source, 'cash', price, 'achat_vehicule_' .. def.model)
      if not ok then return false, 'paiement echoue' end
    else
      local bank = exports['sl-economy']:GetMoney(source, 'bank')
      if not bank or bank < price then
        return false, 'fonds insuffisants'
      end
      local ok = exports['sl-economy']:RemoveMoney(source, 'bank', price, 'achat_vehicule_' .. def.model)
      if not ok then return false, 'paiement echoue' end
    end
  end

  local plate = generatePlate()
  local insertId = SL:DB().insert(
    'INSERT INTO sl_vehicles (character_id, plate, model, fuel, body_health, engine_health, state, garage) VALUES (?, ?, ?, 100, 1000, 1000, ?, ?)',
    { c.characterId, plate, def.model, 'garage', Vehicles.DefaultGarage })

  if not insertId or insertId == 0 then
    -- Remboursement en cas d'echec DB
    if price > 0 then
      exports['sl-economy']:AddMoney(source, 'cash', price, 'remboursement_vehicule')
    end
    return false, 'db error'
  end

  -- Mise en cache
  VehicleCache[plate] = {
    id            = insertId,
    character_id  = c.characterId,
    plate         = plate,
    model         = def.model,
    props         = nil,
    fuel          = 100,
    body_health   = 1000,
    engine_health = 1000,
    state         = 'garage',
    garage        = Vehicles.DefaultGarage,
    position      = nil,
  }
  KeysCache[source][plate] = true

  -- Donne item cle_voiture avec metadata plate
  pcall(function()
    exports['sl-inventory']:AddItem(source, 'cle_voiture', 1, { plate = plate }, 'achat_vehicule')
  end)

  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Vehicule %s achete ! Plaque : %s'):format(def.label, plate),
    type = 'success',
  })

  return true, plate
end)

-- =============================================================================
-- Helper interne : recupere la row DB d'un vehicule (cache ou DB)
-- =============================================================================
function GetVehicleRow(plate)
  if VehicleCache[plate] then return VehicleCache[plate] end
  local row = SL:DB().single(
    'SELECT id, character_id, plate, model, props, fuel, body_health, engine_health, state, garage, position FROM sl_vehicles WHERE plate = ?',
    { plate })
  if row then VehicleCache[plate] = row end
  return row
end

-- =============================================================================
-- Helper : notifie le changement d'etat de cle
-- =============================================================================
function NotifyKeysChanged(source, plate, has)
  TriggerEvent('sl:vehicles:keysChanged', { source = source, plate = plate, has = has })
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:vehicles:keysChanged', { source = source, plate = plate, has = has })
end
