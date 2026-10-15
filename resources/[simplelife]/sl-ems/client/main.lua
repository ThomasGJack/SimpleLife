print('[sl-ems/client] main.lua loaded')

-- ===========================================================================
-- State local
-- ===========================================================================
local isCarrying    = false   -- true si on porte quelqu'un
local carriedEntity = nil     -- entite portee
local carryAttach   = nil     -- handle attach

local nuiOpen = false
local nuiReady = false

local interactIds = {}        -- ids retournes par sl-interact (pour cleanup)

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

-- Charge un dictionnaire d'anim
local function loadAnimDict(dict)
  if HasAnimDictLoaded(dict) then return true end
  RequestAnimDict(dict)
  local t = GetGameTimer()
  while not HasAnimDictLoaded(dict) do
    if GetGameTimer() - t > 5000 then return false end
    Wait(50)
  end
  return true
end

-- Charge un modele
local function loadModel(hash)
  if not IsModelValid(hash) then return false end
  if HasModelLoaded(hash) then return true end
  RequestModel(hash)
  local t = GetGameTimer()
  while not HasModelLoaded(hash) do
    if GetGameTimer() - t > 5000 then return false end
    Wait(50)
  end
  return true
end

-- Trouve le joueur le plus proche (retourne playerServerId, ped, distance)
local function getNearestPlayer(maxDist)
  maxDist = maxDist or EMS.InteractDistance
  local myPed = PlayerPedId()
  local myCoords = GetEntityCoords(myPed)
  local closest, closestPed, closestDist = -1, nil, maxDist + 1.0

  for _, pid in ipairs(GetActivePlayers()) do
    if pid ~= PlayerId() then
      local ped = GetPlayerPed(pid)
      if DoesEntityExist(ped) then
        local dist = #(myCoords - GetEntityCoords(ped))
        if dist < closestDist then
          closestDist = dist
          closest    = GetPlayerServerId(pid)
          closestPed = ped
        end
      end
    end
  end

  if closest == -1 then return nil, nil, nil end
  return closest, closestPed, closestDist
end

-- ===========================================================================
-- Reporter la sante au serveur periodiquement
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(5000)
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
      TriggerServerEvent('sl:ems:reportHealth', GetEntityHealth(ped))
    end
  end
end)

-- ===========================================================================
-- Bus dispatch client : appliquer la sante
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:ems:applyHealth' then
    if not payload or not payload.amount then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local current = GetEntityHealth(ped)
    local newHp   = clamp(current + math.floor(payload.amount), EMS.MinHealth, EMS.MaxHealth)
    SetEntityHealth(ped, newHp)
  end
end)

-- ===========================================================================
-- REVIVE — barre de progression + anim CPR
-- /revivep : cherche le joueur downed le plus proche et lance la sequence
-- ===========================================================================
local function doReviveSequence(targetSrc, targetPed)
  local myPed = PlayerPedId()

  -- Tourne vers la cible
  TaskTurnPedToFaceEntity(myPed, targetPed, 1000)
  Wait(800)

  -- Charge l'anim dict
  local animCfg = EMS.Anims.revive
  local dictLoaded = loadAnimDict(animCfg.dict)
  if not dictLoaded then
    lib.notify({ description = 'Erreur anim CPR.', type = 'error' })
    return
  end

  -- Barre de progression ox_lib
  local success = lib.progressBar({
    duration    = animCfg.duration,
    label       = 'Reanimation en cours...',
    useWhileDead = false,
    canCancel   = true,
    disable     = { car = true, move = true, combat = true },
    anim        = { dict = animCfg.dict, clip = animCfg.clip, flag = animCfg.flag },
  })

  if not success then
    lib.notify({ description = 'Reanimation annulee.', type = 'error' })
    return
  end

  -- Envoie la demande au serveur
  TriggerServerEvent('sl:ems:requestRevive', targetSrc)
end

-- ===========================================================================
-- HEAL — barre de progression + anim soins
-- ===========================================================================
local function doHealSequence(targetSrc, targetPed, amount)
  local myPed = PlayerPedId()

  TaskTurnPedToFaceEntity(myPed, targetPed, 800)
  Wait(600)

  local animCfg = EMS.Anims.heal
  local dictLoaded = loadAnimDict(animCfg.dict)
  if not dictLoaded then
    animCfg = EMS.Anims.revive
    loadAnimDict(animCfg.dict)
  end

  local success = lib.progressBar({
    duration    = animCfg.duration,
    label       = 'Soin en cours...',
    useWhileDead = false,
    canCancel   = true,
    disable     = { car = true, move = true, combat = true },
    anim        = { dict = animCfg.dict, clip = animCfg.clip, flag = animCfg.flag },
  })

  if not success then
    lib.notify({ description = 'Soin annule.', type = 'error' })
    return
  end

  TriggerServerEvent('sl:ems:requestHeal', targetSrc, amount)
end

-- ===========================================================================
-- Interaction sur les peds joueurs (sl-interact)
-- Ajoute un bouton E sur les joueurs downed proches
-- ===========================================================================
local function setupPlayerInteractions()
  -- Tick qui surveille les joueurs downed dans le rayon
  CreateThread(function()
    local registeredPeds = {}

    while true do
      Wait(1000)
      local myCoords = GetEntityCoords(PlayerPedId())

      -- Retire les anciens
      for ped, id in pairs(registeredPeds) do
        if not DoesEntityExist(ped) then
          pcall(function() exports['sl-interact']:RemoveEntity(ped) end)
          registeredPeds[ped] = nil
        end
      end

      -- Cherche les joueurs downed proches
      for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
          local ped = GetPlayerPed(pid)
          if DoesEntityExist(ped) then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist < 8.0 then
              local isDowned = IsEntityDead(ped) or IsPedRagdoll(ped)
              if isDowned and not registeredPeds[ped] then
                local targetSrc = GetPlayerServerId(pid)
                local okAdd, id = pcall(function()
                  return exports['sl-interact']:AddEntity(ped, {
                    label    = 'Ranimer [E]',
                    key      = 'E',
                    distance = EMS.InteractDistance,
                    onSelect = function()
                      CreateThread(function()
                        doReviveSequence(targetSrc, ped)
                      end)
                    end,
                  })
                end)
                if okAdd and id then
                  registeredPeds[ped] = id
                end
              elseif not isDowned and registeredPeds[ped] then
                pcall(function() exports['sl-interact']:RemoveEntity(ped) end)
                registeredPeds[ped] = nil
              end
            end
          end
        end
      end
    end
  end)
end

-- ===========================================================================
-- Commande /revivep — revive interactif (cote client)
-- ===========================================================================
RegisterCommand('revivep', function(args)
  local targetSrc, targetPed, dist = getNearestPlayer(EMS.InteractDistance + 1.0)
  if not targetSrc then
    lib.notify({ description = 'Aucun joueur proche.', type = 'error' })
    return
  end
  -- Verifie que c'est un ped downed
  if not targetPed then
    lib.notify({ description = 'Cible invalide.', type = 'error' })
    return
  end
  CreateThread(function()
    doReviveSequence(targetSrc, targetPed)
  end)
end, false)

-- ===========================================================================
-- Commande /carry — porter/deposer un joueur downed (brancard)
-- ===========================================================================
RegisterCommand('carry', function(args)
  if isCarrying then
    -- Depose la personne
    if carriedEntity and DoesEntityExist(carriedEntity) then
      DetachEntity(carriedEntity, true, true)
      SetEntityCollision(carriedEntity, true, true)
      -- Place le ped devant nous
      local myPed = PlayerPedId()
      local fwd   = GetEntityForwardVector(myPed)
      local pos   = GetEntityCoords(myPed)
      SetEntityCoords(carriedEntity, pos.x + fwd.x * 1.5, pos.y + fwd.y * 1.5, pos.z, false, false, false, false)
      NetworkRequestControlOfEntity(carriedEntity)
    end
    isCarrying    = false
    carriedEntity = nil
    lib.notify({ description = 'Vous avez depose le patient.', type = 'inform' })
    return
  end

  -- Cherche un ped downed proche
  local myPed    = PlayerPedId()
  local myCoords = GetEntityCoords(myPed)
  local found    = nil
  local foundDist = EMS.InteractDistance + 1.0

  for _, pid in ipairs(GetActivePlayers()) do
    if pid ~= PlayerId() then
      local ped = GetPlayerPed(pid)
      if DoesEntityExist(ped) then
        local d = #(myCoords - GetEntityCoords(ped))
        if d < foundDist then
          local isDowned = IsEntityDead(ped) or IsPedRagdoll(ped)
          if isDowned then
            found     = ped
            foundDist = d
          end
        end
      end
    end
  end

  if not found then
    lib.notify({ description = 'Aucun patient a porter a proximite.', type = 'error' })
    return
  end

  -- Attache le ped sur notre dos
  NetworkRequestControlOfEntity(found)
  Wait(200)

  SetEntityCollision(found, false, false)
  AttachEntityToEntity(found, myPed,
    GetPedBoneIndex(myPed, 0xE394),   -- Spine3
    0.0, -0.6, 0.35,                  -- offset
    0.0, 0.0, 0.0,                    -- rotation
    true, true, false, false, 2, true)

  isCarrying    = true
  carriedEntity = found

  lib.notify({ description = 'Patient en transport. /carry pour deposer.', type = 'inform' })
end, false)

-- ===========================================================================
-- NUI MDT medical
-- ===========================================================================
local function openMDT()
  if nuiOpen then return end
  nuiOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open' })
end

local function closeMDT()
  if not nuiOpen then return end
  nuiOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

-- Keybind F6 pour ouvrir le MDT (enregistre comme commande)
RegisterCommand('emsopen', function()
  if nuiOpen then
    closeMDT()
  else
    openMDT()
  end
end, false)

-- Ferme avec Echap
RegisterNUICallback('close', function(_, cb)
  closeMDT()
  cb({ ok = true })
end)

RegisterNUICallback('ready', function(_, cb)
  nuiReady = true
  cb({ ok = true })
end)

-- NUI demande la liste des patients
RegisterNUICallback('getPatients', function(_, cb)
  local result = lib.callback.await('sl-ems:getPatients', false)
  cb(result or {})
end)

-- NUI demande les donnees perso
RegisterNUICallback('getSelfData', function(_, cb)
  local result = lib.callback.await('sl-ems:getSelfData', false)
  cb(result or {})
end)

-- NUI demande les blessures d'une cible
RegisterNUICallback('getInjuries', function(data, cb)
  local targetSrc = tonumber(data and data.targetSrc)
  if not targetSrc then cb({}); return end
  local result = lib.callback.await('sl-ems:getInjuries', false, targetSrc)
  cb(result or {})
end)

-- NUI demande un revive
RegisterNUICallback('revivePatient', function(data, cb)
  local targetSrc = tonumber(data and data.targetSrc)
  if not targetSrc then cb({ ok = false }); return end
  -- Trouve le ped local
  local targetPed = nil
  for _, pid in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(pid) == targetSrc then
      targetPed = GetPlayerPed(pid)
      break
    end
  end
  closeMDT()
  if targetPed and DoesEntityExist(targetPed) then
    CreateThread(function()
      doReviveSequence(targetSrc, targetPed)
    end)
  else
    TriggerServerEvent('sl:ems:requestRevive', targetSrc)
  end
  cb({ ok = true })
end)

-- NUI demande un soin (heal) sur une cible
RegisterNUICallback('healPatient', function(data, cb)
  local targetSrc = tonumber(data and data.targetSrc)
  if not targetSrc then cb({ ok = false }); return end
  local targetPed = nil
  for _, pid in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(pid) == targetSrc then
      targetPed = GetPlayerPed(pid)
      break
    end
  end
  closeMDT()
  if targetPed and DoesEntityExist(targetPed) then
    CreateThread(function()
      doHealSequence(targetSrc, targetPed, EMS.DefaultHealAmount)
    end)
  else
    TriggerServerEvent('sl:ems:requestHeal', targetSrc, EMS.DefaultHealAmount)
  end
  cb({ ok = true })
end)

-- NUI demande une facture
RegisterNUICallback('billPatient', function(data, cb)
  local targetSrc = tonumber(data and data.targetSrc)
  local amount    = tonumber(data and data.amount)
  if not targetSrc or not amount then cb({ ok = false }); return end
  TriggerServerEvent('sl:ems:requestBill', targetSrc, amount)
  closeMDT()
  cb({ ok = true })
end)

-- ===========================================================================
-- Init au characterSelected
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  isCarrying    = false
  carriedEntity = nil

  -- Lance le thread d'interactions sur les joueurs downed
  CreateThread(function()
    Wait(1000)
    setupPlayerInteractions()
  end)
end)

-- ===========================================================================
-- Cleanup si on est en train de porter et que la resource s'arrete
-- ===========================================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  if isCarrying and carriedEntity and DoesEntityExist(carriedEntity) then
    DetachEntity(carriedEntity, true, true)
    SetEntityCollision(carriedEntity, true, true)
  end
end)
