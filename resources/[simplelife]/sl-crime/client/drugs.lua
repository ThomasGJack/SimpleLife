print('[sl-crime/client] drugs.lua loaded')

-- ===========================================================================
-- DROGUE : culture (planting), packaging, vente (deal)
-- ===========================================================================

local plantProps   = {}   -- plantId -> { prop, coords, grownAt }
local dealInProgress   = false
local plantInProgress  = false
local packInProgress   = false

-- Prop weed (model + offset Z pour poser au sol)
local PLANT_MODEL   = `prop_weed_01`
local PLANT_Z_OFFSET = 0.0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function notify(desc, ntype)
  lib.notify({ description = desc, type = ntype or 'inform', duration = 4500 })
end

local function hasItem(itemName, count)
  local ok, has = pcall(function()
    return exports['sl-inventory']:HasItem(itemName, count or 1)
  end)
  return ok and has == true
end

local function fmtTime(sec)
  if sec <= 0 then return '0s' end
  local m = math.floor(sec / 60)
  local s = sec % 60
  if m > 0 then return ('%dm %ds'):format(m, s) end
  return ('%ds'):format(s)
end

-- ---------------------------------------------------------------------------
-- Spawne un prop plant (visuel client-only)
-- ---------------------------------------------------------------------------
local function spawnPlantProp(pid, coords, grown)
  -- Charge le modele
  RequestModel(PLANT_MODEL)
  local t = 0
  while not HasModelLoaded(PLANT_MODEL) do
    Wait(50)
    t = t + 50
    if t > 5000 then
      print('[sl-crime] timeout chargement modele plant')
      return nil
    end
  end

  local prop = CreateObjectNoOffset(PLANT_MODEL,
    coords.x, coords.y, coords.z,
    false, false, false)

  if not DoesEntityExist(prop) then
    SetModelAsNoLongerNeeded(PLANT_MODEL)
    return nil
  end

  FreezeEntityPosition(prop, true)
  SetEntityInvincible(prop, true)
  SetBlockingOfNonTemporaryEvents(prop, true)
  -- Les plants non pousses sont plus petits
  if not grown then
    SetEntityVisible(prop, true, false)
    -- legere opacite pour indiquer croissance
  end
  SetModelAsNoLongerNeeded(PLANT_MODEL)
  return prop
end

-- Detruit un prop plant
local function destroyPlantProp(pid)
  if plantProps[pid] then
    local p = plantProps[pid]
    if p.prop and DoesEntityExist(p.prop) then
      DeleteObject(p.prop)
    end
    plantProps[pid] = nil
  end
end

-- ---------------------------------------------------------------------------
-- CULTURE : planter
-- ---------------------------------------------------------------------------
local function tryPlantSeed()
  if plantInProgress then return end
  if not hasItem('weed_seed', 1) then
    notify('Vous n\'avez pas de graine de weed.', 'error')
    return
  end

  -- Verifie qu'on est pas dans un batiment / en voiture
  local ped = PlayerPedId()
  if IsPedInAnyVehicle(ped, false) then
    notify('Impossible de planter en vehicule.', 'error')
    return
  end

  plantInProgress = true

  -- Animation de plantation
  local success = lib.progressBar({
    duration = 6000,
    label    = 'Planter la graine...',
    useWhileDead = false,
    canCancel    = true,
    disable = { car = true, combat = true, move = true },
    anim    = {
      dict  = 'amb@world_human_gardener_plant@male@base',
      clip  = 'base',
      flag  = 49,
    },
  })

  if not success then
    plantInProgress = false
    notify('Plantation annulee.', 'error')
    return
  end

  -- Coordonnees du sol sous le ped
  local pos   = GetEntityCoords(ped)
  local gnd, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z, false)
  local plantPos = vector3(pos.x, pos.y, gnd and gz or pos.z)

  -- Demande serveur
  local res = lib.callback.await('sl-crime:plantSeed', false, plantPos)
  plantInProgress = false

  if not res or not res.ok then
    if res and res.reason == 'no_seed' then
      notify('Plus de graine.', 'error')
    elseif res and res.reason == 'max_plants' then
      notify('Vous avez deja trop de plants actifs.', 'error')
    else
      notify('Impossible de planter ici.', 'error')
    end
    return
  end

  -- Spawn visuel
  local pid = res.plantId
  local prop = spawnPlantProp(pid, plantPos, false)
  plantProps[pid] = {
    prop    = prop,
    coords  = plantPos,
    grownAt = res.grownAt,
    mine    = true,
  }

  notify(('Graine plantee. Pret a recolter dans %s.'):format(fmtTime((res.grownAt or 0) - math.floor(os.time()))), 'success')
end

-- ---------------------------------------------------------------------------
-- CULTURE : recolter un plant
-- ---------------------------------------------------------------------------
local function tryHarvestPlant(pid)
  local data = plantProps[pid]
  if not data then return end

  local nowTs = math.floor(os.time())
  if data.grownAt and nowTs < data.grownAt then
    local rem = data.grownAt - nowTs
    notify(('Le plant n\'est pas encore pret. Encore %s.'):format(fmtTime(rem)), 'inform')
    return
  end

  local success = lib.progressBar({
    duration = 5000,
    label    = 'Recolter le plant...',
    useWhileDead = false,
    canCancel    = true,
    disable = { car = true, combat = true },
    anim    = {
      dict  = 'amb@world_human_gardener_plant@male@base',
      clip  = 'base',
      flag  = 49,
    },
  })

  if not success then
    notify('Recolte annulee.', 'error')
    return
  end

  local res = lib.callback.await('sl-crime:harvestPlant', false, pid)
  if not res or not res.ok then
    if res and res.reason == 'not_ready' then
      notify(('Pas encore pret. Encore %s.'):format(fmtTime(res.remaining or 0)), 'inform')
    elseif res and res.reason == 'already_harvested' then
      notify('Ce plant a deja ete recolte.', 'error')
      destroyPlantProp(pid)
    else
      notify('Echec de la recolte.', 'error')
    end
    return
  end

  destroyPlantProp(pid)
  notify(('Recolte reussie : %d weed_bud obtenus.'):format(res.amount or 0), 'success')
end

-- ---------------------------------------------------------------------------
-- CULTURE : thread qui poll la presence du joueur pres de ses plants
--           pour afficher l'interaction sl-interact dynamiquement
-- ---------------------------------------------------------------------------
local harvestInteractIds = {}  -- pid -> interactId

CreateThread(function()
  while true do
    Wait(2000)
    if not isCharacterLoaded then goto continue end

    local ped = PlayerPedId()
    local myPos = GetEntityCoords(ped)

    -- Ajoute interactions pour les plants proches
    for pid, data in pairs(plantProps) do
      if not harvestInteractIds[pid] then
        local nowTs = math.floor(os.time())
        local grown = (data.grownAt and nowTs >= data.grownAt)
        local label = grown and 'Recolter le plant [E]' or ('Plant (pousse dans %s)'):format(
          fmtTime((data.grownAt or 0) - nowTs))
        -- On ajoute une zone autour du plant
        local capturePid = pid
        local zid = exports['sl-interact']:AddZone({
          coords   = data.coords,
          radius   = 1.5,
          label    = label,
          key      = 'E',
          onSelect = function()
            tryHarvestPlant(capturePid)
          end,
        })
        harvestInteractIds[pid] = zid
      end
    end

    -- Retire les interactions de plants qui n'existent plus
    for pid, zid in pairs(harvestInteractIds) do
      if not plantProps[pid] then
        pcall(function() exports['sl-interact']:Remove(zid) end)
        harvestInteractIds[pid] = nil
      end
    end

    ::continue::
  end
end)

-- ---------------------------------------------------------------------------
-- PACKAGING
-- ---------------------------------------------------------------------------
local function tryPackaging(cfg)
  if packInProgress then return end

  if not hasItem(cfg.inputItem, cfg.inputCount) then
    notify(('Il vous faut %d x %s pour emballer.'):format(cfg.inputCount, cfg.inputItem), 'error')
    return
  end

  packInProgress = true

  local success = lib.progressBar({
    duration = cfg.progressMs,
    label    = cfg.label .. '...',
    useWhileDead = false,
    canCancel    = true,
    disable = { car = true, combat = true },
    anim    = {
      dict  = 'anim@heists@ornate_bank@grab_cash',
      clip  = 'grab_cash',
      flag  = 49,
    },
  })

  if not success then
    packInProgress = false
    notify('Packaging annule.', 'error')
    return
  end

  local res = lib.callback.await('sl-crime:doPackaging', false, cfg.id)
  packInProgress = false

  if not res or not res.ok then
    if res and res.reason == 'not_enough' then
      notify(('Pas assez de %s (besoin %d).'):format(res.item or cfg.inputItem, res.need or cfg.inputCount), 'error')
    else
      notify('Echec du packaging.', 'error')
    end
    return
  end

  notify(('%d x %s emballe avec succes.'):format(res.count or 1, res.output or cfg.outputItem), 'success')
end

-- ---------------------------------------------------------------------------
-- DEAL (vente a un PNJ dans une zone)
-- ---------------------------------------------------------------------------
local dealNpcHandles = {}  -- zoneId -> ped handle

-- Spawne un PNJ vendeur fixe dans la zone (visuel)
local function spawnDealNpc(zone)
  local npcModel = `a_m_y_skater_01`
  RequestModel(npcModel)
  local t = 0
  while not HasModelLoaded(npcModel) do
    Wait(50)
    t = t + 50
    if t > 4000 then SetModelAsNoLongerNeeded(npcModel); return end
  end
  local ped = CreatePed(4, npcModel,
    zone.coords.x, zone.coords.y, zone.coords.z - 1.0,
    0.0, false, true)
  if not DoesEntityExist(ped) then
    SetModelAsNoLongerNeeded(npcModel)
    return
  end
  SetEntityInvincible(ped, true)
  FreezeEntityPosition(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
  SetModelAsNoLongerNeeded(npcModel)
  dealNpcHandles[zone.id] = ped
end

-- Choisit automatiquement la premiere drogue que le joueur possede
local function pickDrug()
  for _, drugName in ipairs(Crime.SellableDrugs) do
    if hasItem(drugName, 1) then return drugName end
  end
  return nil
end

local function tryDeal(zone)
  if dealInProgress then return end

  local drugItem = pickDrug()
  if not drugItem then
    notify('Vous n\'avez aucune drogue a vendre.', 'error')
    return
  end

  dealInProgress = true

  -- Petite animation d'approche (2 sec)
  local success = lib.progressBar({
    duration = 2000,
    label    = 'Proposer la marchandise...',
    useWhileDead = false,
    canCancel    = true,
    disable = { car = true, combat = true },
    anim    = {
      dict  = 'mp_common',
      clip  = 'givetake1_a',
      flag  = 49,
    },
  })

  if not success then
    dealInProgress = false
    notify('Deal annule.', 'error')
    return
  end

  local res = lib.callback.await('sl-crime:deal', false, zone.id, drugItem)
  dealInProgress = false

  if not res then
    notify('Erreur de communication.', 'error')
    return
  end

  if not res.ok then
    if res.reason == 'cooldown' then
      notify(('Attendez encore %s avant de dealer ici.'):format(fmtTime(res.remaining or 0)), 'error')
    elseif res.reason == 'no_drug' then
      notify('Plus de marchandise.', 'error')
    else
      notify('Deal impossible.', 'error')
    end
    return
  end

  if res.bought then
    local price = res.price or 0
    notify(('Le client a achete. +$%d cash.'):format(price), 'success')
    if res.alertPolice then
      notify('Le client a appele la police !', 'error')
      -- Flash rouge
      StartScreenEffect('DeathFailNeutralIn', 300, false)
      Wait(300)
      StopScreenEffect('DeathFailNeutralIn')
    end
  else
    notify('Le client n\'est pas interesse.', 'inform')
    if res.alertPolice then
      notify('Il a appele la police !', 'error')
      StartScreenEffect('DeathFailNeutralIn', 300, false)
      Wait(300)
      StopScreenEffect('DeathFailNeutralIn')
    end
  end
end

-- ---------------------------------------------------------------------------
-- Enregistrement des zones et PNJ au characterSelected
-- ---------------------------------------------------------------------------
AddEventHandler('sl:core:characterSelected', function()
  -- Zones de packaging
  for _, cfg in ipairs(Crime.Packaging) do
    local zoneCfg = cfg
    local id = exports['sl-interact']:AddZone({
      coords   = cfg.coords,
      radius   = cfg.radius or 3.0,
      label    = cfg.label,
      key      = 'E',
      onSelect = function()
        tryPackaging(zoneCfg)
      end,
    })
    interactIds[#interactIds + 1] = id
  end

  -- Zones de deal
  for _, zone in ipairs(Crime.DealZones) do
    local zoneCfg = zone
    -- Spawn PNJ
    CreateThread(function()
      spawnDealNpc(zoneCfg)
    end)
    -- Zone interact
    local id = exports['sl-interact']:AddZone({
      coords   = zone.coords,
      radius   = zone.radius or 5.0,
      label    = 'Dealer [E]',
      key      = 'E',
      onSelect = function()
        tryDeal(zoneCfg)
      end,
    })
    interactIds[#interactIds + 1] = id
  end

  -- Recupere les plants existants du serveur (reconnexion)
  CreateThread(function()
    Wait(1500)
    local plants = lib.callback.await('sl-crime:getPlants', false)
    if not plants then return end
    for _, p in ipairs(plants) do
      local pid = p.id
      local coords = vector3(p.coords.x, p.coords.y, p.coords.z)
      local nowTs = math.floor(os.time())
      local grown = nowTs >= (p.grownAt or 0)
      local prop = spawnPlantProp(pid, coords, grown)
      plantProps[pid] = {
        prop    = prop,
        coords  = coords,
        grownAt = p.grownAt,
        mine    = p.mine,
      }
    end
    if #plants > 0 then
      notify(('%d plant(s) actif(s) retrouve(s).'):format(#plants), 'inform')
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- Commande client : /planter (n'importe ou, pas besoin de zone)
-- ---------------------------------------------------------------------------
RegisterCommand('planter', function()
  if not isCharacterLoaded then return end
  tryPlantSeed()
end, false)

-- Cleanup PNJ dealers au resourceStop
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for _, ped in pairs(dealNpcHandles) do
    if DoesEntityExist(ped) then DeletePed(ped) end
  end
  dealNpcHandles = {}
  for pid, _ in pairs(plantProps) do
    destroyPlantProp(pid)
  end
  for pid, zid in pairs(harvestInteractIds) do
    pcall(function() exports['sl-interact']:Remove(zid) end)
  end
  harvestInteractIds = {}
end)
