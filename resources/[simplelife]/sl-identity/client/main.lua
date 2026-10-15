print('[sl-identity/client] main.lua loaded')

-- ===========================================================================
-- sl-identity v0.2 : NUI custom grunge GTA V + caméra 3D + preview ped
--
-- Quand le serveur trigger 'sl-identity:openSelector' :
--   1. on TP le joueur sur un spot isolé (LSIA runway)
--   2. on freeze le ped + on lui applique un modèle freemode par défaut
--   3. on setup une caméra qui le regarde (orbite lente)
--   4. on affiche la NUI (sélecteur ou création selon les persos)
--
-- Au final, sl-core hydrate et déclenche le spawn réel.
-- ===========================================================================

local PREVIEW_COORDS = vec3(-1042.31, -2747.93, 21.36)
local PREVIEW_HEADING = 327.0
local CAM_DISTANCE = 1.8
local CAM_HEIGHT = 0.4
local CAM_ORBIT_SPEED = 0.0   -- 0.0 = fixe, > 0 = orbite (en rad/s)

local uiOpen   = false
local hasFocus = false
local previewCam = nil
local origCoords = nil
local camOrbitAngle = 0.0
local camOrbitRunning = false

local function setFocus(state)
  hasFocus = state
  SetNuiFocus(state, state)
  SetNuiFocusKeepInput(false)
end

-- ===========================================================================
-- Caméra preview : orbite ou fixe autour du ped
-- ===========================================================================
local function setupPreviewCamera()
  if previewCam then DestroyCam(previewCam, false) end
  previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  local ped = PlayerPedId()
  local pos = GetEntityCoords(ped)
  SetCamCoord(previewCam, pos.x + math.cos(math.rad(45.0)) * CAM_DISTANCE, pos.y + math.sin(math.rad(45.0)) * CAM_DISTANCE, pos.z + CAM_HEIGHT)
  PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.1, true)
  SetCamFov(previewCam, 35.0)
  RenderScriptCams(true, false, 0, true, false)
  camOrbitAngle = 45.0

  if camOrbitRunning then return end
  camOrbitRunning = true
  CreateThread(function()
    while previewCam do
      Wait(0)
      if CAM_ORBIT_SPEED > 0 then
        camOrbitAngle = camOrbitAngle + CAM_ORBIT_SPEED
        local p = GetEntityCoords(PlayerPedId())
        SetCamCoord(previewCam,
          p.x + math.cos(math.rad(camOrbitAngle)) * CAM_DISTANCE,
          p.y + math.sin(math.rad(camOrbitAngle)) * CAM_DISTANCE,
          p.z + CAM_HEIGHT)
      end
      -- Cache HUD + radar pendant la NUI
      HideHudAndRadarThisFrame()
    end
    camOrbitRunning = false
  end)
end

local function destroyPreviewCamera()
  if previewCam then
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(previewCam, false)
    previewCam = nil
  end
end

-- ===========================================================================
-- Modèle ped (swap pour création M/F)
-- ===========================================================================
local function loadModel(modelHash)
  if not IsModelInCdimage(modelHash) then return false end
  RequestModel(modelHash)
  local deadline = GetGameTimer() + 5000
  while not HasModelLoaded(modelHash) and GetGameTimer() < deadline do Wait(10) end
  return HasModelLoaded(modelHash)
end

local function applyPreviewModel(sex)
  local model = (sex == 'f') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
  local hash  = GetHashKey(model)
  local current = GetEntityModel(PlayerPedId())
  if current == hash then return end
  if not loadModel(hash) then return end
  SetPlayerModel(PlayerId(), hash)
  SetModelAsNoLongerNeeded(hash)
  Wait(100)
  local ped = PlayerPedId()
  SetPedDefaultComponentVariation(ped)
  SetEntityCoords(ped, PREVIEW_COORDS.x, PREVIEW_COORDS.y, PREVIEW_COORDS.z, false, false, false, false)
  SetEntityHeading(ped, PREVIEW_HEADING)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  -- Re-target la caméra sur le nouveau ped
  if previewCam then PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.1, true) end
end

-- ===========================================================================
-- Spot preview : TP + freeze le ped
-- ===========================================================================
local function enterPreviewSpot(initialSex)
  local ped = PlayerPedId()
  origCoords = GetEntityCoords(ped)
  SetEntityCoords(ped, PREVIEW_COORDS.x, PREVIEW_COORDS.y, PREVIEW_COORDS.z, false, false, false, false)
  SetEntityHeading(ped, PREVIEW_HEADING)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetEntityVisible(ped, true, false)
  applyPreviewModel(initialSex or 'm')
  setupPreviewCamera()
end

local function leavePreviewSpot()
  destroyPreviewCamera()
  -- Laisse sl-core / sl-clothing gérer le respawn final.
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
end

-- ===========================================================================
-- NUI helpers
-- ===========================================================================
local function openSelectorUI()
  if uiOpen then return end
  local chars = lib.callback.await('sl-identity:listCharacters', false) or {}

  -- TP au spot, setup camera, modèle par défaut
  -- Si un perso existe avec un sexe défini, on prend ce sexe par défaut.
  local initialSex = 'm'
  for _, c in ipairs(chars) do
    if c.identity and c.identity.sex then initialSex = c.identity.sex; break end
  end
  enterPreviewSpot(initialSex)

  -- Liste des nationalités pour la création
  local nationalities = {}
  for _, n in ipairs(Identity.Nationalities or {}) do
    nationalities[#nationalities+1] = { value = n.value, label = n.label }
  end

  uiOpen = true
  setFocus(true)
  SendNUIMessage({
    action       = 'open',
    characters   = chars,
    nationalities = nationalities,
    maxSlots     = Identity.MaxSlots or 1,
  })
end

local function closeUI()
  if not uiOpen then return end
  uiOpen = false
  setFocus(false)
  SendNUIMessage({ action = 'close' })
end

-- ===========================================================================
-- NUI callbacks
-- ===========================================================================
RegisterNUICallback('selectSlot', function(data, cb)
  local slot = tonumber(data.slot)
  local res = lib.callback.await('sl-identity:select', false, slot)
  if not res or not res.ok then
    cb({ ok = false, error = res and res.error or 'unknown' })
    return
  end
  closeUI()
  leavePreviewSpot()
  lib.notify({
    type = 'success', title = 'Bienvenue',
    description = ('%s %s'):format(res.character.identity.firstName or '?', res.character.identity.lastName or '?'),
  })
  cb({ ok = true })
end)

RegisterNUICallback('deleteSlot', function(data, cb)
  local slot = tonumber(data.slot)
  local res = lib.callback.await('sl-identity:delete', false, slot)
  if not res or not res.ok then
    cb({ ok = false, error = res and res.error or 'unknown' })
    return
  end
  cb({ ok = true })
  -- Recharge la liste pour refléter la suppression
  CreateThread(function()
    Wait(150)
    local chars = lib.callback.await('sl-identity:listCharacters', false) or {}
    SendNUIMessage({
      action = 'open',
      characters = chars,
      nationalities = (function()
        local out = {}
        for _, n in ipairs(Identity.Nationalities or {}) do out[#out+1] = { value = n.value, label = n.label } end
        return out
      end)(),
      maxSlots = Identity.MaxSlots or 1,
    })
  end)
end)

RegisterNUICallback('changeSex', function(data, cb)
  applyPreviewModel(data.sex or 'm')
  cb({ ok = true })
end)

RegisterNUICallback('previewCharacter', function(data, cb)
  -- Quand on sélectionne un perso dans la liste, on swap le modèle preview
  -- selon le sexe de ce perso (pour matcher visuellement à minima)
  if data.identity and data.identity.sex then
    applyPreviewModel(data.identity.sex)
  end
  cb({ ok = true })
end)

RegisterNUICallback('previewCreate', function(data, cb)
  applyPreviewModel(data.sex or 'm')
  cb({ ok = true })
end)

RegisterNUICallback('previewSelector', function(_, cb)
  cb({ ok = true })
end)

RegisterNUICallback('submitCreate', function(data, cb)
  local res = lib.callback.await('sl-identity:create', false, tonumber(data.slot) or 1, {
    firstName = data.firstName,
    lastName  = data.lastName,
    dob       = data.dob,
    sex       = data.sex,
    nationality = data.nationality,
  })
  if not res or not res.ok then
    cb({ ok = false, error = res and res.error or 'unknown' })
    return
  end
  cb({ ok = true })

  -- Auto-select le perso qu'on vient de créer
  CreateThread(function()
    Wait(300)
    local selRes = lib.callback.await('sl-identity:select', false, tonumber(data.slot) or 1)
    if selRes and selRes.ok then
      closeUI()
      leavePreviewSpot()
      lib.notify({
        type = 'success', title = 'Bienvenue à Los Santos',
        description = ('%s %s'):format(data.firstName, data.lastName),
      })
    end
  end)
end)

-- ===========================================================================
-- Events sl-core
-- ===========================================================================
RegisterNetEvent('sl-identity:openSelector', function()
  print('[sl-identity/client] openSelector event received')
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    Wait(400)
    pcall(ShutdownLoadingScreen)
    pcall(ShutdownLoadingScreenNui)
    Wait(300)
    print('[sl-identity/client] calling openSelectorUI')
    openSelectorUI()
  end)
end)

-- ===========================================================================
-- Commandes (debug)
-- ===========================================================================
RegisterCommand('character', function() openSelectorUI() end, false)
RegisterCommand('chars',     function() openSelectorUI() end, false)

-- Cleanup au resource stop
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    if hasFocus then setFocus(false) end
    destroyPreviewCamera()
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
      FreezeEntityPosition(ped, false)
    end
  end
end)
