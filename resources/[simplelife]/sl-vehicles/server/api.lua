print('[sl-vehicles/server] api.lua loaded')

-- =============================================================================
-- sl-vehicles / server/api.lua
-- Exports publics + events bus
-- =============================================================================

-- Suivi des vehicules spawnes : plate -> netId
local SpawnedNetIds = {}

-- =============================================================================
-- SpawnOwned(src, plate) -> netId | nil
-- Spawne le vehicule cote client (via callback), persiste state='out'
-- =============================================================================
function SpawnOwned(source, plate)
  if not plate or not source then return nil end
  local row = GetVehicleRow(plate)
  if not row then return nil end

  -- Choix du point de spawn
  local spawnPt = Vehicles.SpawnPoints[math.random(1, #Vehicles.SpawnPoints)]

  -- Declenche spawn sur le client du joueur
  -- Le client cree le vehicule, applique les props, retourne le netId
  local netId = lib.callback.await('sl-vehicles:clientSpawnVehicle', source, {
    model        = row.model,
    plate        = row.plate,
    props        = row.props,
    fuel         = tonumber(row.fuel) or 100,
    bodyHealth   = tonumber(row.body_health) or 1000,
    engineHealth = tonumber(row.engine_health) or 1000,
    coords       = { x = spawnPt.coords.x, y = spawnPt.coords.y, z = spawnPt.coords.z },
    heading      = spawnPt.heading,
  })

  if not netId or netId == 0 then return nil end

  -- Persiste state
  SL:DB().update(
    'UPDATE sl_vehicles SET state = ?, position = NULL WHERE plate = ?',
    { 'out', plate })
  if VehicleCache[plate] then VehicleCache[plate].state = 'out' end

  -- S'assure que le proprietaire a bien les cles
  if KeysCache[source] then KeysCache[source][plate] = true end

  SpawnedNetIds[plate] = netId

  -- Bus event
  TriggerEvent('sl:vehicles:spawned', { source = source, netId = netId, plate = plate })
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:vehicles:spawned', { source = source, netId = netId, plate = plate })

  -- Fuel externe (sl-fuel optionnel)
  pcall(function()
    exports['sl-fuel']:SetFuel(netId, tonumber(row.fuel) or 100)
  end)

  return netId
end

-- =============================================================================
-- StoreVehicle(plate, [source], [fuel], [bodyH], [engineH]) -> bool, err
-- Persiste l'etat du vehicule et le passe en state='garage'
-- =============================================================================
function StoreVehicle(plate, source, fuel, bodyHealth, engineHealth)
  if not plate then return false, 'no plate' end
  local row = GetVehicleRow(plate)
  if not row then return false, 'unknown plate' end

  -- Recupere le fuel depuis sl-fuel si dispo
  local finalFuel = tonumber(fuel) or tonumber(row.fuel) or 100
  if SpawnedNetIds[plate] then
    local ok2, fuelVal = pcall(function()
      return exports['sl-fuel']:GetFuel(SpawnedNetIds[plate])
    end)
    if ok2 and type(fuelVal) == 'number' then
      finalFuel = fuelVal
    end
    SpawnedNetIds[plate] = nil
  end

  local finalBodyH   = bodyHealth   or row.body_health   or 1000
  local finalEngineH = engineHealth or row.engine_health or 1000

  SL:DB().update(
    'UPDATE sl_vehicles SET state = ?, fuel = ?, body_health = ?, engine_health = ?, position = NULL WHERE plate = ?',
    { 'garage', math.floor(finalFuel), finalBodyH, finalEngineH, plate })

  if VehicleCache[plate] then
    VehicleCache[plate].state         = 'garage'
    VehicleCache[plate].fuel          = math.floor(finalFuel)
    VehicleCache[plate].body_health   = finalBodyH
    VehicleCache[plate].engine_health = finalEngineH
  end

  -- Bus event
  local src = source or 0
  TriggerEvent('sl:vehicles:stored', { source = src, plate = plate })
  if src > 0 then
    TriggerClientEvent('sl:bus:dispatch', src, 'sl:vehicles:stored', { source = src, plate = plate })
  end

  return true
end

-- =============================================================================
-- GiveKeys(src, plate)
-- =============================================================================
function GiveKeys(source, plate)
  if not source or not plate then return end
  if not KeysCache[source] then KeysCache[source] = {} end
  KeysCache[source][plate] = true
  NotifyKeysChanged(source, plate, true)
end

-- =============================================================================
-- HasKeys(src, plate) -> bool
-- =============================================================================
function HasKeys(source, plate)
  if not source or not plate then return false end
  if not KeysCache[source] then return false end
  return KeysCache[source][plate] == true
end

-- =============================================================================
-- ListOwned(src) -> array de rows
-- =============================================================================
function ListOwned(source)
  local c = Cache[source]
  if not c then return {} end
  local rows = SL:DB().query(
    'SELECT id, plate, model, fuel, body_health, engine_health, state, garage FROM sl_vehicles WHERE character_id = ? ORDER BY created_at ASC',
    { c.characterId })
  return rows or {}
end

-- =============================================================================
-- RegisterOwnership(src, plate, model, props) -> plate
-- Cree un enregistrement vehicule (achat externe, recompense, etc.)
-- =============================================================================
function RegisterOwnership(source, plate, model, props)
  local c = Cache[source]
  if not c then return nil end

  local finalPlate = plate
  if not finalPlate or finalPlate == '' then
    finalPlate = generatePlate()
  end

  local propsJson = props and json.encode(props) or nil
  local insertId  = SL:DB().insert(
    'INSERT INTO sl_vehicles (character_id, plate, model, props, fuel, body_health, engine_health, state, garage) VALUES (?, ?, ?, ?, 100, 1000, 1000, ?, ?)',
    { c.characterId, finalPlate, model, propsJson, 'garage', Vehicles.DefaultGarage })

  if not insertId or insertId == 0 then return nil end

  VehicleCache[finalPlate] = {
    id            = insertId,
    character_id  = c.characterId,
    plate         = finalPlate,
    model         = model,
    props         = propsJson,
    fuel          = 100,
    body_health   = 1000,
    engine_health = 1000,
    state         = 'garage',
    garage        = Vehicles.DefaultGarage,
    position      = nil,
  }
  if KeysCache[source] then KeysCache[source][finalPlate] = true end

  return finalPlate
end

-- =============================================================================
-- GetFuel(plate) -> number
-- =============================================================================
function GetVehicleFuel(plate)
  local row = GetVehicleRow(plate)
  if not row then return 0 end
  return tonumber(row.fuel) or 0
end

-- =============================================================================
-- SetFuel(plate, n)
-- =============================================================================
function SetVehicleFuel(plate, n)
  if not plate then return end
  local v = math.max(0, math.min(100, math.floor(tonumber(n) or 0)))
  SL:DB().update('UPDATE sl_vehicles SET fuel = ? WHERE plate = ?', { v, plate })
  if VehicleCache[plate] then VehicleCache[plate].fuel = v end
end

-- =============================================================================
-- EXPORTS publics
-- =============================================================================
exports('SpawnOwned',         SpawnOwned)
exports('StoreVehicle',       StoreVehicle)
exports('GiveKeys',           GiveKeys)
exports('HasKeys',            HasKeys)
exports('ListOwned',          ListOwned)
exports('RegisterOwnership',  RegisterOwnership)
exports('GetFuel',            GetVehicleFuel)
exports('SetFuel',            SetVehicleFuel)

-- =============================================================================
-- Network events cotes serveur : hotwire reussi, store depuis client
-- =============================================================================

-- Hotwire reussi : donne cles temporaires
RegisterNetEvent('sl:vehicles:hotwireSuccess', function(plate)
  local source = source
  if not plate then return end
  GiveKeys(source, plate)
  TriggerClientEvent('ox_lib:notify', source, {
    description = 'Vehicule demarre ! (cles temporaires)',
    type = 'inform',
  })
end)

-- Client demande de stocker un vehicule (bouton garage ou commande)
RegisterNetEvent('sl:vehicles:requestStore', function(plate, fuel, bodyHealth, engineHealth)
  local source = source
  if not plate then return end
  local c = Cache[source]
  if not c then return end
  local row = SL:DB().single('SELECT id FROM sl_vehicles WHERE plate = ? AND character_id = ?', { plate, c.characterId })
  if not row then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Vous n\'etes pas proprietaire de ce vehicule.', type = 'error' })
    return
  end
  local ok, err = StoreVehicle(plate, source, fuel, bodyHealth, engineHealth)
  if ok then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Vehicule range au garage.', type = 'success' })
    TriggerClientEvent('sl:vehicles:storeAck', source, plate)
  else
    TriggerClientEvent('ox_lib:notify', source, { description = 'Impossible de ranger : ' .. tostring(err), type = 'error' })
  end
end)

-- Client demande de toggle lock
RegisterNetEvent('sl:vehicles:toggleLock', function(plate, netId)
  local source = source
  if not plate then return end
  if not HasKeys(source, plate) then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Vous n\'avez pas les cles.', type = 'error' })
    return
  end
  TriggerClientEvent('sl:vehicles:doToggleLock', source, { plate = plate, netId = netId })
end)

-- Callback hasKeys : client appelle avec false (route auto vers serveur)
lib.callback.register('sl-vehicles:hasKeys', function(source, data)
  if not data or not data.plate then return false end
  return HasKeys(source, data.plate)
end)
