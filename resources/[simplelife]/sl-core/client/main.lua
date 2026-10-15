print('[sl-core/client] main.lua loaded')

local selectionCam = nil

local function setupSelectionCam()
  if selectionCam then return end
  selectionCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  SetCamCoord(selectionCam, 712.5, 1198.2, 350.0)
  SetCamRot(selectionCam, -25.0, 0.0, 180.0, 2)
  SetCamFov(selectionCam, 55.0)
  RenderScriptCams(true, false, 0, true, true)
end

local function teardownSelectionCam()
  if not selectionCam then return end
  RenderScriptCams(false, false, 0, true, true)
  DestroyCam(selectionCam, true)
  selectionCam = nil
end

SL.State.SetupSelectionCam = setupSelectionCam
SL.State.TeardownSelectionCam = teardownSelectionCam

local function forceFreemodeModel()
  local hash = joaat('mp_m_freemode_01')
  if not IsModelValid(hash) or not IsModelInCdimage(hash) then
    print('[sl-core/client] WARN: mp_m_freemode_01 not valid in this build')
    return false
  end
  local current = GetEntityModel(PlayerPedId())
  if current == hash then return true end
  RequestModel(hash)
  local t = 0
  while not HasModelLoaded(hash) and t < 200 do
    Wait(50); t = t + 1
  end
  if not HasModelLoaded(hash) then
    print('[sl-core/client] WARN: mp_m_freemode_01 model load timeout')
    return false
  end
  SetPlayerModel(PlayerId(), hash)
  SetModelAsNoLongerNeeded(hash)
  Wait(100)
  local newPed = PlayerPedId()
  SetPedDefaultComponentVariation(newPed)
  print('[sl-core/client] default freemode model forced (was ' .. current .. ', now ' .. GetEntityModel(newPed) .. ')')
  return true
end

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(100) end
  print('[sl-core/client] session started')

  if GetResourceState('spawnmanager') == 'started' then
    exports.spawnmanager:setAutoSpawn(false)
    print('[sl-core/client] spawnmanager autospawn disabled')
  end

  DoScreenFadeOut(0)
  Wait(200)

  forceFreemodeModel()

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, false, false)
  SetEntityInvincible(ped, true)
  SetPlayerInvincible(PlayerId(), true)

  setupSelectionCam()
  Wait(300)
  pcall(ShutdownLoadingScreen)
  pcall(ShutdownLoadingScreenNui)
  DoScreenFadeIn(800)
  print('[sl-core/client] player frozen on selection cam, waiting for menu')
end)

SL.Bus.On('sl:core:characterSelected', function(payload)
  print('[sl-core/client] characterSelected received: ' .. tostring(payload and payload.citizenId))
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end

    local pped = PlayerPedId()
    local waits = 0
    while (pped == 0 or not DoesEntityExist(pped)) and waits < 100 do
      Wait(100)
      pped = PlayerPedId()
      waits = waits + 1
    end
    if pped == 0 then print('[sl-core/client] FATAL: ped never appeared'); return end

    local p = (payload and payload.position) or {
      x = Config.DefaultSpawn.x,
      y = Config.DefaultSpawn.y,
      z = Config.DefaultSpawn.z,
      heading = Config.DefaultSpawn.heading,
    }
    p.x = p.x + 0.0; p.y = p.y + 0.0; p.z = p.z + 0.0

    DoScreenFadeOut(500)
    Wait(600)

    teardownSelectionCam()

    FreezeEntityPosition(pped, true)
    SetEntityCoords(pped, p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(pped, p.heading or 0.0)

    RequestCollisionAtCoord(p.x, p.y, p.z)
    local tries = 0
    while not HasCollisionLoadedAroundEntity(pped) and tries < 50 do
      Wait(100)
      RequestCollisionAtCoord(p.x, p.y, p.z)
      tries = tries + 1
    end
    print('[sl-core/client] collision loaded after ' .. tries .. ' tries')

    SetEntityCoords(pped, p.x, p.y, p.z, false, false, false, false)
    FreezeEntityPosition(pped, false)
    SetEntityVisible(pped, true, false)
    SetEntityInvincible(pped, false)
    SetPlayerInvincible(PlayerId(), false)

    NetworkResurrectLocalPlayer(p.x, p.y, p.z, p.heading or 0.0, true, false)
    ClearPedTasksImmediately(pped)
    RemoveAllPedWeapons(pped, true)
    ClearPlayerWantedLevel(PlayerId())
    SetGameplayCamRelativeHeading(0)

    pcall(ShutdownLoadingScreen)
    pcall(ShutdownLoadingScreenNui)
    TriggerEvent('playerSpawned', { x = p.x, y = p.y, z = p.z, heading = p.heading or 0.0 })

    if payload and payload.vehicleNetId and payload.vehicleNetId > 0 then
      CreateThread(function()
        local tries = 0
        local veh = 0
        while tries < 30 and (veh == 0 or not DoesEntityExist(veh)) do
          veh = NetworkGetEntityFromNetworkId(payload.vehicleNetId)
          if veh ~= 0 and DoesEntityExist(veh) then break end
          Wait(200)
          tries = tries + 1
        end
        if veh ~= 0 and DoesEntityExist(veh) then
          local seatIdx = payload.seat or -2
          TaskWarpPedIntoVehicle(pped, veh, seatIdx)
          print('[sl-core/client] AFK reconnect: warped into vehicle (seat ' .. seatIdx .. ')')
        else
          print('[sl-core/client] AFK reconnect: vehicle not found locally')
        end
      end)
    end

    DoScreenFadeIn(800)
    SL.State.spawned = true
    print('[sl-core/client] spawned at ' .. tostring(p.x) .. ',' .. tostring(p.y) .. ',' .. tostring(p.z))
  end)
end)

RegisterCommand('sl_debug', function()
  print('=== SL CLIENT DEBUG ===')
  print('SL.State.loaded = ' .. tostring(SL.State.loaded))
  print('SL.State.spawned = ' .. tostring(SL.State.spawned))
  print('SL.State.citizenId = ' .. tostring(SL.State.citizenId))
  print('lib (ox_lib) = ' .. tostring(lib))
  print('Identity = ' .. tostring(Identity))
  print('OpenCharacterSelector fn = ' .. tostring(OpenCharacterSelector))
  print('======================')
end, false)

RegisterCommand('sl_force_menu', function()
  if OpenCharacterSelector then OpenCharacterSelector() else print('OpenCharacterSelector not defined yet') end
end, false)

RegisterCommand('sl_unfreeze', function()
  local p = PlayerPedId()
  teardownSelectionCam()
  FreezeEntityPosition(p, false)
  SetEntityVisible(p, true, false)
  SetEntityInvincible(p, false)
  SetPlayerInvincible(PlayerId(), false)
  pcall(ShutdownLoadingScreen)
  pcall(ShutdownLoadingScreenNui)
  DoScreenFadeIn(800)
  print('[sl-core/client] manually unfrozen + faded in')
end, false)

RegisterCommand('sl_hide_loading', function()
  pcall(ShutdownLoadingScreen)
  pcall(ShutdownLoadingScreenNui)
  print('[sl-core/client] loading screen shutdown forced')
end, false)

local lastSyncPos = nil

local function getCurrentVehicleInfo(ped)
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or not DoesEntityExist(veh) then return 0, -2 end
  local netId = NetworkGetNetworkIdFromEntity(veh)
  local seat = -2
  local maxSeats = GetVehicleMaxNumberOfPassengers(veh)
  for s = -1, maxSeats - 1 do
    if GetPedInVehicleSeat(veh, s) == ped then seat = s; break end
  end
  return netId or 0, seat
end

local function sendCurrentPosition(force)
  if not SL.State.spawned then return end
  local ped = PlayerPedId()
  if not ped or ped == 0 or not DoesEntityExist(ped) then return end
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  local vehNetId, seat = getCurrentVehicleInfo(ped)

  if not force and lastSyncPos and vehNetId == 0 then
    local minDist = Config.PositionSyncMinDistance or 1.0
    local dx = coords.x - lastSyncPos.x
    local dy = coords.y - lastSyncPos.y
    local dz = coords.z - lastSyncPos.z
    if (dx * dx + dy * dy + dz * dz) < (minDist * minDist) then
      return
    end
  end

  lastSyncPos = { x = coords.x, y = coords.y, z = coords.z }
  TriggerServerEvent('sl:core:updatePosition', {
    x = coords.x, y = coords.y, z = coords.z, heading = heading,
  })
  TriggerServerEvent('sl:core:syncSnapshot', {
    x = coords.x, y = coords.y, z = coords.z, heading = heading,
    vehicleNetId = vehNetId, seat = seat,
  })
end

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  local interval = (Config.PositionSyncSec or 3) * 1000
  while true do
    Wait(interval)
    pcall(sendCurrentPosition, false)
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  pcall(sendCurrentPosition, true)
end)

RegisterCommand('sl_save_pos', function()
  sendCurrentPosition(true)
  print('[sl-core/client] position sent to server')
end, false)
