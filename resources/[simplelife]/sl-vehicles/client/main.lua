print('[sl-vehicles/client] main.lua loaded')

-- =============================================================================
-- sl-vehicles / client/main.lua
-- Etat local, bus dispatch, verrouillage, hotwire
-- =============================================================================

local IsCharLoaded = false

-- =============================================================================
-- Bus dispatch
-- =============================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:vehicles:keysChanged' then
    -- Rien de specifique cote client pour l'instant (NUI pas impactee)
  elseif event == 'sl:vehicles:spawned' then
    -- Peut etre utilise par sl-fuel, sl-jobmissions
  elseif event == 'sl:vehicles:stored' then
    -- Vehicule range : si c'est le notre et on est dedans, on sort
    if payload and payload.plate then
      local ped = PlayerPedId()
      local veh = GetVehiclePedIsIn(ped, false)
      if veh and veh ~= 0 then
        local existingPlate = GetVehicleNumberPlateText(veh)
        if existingPlate and existingPlate:gsub('%s+', '') == (payload.plate or ''):gsub('%s+', '') then
          TaskLeaveVehicle(ped, veh, 0)
        end
      end
    end
  end
end)

-- =============================================================================
-- characterSelected : signale que le perso est charge
-- =============================================================================
AddEventHandler('sl:core:characterSelected', function()
  IsCharLoaded = true
end)

-- =============================================================================
-- /vehlock : toggle verrouillage du vehicule le plus proche ou dans lequel on est
-- =============================================================================
RegisterCommand('vehlock', function()
  if not IsCharLoaded then return end

  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)

  -- Si pas dans un vehicule, cherche le plus proche
  if not veh or veh == 0 then
    veh = GetClosestVehicle(GetEntityCoords(ped), Vehicles.InteractDistance, 0, 70)
  end

  if not veh or veh == 0 then
    lib.notify({ description = 'Aucun vehicule a proximite.', type = 'error' })
    return
  end

  local plate   = GetVehicleNumberPlateText(veh)
  local netId   = NetworkGetNetworkIdFromEntity(veh)

  TriggerServerEvent('sl:vehicles:toggleLock', plate, netId)
end, false)

-- =============================================================================
-- Receptionne l'ordre de toggle lock du serveur
-- =============================================================================
RegisterNetEvent('sl:vehicles:doToggleLock', function(data)
  if not data or not data.netId then return end
  local veh = NetworkGetEntityFromNetworkId(data.netId)
  if not veh or veh == 0 or not DoesEntityExist(veh) then return end

  local locked = GetVehicleDoorsLockedForAllPlayers(veh)
  -- locked : 0=unlocked, 1=locked for peds (mais pas joueur), 2=full lock
  -- On toggle entre unlocked (0) et locked (2)
  if locked == 2 then
    SetVehicleDoorsLocked(veh, 0)
    lib.notify({ description = 'Vehicule deverrouille.', type = 'inform' })
  else
    SetVehicleDoorsLocked(veh, 2)
    lib.notify({ description = 'Vehicule verrouille.', type = 'inform' })
  end
end)

-- =============================================================================
-- Receptionne l'ACK de store (vehicule supprime par le serveur)
-- =============================================================================
RegisterNetEvent('sl:vehicles:storeAck', function(plate)
  -- Supprime l'entite locale si encore presente
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh and veh ~= 0 then
    local existingPlate = GetVehicleNumberPlateText(veh)
    if existingPlate and existingPlate:gsub('%s+', '') == (plate or ''):gsub('%s+', '') then
      TaskLeaveVehicle(ped, veh, 0)
      Wait(500)
    end
  end
  -- Cherche et supprime aussi s'il traine
  local allVehs = GetGamePool('CVehicle')
  if allVehs then
    for _, v in ipairs(allVehs) do
      if DoesEntityExist(v) then
        local p = GetVehicleNumberPlateText(v)
        if p and p:gsub('%s+', '') == (plate or ''):gsub('%s+', '') then
          if NetworkGetEntityIsNetworked(v) then
            SetEntityAsMissionEntity(v, true, true)
          end
          DeleteEntity(v)
          break
        end
      end
    end
  end
end)

-- =============================================================================
-- HOTWIRE : detection + appui E geres par le thread unique plus bas
-- (l'ancien thread de prompt redondant a ete retire : il affichait un TextUI
--  jamais masque et spammait le callback serveur)
-- =============================================================================
local hotwireActive = false
local hotwireVeh    = nil

RegisterNetEvent('sl:vehicles:startHotwire', function(plate, netId)
  -- Declenche le mini-jeu hotwire
  hotwireActive = true
  hotwireVeh    = { plate = plate, netId = netId }
  startHotwireMinigame(plate, netId)
end)

function startHotwireMinigame(plate, netId)
  lib.hideTextUI()

  local success = lib.progressBar({
    duration = Vehicles.HotwireDuration,
    label    = 'Crocheter le vehicule...',
    useWhileDead = false,
    canCancel    = true,
    disable = { move = true, car = false, combat = true },
    anim = {
      dict   = 'mp_arresting',
      clip   = 'a_uncuff',
      flags  = 49,
    },
  })

  hotwireActive = false
  hotwireVeh    = nil

  if success then
    TriggerServerEvent('sl:vehicles:hotwireSuccess', plate)
    -- Demarre le moteur localement
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
      SetVehicleEngineOn(veh, true, true, false)
    end
    lib.notify({ description = 'Vehicule demarre !', type = 'success' })
  else
    lib.notify({ description = 'Crochetage echoue.', type = 'error' })
  end
end

-- =============================================================================
-- Thread de detection appui E pour hotwire
-- =============================================================================
CreateThread(function()
  local lastCheck = 0
  while true do
    Wait(0)
    if not IsCharLoaded then Wait(2000) goto continue2 end

    local ped  = PlayerPedId()
    local veh  = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 or hotwireActive then
      Wait(500)
      goto continue2
    end

    local now = GetGameTimer()
    if (now - lastCheck) < 2000 then goto continue2 end
    lastCheck = now

    if GetIsVehicleEngineRunning(veh) then goto continue2 end

    local plate = GetVehicleNumberPlateText(veh)
    if not plate then goto continue2 end

    local hasK = lib.callback.await('sl-vehicles:hasKeys', false, { plate = plate })
    if hasK then goto continue2 end

    local hasItem = exports['sl-inventory']:HasItem('lockpick', 1)
    if not hasItem then goto continue2 end

    -- Affiche et attend E
    lib.showTextUI('[E] Crocheter le vehicule', { position = 'left-center' })
    Wait(100)

    while not GetIsVehicleEngineRunning(veh) and GetVehiclePedIsIn(ped, false) == veh do
      if IsControlJustPressed(0, 38) then -- E
        lib.hideTextUI()
        local netId = NetworkGetNetworkIdFromEntity(veh)
        startHotwireMinigame(plate, netId)
        break
      end
      Wait(0)
    end
    lib.hideTextUI()

    ::continue2::
  end
end)

-- Callback hasKeys est enregistre cote serveur dans server/api.lua
