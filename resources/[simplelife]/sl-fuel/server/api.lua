print('[sl-fuel/server] api.lua loaded')

-- ===========================================================================
-- Helpers internes
-- ===========================================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

-- Pousse le niveau courant au client propriétaire (broadcast léger)
-- On utilise le bus sl:bus:dispatch vers tous les clients pour que sl-hud
-- puisse aussi recevoir — mais l'event sl:fuel:update est local au client.
local function pushToSource(source, netId, level)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:fuel:update', {
    netId = netId,
    level = level,
  })
end

-- ===========================================================================
-- API publique serveur
-- ===========================================================================

--- GetFuel(netId) -> number (0-100) ou nil
local function GetFuel(netId)
  netId = tonumber(netId)
  if not netId then return nil end
  return FuelCache[netId]
end

--- SetFuel(netId, level) -> bool
local function SetFuel(netId, level)
  netId = tonumber(netId)
  level = tonumber(level)
  if not netId or not level then return false end
  level = clamp(level, 0, Fuel.MaxLevel)
  FuelCache[netId] = level
  -- Notifie tous les clients proches via broadcast ciblé source = -1 (world)
  -- On ne connait pas le source ici ; le client sync en pull via callback
  return true
end

--- Consume(netId, amount) -> new_level (float) ou nil
local function Consume(netId, amount)
  netId  = tonumber(netId)
  amount = tonumber(amount)
  if not netId or not amount then return nil end
  local current = FuelCache[netId]
  if current == nil then return nil end
  local newLevel = clamp(current - amount, 0, Fuel.MaxLevel)
  FuelCache[netId] = newLevel
  return newLevel
end

-- Exports accessibles aux autres ressources
exports('GetFuel', GetFuel)
exports('SetFuel', SetFuel)
exports('Consume', Consume)

-- ===========================================================================
-- Callback client : le client interroge le niveau de son véhicule au spawn
-- ===========================================================================
lib.callback.register('sl-fuel:getLevel', function(source, netId)
  netId = tonumber(netId)
  if not netId then return nil end
  local level = FuelCache[netId]
  if level == nil then
    -- Véhicule inconnu → on initialise avec StartLevel
    FuelCache[netId] = Fuel.StartLevel
    level = Fuel.StartLevel
  end
  return level
end)

-- ===========================================================================
-- Event client → serveur : le client envoie sa consommation calculée
-- (tick 500 ms, montant = consommation locale)
-- ===========================================================================
RegisterNetEvent('sl-fuel:consume', function(netId, amount)
  local source = source
  netId  = tonumber(netId)
  amount = tonumber(amount)
  if not netId or not amount or amount <= 0 then return end
  -- Sanity check : on plafonne la consommation max acceptable par tick
  -- (max raisonnable : ~0.05 u/s * 0.5 s * 10x sécurité = 0.25 u par tick)
  if amount > 1.0 then amount = 1.0 end
  local newLevel = Consume(netId, amount)
  if newLevel == nil then return end
  -- Push retour au client pour confirmer
  pushToSource(source, netId, newLevel)
end)

-- ===========================================================================
-- Event client → serveur : ravitaillement station
-- Payload : { netId, liters }
-- ===========================================================================
RegisterNetEvent('sl-fuel:refuel', function(netId, liters)
  local source = source
  netId  = tonumber(netId)
  liters = tonumber(liters)
  if not netId or not liters or liters <= 0 then return end

  local current = FuelCache[netId]
  if current == nil then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Véhicule introuvable.', type = 'error',
    })
    return
  end

  -- Plafonne : on ne peut remplir que ce qu'il manque
  local spaceLeft = Fuel.MaxLevel - current
  if spaceLeft <= 0 then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Le réservoir est plein.', type = 'inform',
    })
    return
  end
  local actualLiters = math.min(liters, spaceLeft)
  local cost = math.ceil(actualLiters * Fuel.PricePerUnit)

  -- Vérifie le solde
  local balance = 0
  local ok, val = pcall(function()
    return exports['sl-economy']:GetMoney(source, 'cash')
  end)
  if ok and val then balance = tonumber(val) or 0 end

  if balance < cost then
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Solde insuffisant : %d$ requis.'):format(cost), type = 'error',
    })
    return
  end

  -- Débite
  local removed = false
  local rok = pcall(function()
    removed = exports['sl-economy']:RemoveMoney(source, 'cash', cost, 'carburant')
  end)
  if not rok or not removed then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Erreur lors du paiement.', type = 'error',
    })
    return
  end

  -- Remonte le fuel
  local newLevel = clamp(current + actualLiters, 0, Fuel.MaxLevel)
  FuelCache[netId] = newLevel

  -- Confirme au client
  pushToSource(source, netId, newLevel)
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Plein de %.0f L — %d$ débités.'):format(actualLiters, cost),
    type = 'success',
  })
  print(('[sl-fuel] refuel src=%d netId=%d liters=%.1f cost=%d newLevel=%.1f')
    :format(source, netId, actualLiters, cost, newLevel))
end)

-- ===========================================================================
-- Event client → serveur : bidon essence
-- Payload : { netId }
-- ===========================================================================
RegisterNetEvent('sl-fuel:useCan', function(netId)
  local source = source
  netId = tonumber(netId)
  if not netId then return end

  local current = FuelCache[netId]
  if current == nil then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Aucun véhicule détecté.', type = 'error',
    })
    return
  end

  local spaceLeft = Fuel.MaxLevel - current
  if spaceLeft <= 0 then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Le réservoir est plein.', type = 'inform',
    })
    return
  end

  local actualLiters = math.min(Fuel.CanAmount, spaceLeft)
  local newLevel     = clamp(current + actualLiters, 0, Fuel.MaxLevel)
  FuelCache[netId]   = newLevel

  pushToSource(source, netId, newLevel)
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Bidon versé : +%.0f L (réservoir : %.0f%%)'):format(actualLiters, newLevel),
    type = 'success',
  })
  print(('[sl-fuel] can src=%d netId=%d +%.1f newLevel=%.1f')
    :format(source, netId, actualLiters, newLevel))
end)
