print('[sl-vehicles/client] concession.lua loaded')

-- =============================================================================
-- sl-vehicles / client/concession.lua
-- NPC concession + NUI + preview vehicule + camera orbitale
-- =============================================================================

local concessionNpcPed    = nil
local concessionInteractId = nil
local previewVehicle      = nil
local previewCamera       = nil
local orbitAngle          = 0.0
local orbitRunning        = false
local concessionOpen      = false

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

-- =============================================================================
-- Preview vehicule : spawn un vehicule en face du joueur + camera orbitale
-- =============================================================================
local function stopPreview()
  orbitRunning = false
  if previewCamera then
    DestroyCam(previewCamera, false)
    RenderScriptCams(false, false, 0, true, true)
    previewCamera = nil
  end
  if previewVehicle and DoesEntityExist(previewVehicle) then
    DeleteEntity(previewVehicle)
    previewVehicle = nil
  end
end

local function startPreview(model)
  stopPreview()

  if not loadModel(model) then return end

  local ped    = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading= GetEntityHeading(ped)

  -- Spawn le vehicule 8m devant le joueur
  local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 8.0, 0.0)
  previewVehicle = CreateVehicle(GetHashKey(model), offset.x, offset.y, offset.z, heading + 180.0, false, false)
  SetEntityInvincible(previewVehicle, true)
  FreezeEntityPosition(previewVehicle, true)
  SetVehicleEngineOn(previewVehicle, false, true, true)
  SetModelAsNoLongerNeeded(GetHashKey(model))

  -- Camera orbitale
  previewCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  RenderScriptCams(true, false, 0, true, true)
  orbitAngle   = 0.0
  orbitRunning = true

  CreateThread(function()
    while orbitRunning and previewVehicle and DoesEntityExist(previewVehicle) do
      Wait(0)
      orbitAngle = (orbitAngle + Vehicles.PreviewCamera.speed * 0.016) % (2 * math.pi)
      local vCoords = GetEntityCoords(previewVehicle)
      local r       = Vehicles.PreviewCamera.radius
      local h       = Vehicles.PreviewCamera.height
      local cx = vCoords.x + r * math.cos(orbitAngle)
      local cy = vCoords.y + r * math.sin(orbitAngle)
      local cz = vCoords.z + h
      SetCamCoord(previewCamera, cx, cy, cz)
      PointCamAtCoord(previewCamera, vCoords.x, vCoords.y, vCoords.z + 0.5)
    end
  end)
end

-- =============================================================================
-- Ouvre la NUI concession
-- =============================================================================
local function openConcession()
  if concessionOpen then return end
  concessionOpen = true

  -- Construit le catalogue pour la NUI
  local catalog = {}
  for _, v in ipairs(Vehicles.Catalog) do
    catalog[#catalog+1] = {
      model    = v.model,
      label    = v.label,
      category = v.category,
      price    = v.price,
    }
  end

  -- Construit les categories
  local cats = {}
  for _, c in ipairs(Vehicles.Categories) do
    cats[#cats+1] = { key = c.key, label = c.label, icon = c.icon }
  end

  SetNuiFocus(true, true)
  SendNUIMessage({
    action   = 'openConcession',
    catalog  = catalog,
    categories = cats,
  })
end

local function closeConcession()
  if not concessionOpen then return end
  concessionOpen = false
  stopPreview()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

-- =============================================================================
-- NUI Callbacks : concession
-- =============================================================================
RegisterNUICallback('concession:close', function(_, cb)
  closeConcession()
  cb({ ok = true })
end)

RegisterNUICallback('concession:preview', function(data, cb)
  if data and data.model then
    CreateThread(function()
      startPreview(data.model)
    end)
  end
  cb({ ok = true })
end)

RegisterNUICallback('concession:buy', function(data, cb)
  if not data or not data.model then cb({ ok = false, err = 'no model' }) return end
  local ok, result = lib.callback.await('sl-vehicles:buyVehicle', false, { model = data.model })
  cb({ ok = ok, plate = result })
end)

-- =============================================================================
-- Spawn NPC concession
-- =============================================================================
CreateThread(function()
  -- Attend que le perso soit charge
  while not IsCharLoaded do Wait(500) end

  local ok = loadModel(Vehicles.ConcessionNpcModel)
  if not ok then
    print('[sl-vehicles] WARN: Impossible de charger le modele NPC concession')
    return
  end

  local coords  = Vehicles.ConcessionCoords
  local heading = Vehicles.ConcessionHeading

  concessionNpcPed = CreatePed(4, GetHashKey(Vehicles.ConcessionNpcModel),
    coords.x, coords.y, coords.z - 1.0, heading, false, true)
  SetEntityInvincible(concessionNpcPed, true)
  FreezeEntityPosition(concessionNpcPed, true)
  SetBlockingOfNonTemporaryEvents(concessionNpcPed, true)
  SetPedCanRagdoll(concessionNpcPed, false)
  SetPedHasNoDesperateCover(concessionNpcPed, true)
  TaskStartScenarioInPlace(concessionNpcPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
  SetModelAsNoLongerNeeded(GetHashKey(Vehicles.ConcessionNpcModel))

  -- AddEntity interact
  concessionInteractId = exports['sl-interact']:AddEntity(concessionNpcPed, {
    label    = 'Concession [E]',
    key      = 'E',
    distance = 3.0,
    onSelect = function()
      openConcession()
    end,
  })
end)

-- =============================================================================
-- Escape ferme la NUI
-- =============================================================================
CreateThread(function()
  while true do
    Wait(0)
    if concessionOpen and IsControlJustPressed(0, 200) then -- Escape
      closeConcession()
    end
  end
end)
