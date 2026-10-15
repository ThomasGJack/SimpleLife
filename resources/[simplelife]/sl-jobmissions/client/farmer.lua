print('[sl-jobmissions/client] farmer.lua loaded')

-- ===========================================================================
-- FARMER — logique complete
-- Cycle : zones de champ (AddZone 'Recolter [E]') → anim + recolte ble →
--         vendre au moulin PNJ (AddEntity 'Vendre ble [E]') →
--         RemoveItem ble + AddMoney + XP.
-- Optionnel : planter graines_ble dans les champs.
-- ===========================================================================

local cfg = nil

-- Etat
local farmerState = {
  fieldZones   = {},   -- liste des ids sl-interact zones
  blips        = {},   -- liste des blips (champs + moulin) a nettoyer
  millInteract = nil,  -- id interact moulin
  millPed      = nil,  -- entite PNJ moulin
  harvesting   = false,
  planting     = false,
}

-- ---------------------------------------------------------------------------
-- Nettoyage
-- ---------------------------------------------------------------------------
local function cleanFarmer()
  for _, zid in ipairs(farmerState.fieldZones) do
    pcall(function() exports['sl-interact']:Remove(zid) end)
  end
  farmerState.fieldZones = {}

  -- Retirer les blips (champs + moulin) sinon ils restent sur la carte
  for _, blip in ipairs(farmerState.blips) do
    RemoveBlipSafe(blip)
  end
  farmerState.blips = {}

  if farmerState.millInteract then
    pcall(function() exports['sl-interact']:Remove(farmerState.millInteract) end)
    farmerState.millInteract = nil
  end

  DeletePed(farmerState.millPed)
  farmerState.millPed   = nil
  farmerState.harvesting = false
  farmerState.planting   = false
end

-- ---------------------------------------------------------------------------
-- Recolte d un champ (callback depuis onSelect)
-- ---------------------------------------------------------------------------
local function doHarvest()
  cfg = JobMissions.Farmer
  if farmerState.harvesting then return end
  farmerState.harvesting = true

  -- Charger anim
  RequestAnimDict('amb@world_human_gardener_plant@male@base')
  local t = 0
  while not HasAnimDictLoaded('amb@world_human_gardener_plant@male@base') do
    Wait(100)
    t = t + 100
    if t > 5000 then break end
  end

  local ok = lib.progressBar({
    duration        = cfg.HarvestTime,
    label           = 'Recolte en cours...',
    useWhileDead    = false,
    canCancel       = true,
    disable         = { move = true, car = false, combat = true },
    anim            = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
  })

  farmerState.harvesting = false

  if not ok then
    lib.notify({ description = 'Recolte annulee.', type = 'inform' })
    return
  end

  -- Appel serveur : donne le ble
  lib.callback.await('sl-jobmissions:farmer:harvest', false)
end

-- ---------------------------------------------------------------------------
-- Plantation (optionnel, consomme graines_ble)
-- ---------------------------------------------------------------------------
local function doPlant()
  cfg = JobMissions.Farmer
  if farmerState.planting then return end

  -- Verifier les graines
  local hasSeeds = false
  pcall(function()
    hasSeeds = exports['sl-inventory']:HasItem(cfg.SeedItem, 1)
  end)
  if not hasSeeds then
    lib.notify({ description = 'Vous n avez pas de graines de ble.', type = 'error' })
    return
  end

  farmerState.planting = true

  RequestAnimDict('amb@world_human_gardener_plant@male@enter')
  local t = 0
  while not HasAnimDictLoaded('amb@world_human_gardener_plant@male@enter') do
    Wait(100)
    t = t + 100
    if t > 5000 then break end
  end

  local ok = lib.progressBar({
    duration        = cfg.PlantTime,
    label           = 'Plantation...',
    useWhileDead    = false,
    canCancel       = true,
    disable         = { move = true, car = false, combat = true },
    anim            = { dict = 'amb@world_human_gardener_plant@male@enter', clip = 'enter' },
  })

  farmerState.planting = false

  if not ok then
    lib.notify({ description = 'Plantation annulee.', type = 'inform' })
    return
  end

  -- Retirer les graines (autoritatif serveur : pas de RemoveItem client)
  local removed = lib.callback.await('sl-jobmissions:farmer:plant', false)

  if removed then
    lib.notify({ description = 'Graines plantees ! Revenez recolter plus tard.', type = 'success' })
  end
end

-- ---------------------------------------------------------------------------
-- Vente au moulin (appel depuis onSelect du PNJ)
-- ---------------------------------------------------------------------------
local function doSell()
  cfg = JobMissions.Farmer

  -- Compter le ble disponible
  local bleCount = 0
  pcall(function()
    bleCount = exports['sl-inventory']:GetItem(cfg.HarvestItem) or 0
  end)

  if bleCount <= 0 then
    lib.notify({ description = 'Vous n avez pas de ble a vendre.', type = 'error' })
    return
  end

  -- Confirmer la vente
  local confirmed = lib.alertDialog({
    header  = 'Vente de ble',
    content = ('Vendre %d kg de ble pour $%d ?'):format(bleCount, bleCount * cfg.PricePerKg),
    centered = true,
    cancel  = true,
  })

  if confirmed ~= 'confirm' then return end

  lib.callback.await('sl-jobmissions:farmer:sell', false, bleCount)
end

-- ---------------------------------------------------------------------------
-- Enregistrement des zones de champ
-- ---------------------------------------------------------------------------
local function registerFieldZones()
  cfg = JobMissions.Farmer

  for i, field in ipairs(cfg.Fields) do
    local coords = { x = field.coords.x, y = field.coords.y, z = field.coords.z }

    -- Zone recolte
    local zid = exports['sl-interact']:AddZone({
      coords   = vec3(coords.x, coords.y, coords.z),
      radius   = field.radius,
      label    = ('Recolter [E] — %s'):format(field.label),
      key      = 'E',
      onSelect = function()
        if not MissionLoop or ActiveJob ~= 'farmer' then return end
        doHarvest()
      end,
    })
    farmerState.fieldZones[#farmerState.fieldZones + 1] = zid

    -- Zone plantation (meme zone, touche G)
    local zid2 = exports['sl-interact']:AddZone({
      coords   = vec3(coords.x, coords.y, coords.z),
      radius   = field.radius,
      label    = ('Planter [G] — %s'):format(field.label),
      key      = 'G',
      onSelect = function()
        if not MissionLoop or ActiveJob ~= 'farmer' then return end
        doPlant()
      end,
    })
    farmerState.fieldZones[#farmerState.fieldZones + 1] = zid2

    -- Blip champ (stocke dans farmerState.blips pour nettoyage propre)
    local blip = AddBlip(coords, 88, 2, field.label, 0.7)
    farmerState.blips[#farmerState.blips + 1] = blip
  end
end

-- ---------------------------------------------------------------------------
-- Spawn PNJ moulin + interaction vente
-- ---------------------------------------------------------------------------
local function registerMill()
  cfg = JobMissions.Farmer
  local mc = cfg.Mill
  local coords = { x = mc.coords.x, y = mc.coords.y, z = mc.coords.z }

  farmerState.millPed = SpawnFreezePed(mc.pedModel, coords, mc.heading or 0)
  if not farmerState.millPed then return end

  -- Blip moulin (stocke pour nettoyage)
  local millBlip = AddBlip(coords, 280, 5, 'Moulin — Vente ble', 0.8)
  farmerState.blips[#farmerState.blips + 1] = millBlip

  farmerState.millInteract = exports['sl-interact']:AddEntity(farmerState.millPed, {
    label    = mc.label or 'Vendre ble [E]',
    key      = 'E',
    distance = 3.0,
    onSelect = function()
      if not MissionLoop or ActiveJob ~= 'farmer' then return end
      doSell()
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Boucle principale farmer (pas de boucle active, tout est event-driven via interact)
-- ---------------------------------------------------------------------------
function FarmerLoop()
  cfg = JobMissions.Farmer

  -- Nettoyage prealable
  cleanFarmer()

  -- Enregistrement des zones et PNJ
  registerFieldZones()
  registerMill()

  lib.notify({ description = 'Mode fermier actif. Recoltez et vendez au moulin !', type = 'inform' })

  -- Thread de surveillance : si le duty est coupe, on sort
  CreateThread(function()
    while MissionLoop and OnDuty and ActiveJob == 'farmer' do
      Wait(2000)
    end

    cleanFarmer()
    MissionLoop = false
    print('[sl-jobmissions/farmer] boucle terminee')
  end)
end
