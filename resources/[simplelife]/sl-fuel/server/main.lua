print('[sl-fuel/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache runtime : netId -> fuel level (0-100)
-- Pas de table SQL : la persistence est déléguée à sl-vehicles
-- (sl-vehicles stocke fuel dans sl_vehicles.fuel et appelle SetFuel au spawn)
-- ===========================================================================
FuelCache = FuelCache or {}   -- netId (number) -> float

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
    deps    = { 'sl-core@^0.1', 'sl-economy@^0.1', 'sl-interact@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Nettoyage au playerDropped
-- (le cache est par netId de véhicule, pas par source joueur,
--  donc on ne purge pas au drop — sl-vehicles:stored gérera)
-- ===========================================================================
AddEventHandler('sl:core:playerDropped', function(payload)
  -- Rien à purger ici : le véhicule reste potentiellement en monde
  -- sl:vehicles:stored nettoiera via SetFuel(plate) -> sl-vehicles persist
end)

-- ===========================================================================
-- Écoute du bus : sl-vehicles spawn → initialise FuelCache depuis sl-vehicles
-- ===========================================================================
AddEventHandler('sl:vehicles:spawned', function(payload)
  if not payload or not payload.netId then return end
  local netId = tonumber(payload.netId)
  if not netId then return end
  -- Si déjà en cache (respawn rapide), on conserve
  if FuelCache[netId] then return end
  -- Sinon on demande à sl-vehicles le fuel persisté
  local ok, val = pcall(function()
    return exports['sl-vehicles']:GetFuel(payload.plate)
  end)
  if ok and val and type(val) == 'number' then
    FuelCache[netId] = math.max(0, math.min(Fuel.MaxLevel, val))
  else
    FuelCache[netId] = Fuel.StartLevel
  end
  print(('[sl-fuel] spawn netId=%d fuel=%.1f'):format(netId, FuelCache[netId]))
end)

-- ===========================================================================
-- Sauvegarde au resource stop
-- ===========================================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  -- sl-vehicles sera alerté via exports si besoin ; rien à flush ici
  FuelCache = {}
end)
