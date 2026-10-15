print('[sl-fuel/client] main.lua loaded')

-- ===========================================================================
-- État local
-- fuelByNet[netId] = 0-100 (jauge runtime côté client)
-- ===========================================================================
local fuelByNet      = {}   -- netId (number) -> float
local currentNetId   = nil  -- netId du véhicule actuellement conduit
local lastAlertLevel = nil  -- pour ne notifier qu'une fois par seuil descendant
local interactIds    = {}   -- ids retournés par sl-interact (pour cleanup)

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

local function round1(v)
  return math.floor(v * 10 + 0.5) / 10
end

-- Envoie le niveau au HUD local (sl-hud écoute sl:fuel:update côté client)
local function pushHud(netId, level)
  TriggerEvent('sl:fuel:update', { netId = netId, level = level })
end

-- Vérifie les seuils d'alerte (passage descendant)
local function checkAlerts(level)
  for _, threshold in ipairs(Fuel.AlertThresholds) do
    if (lastAlertLevel == nil or lastAlertLevel > threshold) and level <= threshold then
      if threshold <= 5.0 then
        lib.notify({
          description = 'Carburant CRITIQUE — trouvez une station immédiatement !',
          type        = 'error',
          duration    = 7000,
        })
      else
        lib.notify({
          description = ('Carburant faible : %.0f%%'):format(level),
          type        = 'warning',
          duration    = 5000,
        })
      end
    end
  end
  lastAlertLevel = level
end

-- ===========================================================================
-- Thread principal : consommation + cale moteur
-- ===========================================================================
CreateThread(function()
  local lastTickMs  = GetGameTimer()
  local lastSendMs  = 0
  local SEND_DELAY  = Fuel.ConsumeTickMs   -- ms entre envois réseau

  while true do
    Wait(Fuel.ConsumeTickMs)

    local now  = GetGameTimer()
    local dt   = (now - lastTickMs) / 1000.0
    lastTickMs = now

    local ped  = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then goto continue end

    local veh  = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
      currentNetId   = nil
      lastAlertLevel = nil
      goto continue
    end

    -- Seulement si on est conducteur (siège 0)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
      goto continue
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    if not netId or netId == 0 then goto continue end

    -- Première fois qu'on voit ce véhicule : fetch serveur
    if not fuelByNet[netId] then
      fuelByNet[netId] = Fuel.StartLevel
      -- Fetch async (ne bloque pas le thread)
      CreateThread(function()
        local level = lib.callback.await('sl-fuel:getLevel', false, netId)
        if level and type(level) == 'number' then
          fuelByNet[netId] = clamp(level, 0, Fuel.MaxLevel)
          SetVehicleFuelLevel(veh, fuelByNet[netId])
          pushHud(netId, fuelByNet[netId])
          lastAlertLevel = fuelByNet[netId]
        end
      end)
      goto continue
    end

    currentNetId = netId
    local fuel   = fuelByNet[netId]

    -- Si moteur éteint, on ne consomme pas
    if not IsVehicleEngineOn(veh) then
      goto continue
    end

    -- Calcul consommation
    local rpm    = GetVehicleCurrentRpm(veh)           -- 0.0 - 1.0
    local speed  = GetEntitySpeed(veh)                  -- m/s
    local consume = (Fuel.BaseConsumption
                     + rpm   * Fuel.RpmFactor
                     + speed * Fuel.SpeedFactor) * dt

    local newFuel = clamp(fuel - consume, 0, Fuel.MaxLevel)
    fuelByNet[netId] = newFuel

    -- Cale le moteur si réservoir vide
    if newFuel <= Fuel.StallLevel then
      if IsVehicleEngineOn(veh) then
        SetVehicleEngineOn(veh, false, true, true)
      end
      SetVehicleFuelLevel(veh, 0.0)
    else
      SetVehicleFuelLevel(veh, newFuel)
    end

    -- Push HUD
    pushHud(netId, newFuel)
    checkAlerts(newFuel)

    -- Envoie la consommation au serveur (batché, pas à chaque tick)
    if (now - lastSendMs) >= SEND_DELAY then
      lastSendMs = now
      local delta = round1(fuel - newFuel)
      if delta > 0 then
        TriggerServerEvent('sl-fuel:consume', netId, delta)
      end
    end

    ::continue::
  end
end)

-- ===========================================================================
-- Réception serveur → client (confirmation niveau après refuel/consume/useCan)
-- Via le bus sl:bus:dispatch
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event ~= 'sl:fuel:update' then return end
  if not payload or not payload.netId then return end
  local netId = tonumber(payload.netId)
  local level = tonumber(payload.level)
  if not netId or not level then return end
  fuelByNet[netId] = clamp(level, 0, Fuel.MaxLevel)
  -- Applique immédiatement au véhicule si c'est celui qu'on conduit
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh and veh ~= 0 and DoesEntityExist(veh) then
    if NetworkGetNetworkIdFromEntity(veh) == netId then
      SetVehicleFuelLevel(veh, fuelByNet[netId])
      pushHud(netId, fuelByNet[netId])
      checkAlerts(fuelByNet[netId])
    end
  end
end)

-- ===========================================================================
-- Stations-service — interactions monde
-- ===========================================================================
local function openRefuelDialog(netId)
  -- Vérifie que le joueur est dans/près d'un véhicule arrêté
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if not veh or veh == 0 or not DoesEntityExist(veh) then
    -- Cherche le véhicule le plus proche
    veh = GetClosestVehicle(GetEntityCoords(ped), Fuel.StationVehicleDistance, 0, 70)
  end
  if not veh or veh == 0 or not DoesEntityExist(veh) then
    lib.notify({ description = 'Aucun véhicule à proximité.', type = 'error' })
    return
  end
  local vehSpeed = GetEntitySpeed(veh)
  if vehSpeed > 1.0 then
    lib.notify({ description = 'Le véhicule doit être arrêté.', type = 'error' })
    return
  end

  local vehNetId = NetworkGetNetworkIdFromEntity(veh)
  local current  = fuelByNet[vehNetId] or Fuel.StartLevel
  local spaceLeft = Fuel.MaxLevel - current

  if spaceLeft <= 0.5 then
    lib.notify({ description = 'Le réservoir est déjà plein.', type = 'inform' })
    return
  end

  local maxLiters = math.floor(spaceLeft)
  local maxCost   = math.ceil(spaceLeft * Fuel.PricePerUnit)

  -- Dialogue de saisie de la quantité
  local input = lib.inputDialog('Faire le plein', {
    {
      type        = 'number',
      label       = ('Litres (max %.0f L — %d$)'):format(spaceLeft, maxCost),
      description = ('Prix : %.2f$/L — Réservoir : %.0f%%'):format(Fuel.PricePerUnit, current),
      default     = maxLiters,
      min         = 1,
      max         = maxLiters,
      required    = true,
    },
  })

  if not input or not input[1] then return end
  local liters = tonumber(input[1])
  if not liters or liters <= 0 then return end

  TriggerServerEvent('sl-fuel:refuel', vehNetId, liters)
end

-- Enregistre les zones d'interaction pour chaque station
local function registerStations()
  for i, station in ipairs(Fuel.Stations) do
    local id = exports['sl-interact']:AddZone({
      coords   = station.coords,
      radius   = station.radius or 4.0,
      label    = station.label .. ' — Faire le plein [E]',
      key      = 'E',
      onSelect = function()
        -- netId passé via closure — on le résout au moment du clic
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local resolvedNetId = nil
        if veh and veh ~= 0 and DoesEntityExist(veh) then
          resolvedNetId = NetworkGetNetworkIdFromEntity(veh)
        end
        openRefuelDialog(resolvedNetId)
      end,
    })
    interactIds[i] = id
  end
end

-- ===========================================================================
-- Bidon essence — hook sl-inventory:effect (event CLIENT)
-- sl-inventory (server InventoryUseItem) émet pour l'item bidon_essence :
--   TriggerClientEvent('sl-inventory:effect', source, { type='tool', tool='fuel_can', metadata=... })
-- NOTE : sl:inventory:itemUsed est un event SERVEUR (TriggerEvent), il ne
--        remonte JAMAIS au client. On écoute donc bien sl-inventory:effect.
-- ===========================================================================
RegisterNetEvent('sl-inventory:effect', function(effect)
  if not effect then return end
  -- On réagit uniquement à l'usage du bidon (type tool, tool='fuel_can')
  local isCan = (effect.type == 'tool' and effect.tool == 'fuel_can')
  if not isCan then return end

  -- Trouve le véhicule le plus proche
  local ped    = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local veh    = GetClosestVehicle(coords, Fuel.CanDistance, 0, 70)
  if not veh or veh == 0 or not DoesEntityExist(veh) then
    lib.notify({ description = 'Aucun véhicule assez proche pour verser le bidon.', type = 'error' })
    return
  end

  local netId = NetworkGetNetworkIdFromEntity(veh)
  TriggerServerEvent('sl-fuel:useCan', netId)
end)

-- ===========================================================================
-- Exports client (pour sl-hud et tout autre consommateur)
-- ===========================================================================

--- GetFuel(netId) -> float|nil
exports('GetFuel', function(netId)
  return fuelByNet[tonumber(netId)]
end)

--- SetFuel(netId, level) — override local (après SetFuel serveur)
exports('SetFuel', function(netId, level)
  netId = tonumber(netId)
  level = tonumber(level)
  if not netId or not level then return end
  fuelByNet[netId] = clamp(level, 0, Fuel.MaxLevel)
  pushHud(netId, fuelByNet[netId])
end)

--- Consume(netId, amount) -> new_level
exports('Consume', function(netId, amount)
  netId  = tonumber(netId)
  amount = tonumber(amount)
  if not netId or not amount then return nil end
  local cur = fuelByNet[netId]
  if cur == nil then return nil end
  local newVal = clamp(cur - amount, 0, Fuel.MaxLevel)
  fuelByNet[netId] = newVal
  return newVal
end)

-- ===========================================================================
-- Init : enregistrement des stations au chargement
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  -- Attend que le monde soit chargé
  CreateThread(function()
    Wait(1500)
    -- Purge les anciennes zones si re-select (reconnexion)
    for _, id in ipairs(interactIds) do
      pcall(function() exports['sl-interact']:Remove(id) end)
    end
    interactIds = {}
    registerStations()
  end)
end)
