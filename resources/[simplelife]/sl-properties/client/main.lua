print('[sl-properties/client] main.lua loaded')

-- ===========================================================================
-- Etat local
-- ===========================================================================
local ownedProps   = {}   -- array de proprietes { id, label, enter_pos, interior_pos, ipl }
local currentPropId = nil -- propriete dans laquelle le joueur se trouve actuellement
local agentPeds    = {}   -- { pedHandle, interactId }
local enterZones   = {}   -- propId -> interactId
local stashZone    = nil  -- interactId zone coffre courante
local exitZone     = nil  -- interactId zone sortie courante
local nuiOpen      = false
local stashPropId  = nil  -- propriete dont le coffre est ouvert

-- ===========================================================================
-- Utilitaires
-- ===========================================================================
local function vec3FromTable(t)
  if not t then return nil end
  return vec3(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
end

local function removeEnterZone(propId)
  if enterZones[propId] then
    exports['sl-interact']:Remove(enterZones[propId])
    enterZones[propId] = nil
  end
end

local function removeAgents()
  for _, data in ipairs(agentPeds) do
    if data.interactId then exports['sl-interact']:Remove(data.interactId) end
    if DoesEntityExist(data.ped) then DeleteEntity(data.ped) end
  end
  agentPeds = {}
end

local function removeInteriorZones()
  if stashZone then exports['sl-interact']:Remove(stashZone) stashZone = nil end
  if exitZone  then exports['sl-interact']:Remove(exitZone)  exitZone  = nil end
end

-- ===========================================================================
-- Spawn PNJ agent immobilier (freeze + invincible)
-- ===========================================================================
local function spawnAgent(agentDef)
  local modelHash = GetHashKey(agentDef.model)
  RequestModel(modelHash)
  local waited = 0
  while not HasModelLoaded(modelHash) and waited < 5000 do
    Wait(100)
    waited = waited + 100
  end
  if not HasModelLoaded(modelHash) then
    print('[sl-properties] modele agent non charge : ' .. agentDef.model)
    return nil
  end

  local ped = CreatePed(4, modelHash, agentDef.coords.x, agentDef.coords.y, agentDef.coords.z - 1.0,
                        agentDef.coords.w, false, true)
  SetEntityInvincible(ped, true)
  FreezeEntityPosition(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedDiesWhenInjured(ped, false)
  SetPedCanRagdoll(ped, false)
  SetModelAsNoLongerNeeded(modelHash)

  local interactId = exports['sl-interact']:AddEntity(ped, {
    label    = agentDef.label,
    key      = 'E',
    distance = 3.0,
    onSelect = function()
      openAgencyNUI()
    end,
  })

  return { ped = ped, interactId = interactId }
end

-- ===========================================================================
-- NUI agence immobiliere
-- ===========================================================================
function openAgencyNUI()
  local available = lib.callback.await('sl:properties:getAvailable', false)
  local owned     = lib.callback.await('sl:properties:getOwned', false)
  ownedProps = owned or {}

  SetNuiFocus(true, true)
  nuiOpen = true
  SendNUIMessage({
    action    = 'openAgency',
    available = available or {},
    owned     = ownedProps or {},
  })
end

-- ===========================================================================
-- Enregistrement des zones d'entree pour les proprietes possedees
-- ===========================================================================
local function registerEnterZone(prop)
  if enterZones[prop.id] then return end  -- deja enregistre

  local coords = vec3FromTable(prop.enter_pos)
  if not coords then return end

  enterZones[prop.id] = exports['sl-interact']:AddZone({
    coords   = coords,
    radius   = Properties.EnterRadius,
    label    = prop.label .. ' [E]',
    key      = 'E',
    onSelect = function()
      TriggerServerEvent('sl:properties:enter', prop.id)
    end,
  })
end

local function refreshEnterZones()
  -- Retire toutes les zones existantes
  for propId, _ in pairs(enterZones) do
    removeEnterZone(propId)
  end
  -- Re-enregistre pour chaque propriete possedee
  for _, prop in ipairs(ownedProps) do
    registerEnterZone(prop)
  end
end

-- ===========================================================================
-- Enregistrement des zones interieur (coffre + sortie)
-- ===========================================================================
local function setupInteriorZones(propId, interiorPos)
  removeInteriorZones()

  local coords = vec3FromTable(interiorPos)
  if not coords then return end

  -- Zone coffre (offset 1m devant)
  local stashCoords = vec3(
    coords.x + 0.5,
    coords.y + 1.0,
    coords.z
  )
  stashZone = exports['sl-interact']:AddZone({
    coords   = stashCoords,
    radius   = Properties.StashRadius,
    label    = 'Coffre [E]',
    key      = 'E',
    onSelect = function()
      TriggerServerEvent('sl:properties:openStash', propId)
    end,
  })

  -- Zone sortie
  exitZone = exports['sl-interact']:AddZone({
    coords   = coords,
    radius   = Properties.ExitRadius,
    label    = 'Sortir [E]',
    key      = 'E',
    onSelect = function()
      TriggerServerEvent('sl:properties:exit', propId)
    end,
  })
end

-- ===========================================================================
-- Entree dans une propriete
-- ===========================================================================
local function doEnter(payload)
  currentPropId = payload.propId
  local inter = payload.interior_pos
  if not inter then return end

  -- Fade out
  DoScreenFadeOut(500)
  Wait(520)

  -- Charge l'IPL si necessite
  if payload.ipl and payload.ipl ~= '' then
    RequestIpl(payload.ipl)
    local waited = 0
    while not IsIplActive(payload.ipl) and waited < 3000 do
      Wait(100)
      waited = waited + 100
    end
  end

  local ped = PlayerPedId()
  local x = tonumber(inter.x) or 0
  local y = tonumber(inter.y) or 0
  local z = tonumber(inter.z) or 0
  local h = tonumber(inter.heading) or 0.0

  SetEntityCoords(ped, x, y, z, false, false, false, false)
  SetEntityHeading(ped, h)

  Wait(200)
  DoScreenFadeIn(500)

  lib.notify({ description = payload.label .. ' — Bienvenue chez vous.', type = 'inform', duration = 4000 })

  setupInteriorZones(payload.propId, inter)
end

-- ===========================================================================
-- Sortie d'une propriete
-- ===========================================================================
local function doExit(payload)
  removeInteriorZones()
  currentPropId = nil

  local epos = payload.enter_pos
  if not epos then return end

  DoScreenFadeOut(500)
  Wait(520)

  local ped = PlayerPedId()
  SetEntityCoords(ped,
    tonumber(epos.x) or 0,
    tonumber(epos.y) or 0,
    (tonumber(epos.z) or 0) + 0.5,
    false, false, false, false
  )
  SetEntityHeading(ped, 0.0)

  Wait(200)
  DoScreenFadeIn(500)
  lib.notify({ description = 'Vous avez quitte votre appartement.', type = 'inform' })
end

-- ===========================================================================
-- Coffre : ouverture NUI
-- ===========================================================================
local function openStashNUI(payload)
  stashPropId = payload.propId
  SetNuiFocus(true, true)
  nuiOpen = true
  SendNUIMessage({
    action    = 'openStash',
    propId    = payload.propId,
    label     = payload.label,
    slots     = payload.slots,
    slotCount = payload.slotCount,
    maxWeight = payload.maxWeight,
    catalog   = payload.catalog,
  })
end

-- ===========================================================================
-- Bus events client
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:properties:doEnter' then
    doEnter(payload)
  elseif event == 'sl:properties:doExit' then
    doExit(payload)
  elseif event == 'sl:properties:stashOpen' then
    openStashNUI(payload)
  elseif event == 'sl:properties:owned' then
    -- Une nouvelle propriete vient d'etre acquise : refresh zones
    CreateThread(function()
      local owned = lib.callback.await('sl:properties:getOwned', false)
      if owned then
        ownedProps = owned
        refreshEnterZones()
      end
    end)
  end
end)

-- ===========================================================================
-- Character selected
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  CreateThread(function()
    Wait(1000)  -- laisse le serveur hydrater

    -- Spawn agents
    spawnAgents()

    -- Charge les proprietes possedees et enregistre les zones
    local owned = lib.callback.await('sl:properties:getOwned', false)
    ownedProps = owned or {}
    refreshEnterZones()
  end)
end)

-- ===========================================================================
-- Spawn des agents
-- ===========================================================================
function spawnAgents()
  removeAgents()
  for _, agentDef in ipairs(Properties.Agents) do
    local data = spawnAgent(agentDef)
    if data then
      agentPeds[#agentPeds + 1] = data
    end
  end
end

-- ===========================================================================
-- NUI callbacks
-- ===========================================================================

-- Fermeture NUI (Esc ou bouton)
RegisterNUICallback('close', function(_, cb)
  SetNuiFocus(false, false)
  nuiOpen = false
  stashPropId = nil
  SendNUIMessage({ action = 'close' })
  cb({ ok = true })
end)

-- Achat propriete
RegisterNUICallback('buy', function(data, cb)
  local propId = tonumber(data.propId)
  if not propId then cb({ ok = false, reason = 'invalid_id' }) return end
  TriggerServerEvent('sl:properties:buy', propId)
  cb({ ok = true })
end)

-- Depot coffre : item depuis inventaire joueur vers coffre
RegisterNUICallback('stashDeposit', function(data, cb)
  if not stashPropId then cb({ ok = false }) return end
  local ok, reason = lib.callback.await('sl:properties:stashDeposit', false,
    stashPropId, data.slot, data.item, data.count)
  if ok then
    -- Rafraichit le coffre
    TriggerServerEvent('sl:properties:openStash', stashPropId)
  else
    SendNUIMessage({ action = 'toast', text = 'Depot impossible : ' .. tostring(reason), type = 'error' })
  end
  cb({ ok = ok, reason = reason })
end)

-- Retrait coffre
RegisterNUICallback('stashWithdraw', function(data, cb)
  if not stashPropId then cb({ ok = false }) return end
  local ok, item, count = lib.callback.await('sl:properties:stashWithdraw', false,
    stashPropId, data.slot, data.count)
  if ok then
    SendNUIMessage({ action = 'toast', text = (count .. 'x ' .. tostring(item) .. ' retire'), type = 'success' })
    -- Rafraichit le coffre
    TriggerServerEvent('sl:properties:openStash', stashPropId)
  else
    local msgs = {
      empty      = 'Slot vide.',
      too_heavy  = 'Trop lourd pour votre inventaire.',
      no_access  = 'Acces refuse.',
      add_failed = 'Erreur ajout inventaire.',
    }
    local msg = msgs[item] or ('Erreur : ' .. tostring(item))
    SendNUIMessage({ action = 'toast', text = msg, type = 'error' })
  end
  cb({ ok = ok })
end)

-- Entrer dans propriete depuis NUI agence (deja possedee)
RegisterNUICallback('enterProp', function(data, cb)
  TriggerServerEvent('sl:properties:enter', tonumber(data.propId))
  SetNuiFocus(false, false)
  nuiOpen = false
  cb({ ok = true })
end)

-- ===========================================================================
-- Nettoyage a l'arret de la resource
-- ===========================================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  removeAgents()
  for propId, _ in pairs(enterZones) do removeEnterZone(propId) end
  removeInteriorZones()
  if nuiOpen then
    SetNuiFocus(false, false)
    nuiOpen = false
  end
end)

-- ===========================================================================
-- Touche Esc pour fermer NUI
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(0)
    if nuiOpen then
      if IsControlJustReleased(0, 322) then  -- 322 = Escape
        SetNuiFocus(false, false)
        nuiOpen = false
        stashPropId = nil
        SendNUIMessage({ action = 'close' })
      end
    end
  end
end)
