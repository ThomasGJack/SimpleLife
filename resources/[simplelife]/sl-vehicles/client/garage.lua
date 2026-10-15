print('[sl-vehicles/client] garage.lua loaded')

-- =============================================================================
-- sl-vehicles / client/garage.lua
-- NPC garage + NUI liste vehicules + spawn/store
-- =============================================================================

local garageNpcPed     = nil
local garageInteractId = nil
local garageOpen       = false

-- =============================================================================
-- Helpers
-- =============================================================================
local function loadModel(model)
  local hash = GetHashKey(model)
  if not IsModelValid(hash) then return false end
  RequestModel(hash)
  local t = 0
  while not HasModelLoaded(hash) do
    Wait(100)
    t = t + 100
    if t > 8000 then return false end
  end
  return true
end

local function getVehicleHealth(veh)
  if not veh or not DoesEntityExist(veh) then return 1000.0, 1000.0 end
  return GetVehicleBodyHealth(veh), GetVehicleEngineHealth(veh)
end

-- =============================================================================
-- Callback client : spawn vehicule
-- Appele par le serveur via lib.callback.await('sl-vehicles:clientSpawnVehicle', src, data)
-- =============================================================================
lib.callback.register('sl-vehicles:clientSpawnVehicle', function(data)
  if not data or not data.model then return 0 end

  if not loadModel(data.model) then return 0 end

  local coords  = vec3(data.coords.x, data.coords.y, data.coords.z)
  local heading = data.heading or 0.0

  local veh = CreateVehicle(GetHashKey(data.model), coords.x, coords.y, coords.z, heading, true, false)
  SetModelAsNoLongerNeeded(GetHashKey(data.model))

  -- Attend que le vehicule existe et soit networked
  local waited = 0
  while not NetworkGetEntityIsNetworked(veh) and waited < 3000 do
    Wait(100)
    waited = waited + 100
  end

  -- Applique la plaque
  if data.plate then
    SetVehicleNumberPlateText(veh, data.plate)
  end

  -- Applique les props si presentes
  if data.props and data.props ~= '' then
    local ok, propsTable = pcall(json.decode, data.props)
    if ok and propsTable then
      lib.setVehicleProperties(veh, propsTable)
    end
  end

  -- Fuel
  SetVehicleFuelLevel(veh, tonumber(data.fuel) or 100)

  -- Health
  SetVehicleBodyHealth(veh, tonumber(data.bodyHealth) or 1000)
  SetVehicleEngineHealth(veh, tonumber(data.engineHealth) or 1000)

  -- Verrouille par defaut
  SetVehicleDoorsLocked(veh, 2)

  local netId = NetworkGetNetworkIdFromEntity(veh)
  return netId
end)

-- =============================================================================
-- Ouvre la NUI garage
-- =============================================================================
local function openGarage()
  if garageOpen then return end
  garageOpen = true

  local list = lib.callback.await('sl-vehicles:listOwned', false)
  if not list then list = {} end

  SetNuiFocus(true, true)
  SendNUIMessage({
    action   = 'openGarage',
    vehicles = list,
  })
end

local function closeGarage()
  if not garageOpen then return end
  garageOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

-- =============================================================================
-- NUI Callbacks : garage
-- =============================================================================
RegisterNUICallback('garage:close', function(_, cb)
  closeGarage()
  cb({ ok = true })
end)

RegisterNUICallback('garage:spawn', function(data, cb)
  if not data or not data.plate then cb({ ok = false }) return end
  local netId = lib.callback.await('sl-vehicles:spawnOwned', false, { plate = data.plate })
  if netId and netId > 0 then
    closeGarage()
    cb({ ok = true, netId = netId })
  else
    cb({ ok = false, err = 'spawn echoue' })
  end
end)

RegisterNUICallback('garage:store', function(data, cb)
  if not data or not data.plate then cb({ ok = false }) return end

  -- Cherche le vehicule
  local allVehs = GetGamePool('CVehicle')
  local targetVeh = nil
  for _, v in ipairs(allVehs) do
    if DoesEntityExist(v) then
      local p = GetVehicleNumberPlateText(v)
      if p and p:gsub('%s+', '') == data.plate:gsub('%s+', '') then
        targetVeh = v
        break
      end
    end
  end

  local fuel        = 100
  local bodyHealth  = 1000
  local engineHealth= 1000

  if targetVeh then
    fuel         = math.floor(GetVehicleFuelLevel(targetVeh) or 100)
    bodyHealth   = GetVehicleBodyHealth(targetVeh)
    engineHealth = GetVehicleEngineHealth(targetVeh)
    -- Sauvegarde les props avant suppression
    local propsOk, propsData = pcall(function() return lib.getVehicleProperties(targetVeh) end)
    if propsOk and propsData then
      data.props = json.encode(propsData)
    end
  end

  TriggerServerEvent('sl:vehicles:requestStore', data.plate, fuel, bodyHealth, engineHealth)
  closeGarage()
  cb({ ok = true })
end)

-- =============================================================================
-- Store par proximite (en dehors NUI)
-- =============================================================================
RegisterNetEvent('sl:vehicles:openGarageStore', function()
  -- Ouvre juste le garage depuis un trigger externe si besoin
  openGarage()
end)

-- =============================================================================
-- Spawn NPC garage
-- =============================================================================
CreateThread(function()
  while not IsCharLoaded do Wait(500) end

  local ok = loadModel(Vehicles.GarageNpcModel)
  if not ok then
    print('[sl-vehicles] WARN: Impossible de charger le modele NPC garage')
    -- Utilise AddZone si NPC indisponible
    garageInteractId = exports['sl-interact']:AddZone({
      coords   = Vehicles.GarageCoords,
      radius   = 3.0,
      label    = 'Garage [E]',
      key      = 'E',
      onSelect = function() openGarage() end,
    })
    return
  end

  local coords  = Vehicles.GarageCoords
  local heading = Vehicles.GarageHeading

  garageNpcPed = CreatePed(4, GetHashKey(Vehicles.GarageNpcModel),
    coords.x, coords.y, coords.z - 1.0, heading, false, true)
  SetEntityInvincible(garageNpcPed, true)
  FreezeEntityPosition(garageNpcPed, true)
  SetBlockingOfNonTemporaryEvents(garageNpcPed, true)
  SetPedCanRagdoll(garageNpcPed, false)
  SetPedHasNoDesperateCover(garageNpcPed, true)
  TaskStartScenarioInPlace(garageNpcPed, 'WORLD_HUMAN_MECHANIC_FIXING_PLAYER', 0, true)
  SetModelAsNoLongerNeeded(GetHashKey(Vehicles.GarageNpcModel))

  garageInteractId = exports['sl-interact']:AddEntity(garageNpcPed, {
    label    = 'Garage [E]',
    key      = 'E',
    distance = 3.0,
    onSelect = function()
      openGarage()
    end,
  })
end)

-- =============================================================================
-- Escape ferme NUI garage
-- =============================================================================
CreateThread(function()
  while true do
    Wait(0)
    if garageOpen and IsControlJustPressed(0, 200) then
      closeGarage()
    end
  end
end)

-- =============================================================================
-- Commande /store : stocker le vehicule dans lequel on est
-- =============================================================================
RegisterCommand('store', function()
  if not IsCharLoaded then return end
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if not veh or veh == 0 then
    lib.notify({ description = 'Vous n\'etes pas dans un vehicule.', type = 'error' })
    return
  end
  local plate = GetVehicleNumberPlateText(veh)
  if not plate then return end

  local fuel         = math.floor(GetVehicleFuelLevel(veh) or 100)
  local bodyHealth   = GetVehicleBodyHealth(veh)
  local engineHealth = GetVehicleEngineHealth(veh)

  TriggerServerEvent('sl:vehicles:requestStore', plate, fuel, bodyHealth, engineHealth)
end, false)
