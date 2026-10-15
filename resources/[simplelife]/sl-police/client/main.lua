print('[sl-police/client] main.lua loaded')

-- ===========================================================================
-- Etat local
-- ===========================================================================
local isCuffed     = false     -- ce client est-il menotte ?
local isDragging   = false     -- ce cop escorte-t-il quelqu un ?
local dragTarget   = nil       -- ped du menotte escorte
local isJailed     = false     -- ce client est-il emprisonne ?
local jailEndTime  = 0
local mdtOpen      = false
local searchOpen   = false

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function getClosestPlayer(maxDist)
  local ped     = PlayerPedId()
  local myCoord = GetEntityCoords(ped)
  local closest = nil
  local closestDist = maxDist or Police.CuffDistance

  for _, pid in ipairs(GetActivePlayers()) do
    if pid ~= PlayerId() then
      local tPed  = GetPlayerPed(pid)
      local tCoord = GetEntityCoords(tPed)
      local dist  = #(myCoord - tCoord)
      if dist < closestDist then
        closestDist = dist
        closest = pid
      end
    end
  end
  return closest, closestDist
end

local function playAnim(ped, dict, anim, duration)
  RequestAnimDict(dict)
  local t = 0
  while not HasAnimDictLoaded(dict) and t < 5000 do
    Wait(50); t = t + 50
  end
  if not HasAnimDictLoaded(dict) then return end
  TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, 49, 0, false, false, false)
end

-- ===========================================================================
-- MENOTTAGE cote client
-- ===========================================================================

-- Recevoir l ordre d appliquer les menottes (depuis le bus)
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  -- -------------------------------------------------------
  -- sl:police:applyCuff — ce joueur est menotte
  -- -------------------------------------------------------
  if event == 'sl:police:applyCuff' then
    isCuffed = true
    local ped = PlayerPedId()
    -- Anim menottes : mains dans le dos
    playAnim(ped, 'mp_arresting', 'idle', -1)
    -- Desactivation des controles en boucle
    CreateThread(function()
      while isCuffed do
        Wait(0)
        -- Bloquer : actions, combat, sprint, saut, vehicule entrer
        DisableAllControlActions(0)
        -- Autoriser la camera + deplacement lent
        EnableControlAction(0, 1, true)   -- LookLeftRight
        EnableControlAction(0, 2, true)   -- LookUpDown
        EnableControlAction(0, 245, true) -- MoveLeftRight
        EnableControlAction(0, 246, true) -- MoveUpDown
        EnableControlAction(0, 249, true) -- MoveUpOnly
        EnableControlAction(0, 250, true) -- MoveDownOnly
      end
      -- Restaurer les controles a la liberation
      EnableAllControlActions(0)
    end)

  -- -------------------------------------------------------
  -- sl:police:applyUncuff — ce joueur est libere des menottes
  -- -------------------------------------------------------
  elseif event == 'sl:police:applyUncuff' then
    isCuffed = false
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    EnableAllControlActions(0)

  -- -------------------------------------------------------
  -- sl:police:jailTeleport — TP prison + timer
  -- -------------------------------------------------------
  elseif event == 'sl:police:jailTeleport' then
    if not payload then return end
    isJailed = true
    jailEndTime = GetGameTimer() + ((payload.seconds or 60) * 1000)
    local coords = payload.coords
    local ped = PlayerPedId()

    -- Fade out / teleport / fade in
    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, 0, true, false)
    DoScreenFadeIn(500)

    lib.notify({ description = ('Vous etes emprisonne. Peine : %ds.'):format(payload.seconds), type = 'error', duration = 8000 })

    -- Compte a rebours affiche en notification toutes les minutes
    CreateThread(function()
      while isJailed do
        Wait(60000)
        if not isJailed then break end
        local remaining = math.ceil((jailEndTime - GetGameTimer()) / 1000)
        if remaining > 0 then
          lib.notify({ description = ('Prison — il reste %ds.'):format(remaining), type = 'error', duration = 5000 })
        end
      end
    end)

    -- Empecher de sortir de la zone prison (simple rayon)
    CreateThread(function()
      while isJailed do
        Wait(2000)
        if not isJailed then break end
        local myPos = GetEntityCoords(PlayerPedId())
        local prisonCenter = vec3(Police.Coords.Prison.x, Police.Coords.Prison.y, Police.Coords.Prison.z)
        if #(myPos - prisonCenter) > 120.0 then
          -- Ramener dans la prison
          SetEntityCoords(PlayerPedId(),
            Police.Coords.Prison.x, Police.Coords.Prison.y, Police.Coords.Prison.z,
            false, false, false, false)
          lib.notify({ description = 'Tentative de fuite enregistree.', type = 'error' })
        end
      end
    end)

  -- -------------------------------------------------------
  -- sl:police:jailRelease — liberation prison
  -- -------------------------------------------------------
  elseif event == 'sl:police:jailRelease' then
    isJailed = false
    local coords = payload and payload.coords or { x = Police.Coords.PrisonExit.x, y = Police.Coords.PrisonExit.y, z = Police.Coords.PrisonExit.z }
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    DoScreenFadeIn(500)

  -- -------------------------------------------------------
  -- sl:police:startDrag — ce cop commence l escorte
  -- -------------------------------------------------------
  elseif event == 'sl:police:startDrag' then
    if not payload or not payload.target then return end
    local targetSrc = payload.target
    isDragging = true

    CreateThread(function()
      while isDragging do
        Wait(0)
        local myPed     = PlayerPedId()
        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
        if not targetPed or not DoesEntityExist(targetPed) then
          isDragging = false
          break
        end
        local myPos = GetEntityCoords(myPed)
        -- Garder le menotte derriere le cop
        local forwardV = GetEntityForwardVector(myPed)
        local targetPos = vector3(
          myPos.x - forwardV.x * Police.DragDistance,
          myPos.y - forwardV.y * Police.DragDistance,
          myPos.z
        )
        -- Teleporter doucement le ped cote client (le server le fait aussi via dispatch)
        -- On envoie un event au serveur pour qu il repositionne le target
        -- (une fois toutes les 200ms pour eviter le flood)
        Wait(200)
      end
    end)

  -- -------------------------------------------------------
  -- sl:police:stopDrag — arreter l escorte
  -- -------------------------------------------------------
  elseif event == 'sl:police:stopDrag' then
    isDragging = false

  -- -------------------------------------------------------
  -- sl:police:requestPutin — le cop demande le netId de son vehicule
  -- -------------------------------------------------------
  elseif event == 'sl:police:requestPutin' then
    if not payload then return end
    local ped    = PlayerPedId()
    local veh    = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
      lib.notify({ description = 'Vous n etes pas dans un vehicule.', type = 'error' })
      return
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('sl:police:net:putin', payload.target, netId, payload.seat or -2)

  -- -------------------------------------------------------
  -- sl:police:forceInVehicle — ce joueur est force dans le vehicule
  -- -------------------------------------------------------
  elseif event == 'sl:police:forceInVehicle' then
    if not payload then return end
    local veh = NetToVeh(payload.vehicleNetId)
    if not veh or veh == 0 then return end
    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, veh, payload.seat or -2)

  -- -------------------------------------------------------
  -- sl:police:openSearch — ouvrir la NUI de fouille
  -- -------------------------------------------------------
  elseif event == 'sl:police:openSearch' then
    if not payload then return end
    searchOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
      action    = 'openSearch',
      targetSrc = payload.targetSrc,
      items     = payload.items or {},
    })

  -- -------------------------------------------------------
  -- sl:police:searchSync — MAJ de la NUI fouille (apres saisie)
  -- -------------------------------------------------------
  elseif event == 'sl:police:searchSync' then
    if not payload then return end
    SendNUIMessage({
      action    = 'syncSearch',
      targetSrc = payload.targetSrc,
      items     = payload.items or {},
    })

  -- -------------------------------------------------------
  -- sl:police:openMDT — ouvrir le MDT NUI
  -- -------------------------------------------------------
  elseif event == 'sl:police:openMDT' then
    if mdtOpen then return end
    mdtOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMDT' })

  -- -------------------------------------------------------
  -- sl:police:robberyAlert — blip GPS temporaire pour braquage
  -- -------------------------------------------------------
  elseif event == 'sl:police:robberyAlert' then
    if not payload or not payload.coords then return end
    local coords = payload.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('BRAQUAGE : ' .. (payload.shop or ''))
    EndTextCommandSetBlipName(blip)
    -- Supprimer apres 5 min
    CreateThread(function()
      Wait(300000)
      if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
  end
end)

-- ===========================================================================
-- NUI Callbacks
-- ===========================================================================

-- Fermeture MDT
RegisterNUICallback('mdt:close', function(_, cb)
  mdtOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'closeMDT' })
  cb({ ok = true })
end)

-- Fermeture fenetre fouille
RegisterNUICallback('search:close', function(_, cb)
  searchOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'closeSearch' })
  cb({ ok = true })
end)

-- Recherche citoyen MDT
RegisterNUICallback('mdt:searchCitizen', function(data, cb)
  local results = lib.callback.await('sl-police:mdt:searchCitizen', false, data.query or '')
  cb(results or {})
end)

-- Liste BOLOs
RegisterNUICallback('mdt:getBolos', function(_, cb)
  local results = lib.callback.await('sl-police:mdt:getBolos', false)
  cb(results or {})
end)

-- Ajouter BOLO
RegisterNUICallback('mdt:addBolo', function(data, cb)
  local ok = lib.callback.await('sl-police:mdt:addBolo', false, data.citizenId, data.reason)
  cb({ ok = ok })
end)

-- Supprimer BOLO
RegisterNUICallback('mdt:deleteBolo', function(data, cb)
  local ok = lib.callback.await('sl-police:mdt:deleteBolo', false, data.id)
  cb({ ok = ok })
end)

-- Membres en service
RegisterNUICallback('mdt:getOnDuty', function(_, cb)
  local list = lib.callback.await('sl-police:mdt:getOnDuty', false)
  cb(list or {})
end)

-- Ajouter une charge depuis la NUI MDT
RegisterNUICallback('mdt:addCharge', function(data, cb)
  if not data or not data.citizenId or not data.charge then
    cb({ ok = false }); return
  end
  local fine = tonumber(data.fine) or 0
  TriggerServerEvent('sl:police:net:addCharge', data.citizenId, data.charge, fine)
  cb({ ok = true })
end)

-- Saisir un item (depuis la NUI fouille)
RegisterNUICallback('search:seize', function(data, cb)
  TriggerServerEvent('sl:police:net:seizeItem', data.targetSrc, data.item, data.count or 1)
  cb({ ok = true })
end)

-- ===========================================================================
-- Commande menottage. Keymap centralisé dans sl-keybinds (touche G,
-- catégorie "SimpleLife"). Gere uniquement si le cop est en service.
-- ===========================================================================
RegisterCommand('sl_cuff_nearest', function()
  local closestPid, dist = getClosestPlayer(Police.CuffDistance)
  if not closestPid then
    lib.notify({ description = 'Personne a portee de menottage.', type = 'error' })
    return
  end
  local targetSrc = GetPlayerServerId(closestPid)
  -- Anim menottes sur le cop
  local ped = PlayerPedId()
  playAnim(ped, 'mp_arresting', 'a_uncuff', Police.CuffAnimMs)
  -- Envoyer au serveur
  TriggerServerEvent('sl:police:net:cuff', targetSrc)
end, false)

-- ===========================================================================
-- Escape ferme les NUI police
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(0)
    if (mdtOpen or searchOpen) and IsControlJustReleased(0, 322) then -- Escape = 322
      if mdtOpen then
        mdtOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeMDT' })
      end
      if searchOpen then
        searchOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeSearch' })
      end
    end
  end
end)

-- ===========================================================================
-- Blip MRPD permanent
-- ===========================================================================
CreateThread(function()
  local blip = AddBlipForCoord(Police.Coords.MRPD.x, Police.Coords.MRPD.y, Police.Coords.MRPD.z)
  SetBlipSprite(blip, 60)
  SetBlipColour(blip, 3)
  SetBlipScale(blip, 0.85)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentSubstringPlayerName('Commissariat MRPD')
  EndTextCommandSetBlipName(blip)
end)
