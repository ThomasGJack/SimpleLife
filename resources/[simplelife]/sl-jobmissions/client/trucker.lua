print('[sl-jobmissions/client] trucker.lua loaded')

-- ===========================================================================
-- TRUCKER — logique complete
-- Cycle : aller au depot → charger N palettes (progressBar x N) →
--         blip livraison → livrer → paiement par palette.
-- ===========================================================================

local cfg = nil

-- Etat courant
local truckerState = {
  depotPed    = nil,
  depotInteract = nil,
  delivBlip   = nil,
  loadedPalettes = 0,
  destCoords  = nil,
  loading     = false,
}

-- ---------------------------------------------------------------------------
-- Nettoyage
-- ---------------------------------------------------------------------------
local function cleanTrucker()
  if truckerState.depotInteract then
    pcall(function() exports['sl-interact']:Remove(truckerState.depotInteract) end)
    truckerState.depotInteract = nil
  end
  if truckerState.delivBlip and DoesBlipExist(truckerState.delivBlip) then
    RemoveBlipSafe(truckerState.delivBlip)
    truckerState.delivBlip = nil
  end
  DeletePed(truckerState.depotPed)
  truckerState.depotPed       = nil
  truckerState.loadedPalettes = 0
  truckerState.destCoords     = nil
  truckerState.loading        = false
end

-- ---------------------------------------------------------------------------
-- Verifier que le joueur est dans un camion accepte
-- ---------------------------------------------------------------------------
local function isInTruck()
  local ped = PlayerPedId()
  if not IsPedInAnyVehicle(ped, false) then return false end
  local veh   = GetVehiclePedIsIn(ped, false)
  local model = GetEntityModel(veh)
  for _, m in ipairs(cfg.TruckModels) do
    if model == GetHashKey(m) then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Phase 1 : aller au depot, PNJ depot, charger les palettes
-- ---------------------------------------------------------------------------
local function doDepotPhase()
  cfg = JobMissions.Trucker
  local depotCfg = cfg.Depot
  local depotCoords = { x = depotCfg.coords.x, y = depotCfg.coords.y, z = depotCfg.coords.z }

  -- Spawn PNJ depot s il n existe pas
  if not truckerState.depotPed or not DoesEntityExist(truckerState.depotPed) then
    truckerState.depotPed = SpawnFreezePed(depotCfg.pedModel, depotCoords, depotCfg.heading or 0)
  end

  -- Blip depot
  local depotBlip = AddBlip(depotCoords, 473, 4, 'Depot routier', 0.9)
  SetBlipRoute(depotBlip, true)

  lib.notify({ description = 'Rendez-vous au depot pour charger.', type = 'inform' })

  -- Attendre que le joueur arrive au depot
  while MissionLoop do
    local pos = GetEntityCoords(PlayerPedId())
    local d   = Dist3D({ x = pos.x, y = pos.y, z = pos.z }, depotCoords)
    if d <= 20.0 then break end
    Wait(500)
  end

  if depotBlip and DoesBlipExist(depotBlip) then
    RemoveBlipSafe(depotBlip)
  end

  if not MissionLoop then return false end

  -- Interaction sur le PNJ pour charger
  local totalPalettes = cfg.PaletteCount
  truckerState.loadedPalettes = 0
  local loadDone = false

  truckerState.depotInteract = exports['sl-interact']:AddEntity(truckerState.depotPed, {
    label    = 'Charger palettes [E]',
    key      = 'E',
    distance = 4.0,
    onSelect = function()
      if truckerState.loading then return end
      if not isInTruck() then
        lib.notify({ description = 'Vous devez etre dans un camion.', type = 'error' })
        return
      end

      truckerState.loading = true

      -- Charger chaque palette avec une progressBar
      CreateThread(function()
        for i = 1, totalPalettes do
          if not MissionLoop then break end
          local ok = lib.progressBar({
            duration = cfg.LoadTime,
            label    = ('Chargement palette %d/%d...'):format(i, totalPalettes),
            useWhileDead    = false,
            canCancel       = false,
            disable = { move = true, car = false, combat = true },
            anim    = { dict = 'anim@heists@box_carry@', clip = 'idle' },
          })
          if ok then
            truckerState.loadedPalettes = i
            lib.notify({ description = ('Palette %d/%d chargee'):format(i, totalPalettes), type = 'success', duration = 2000 })
          end
        end
        truckerState.loading = false
        loadDone = (truckerState.loadedPalettes >= totalPalettes)
      end)
    end,
  })

  -- Attendre fin du chargement
  while MissionLoop and not loadDone do
    Wait(500)
    -- re-verifier manuellement si loadedPalettes est atteint
    if truckerState.loadedPalettes >= totalPalettes then
      loadDone = true
    end
  end

  if truckerState.depotInteract then
    pcall(function() exports['sl-interact']:Remove(truckerState.depotInteract) end)
    truckerState.depotInteract = nil
  end

  return loadDone and MissionLoop
end

-- ---------------------------------------------------------------------------
-- Phase 2 : livraison
-- ---------------------------------------------------------------------------
local function doDeliveryPhase()
  cfg = JobMissions.Trucker
  local dest = TableRandom(cfg.Deliveries)
  truckerState.destCoords = { x = dest.x, y = dest.y, z = dest.z }

  truckerState.delivBlip = AddBlip(truckerState.destCoords, 477, 2, dest.label or 'Point de livraison', 0.9)
  SetBlipRoute(truckerState.delivBlip, true)

  lib.notify({ description = ('Livraison : %s'):format(dest.label or '?'), type = 'inform' })

  -- Attendre arrivee
  while MissionLoop do
    local pos = GetEntityCoords(PlayerPedId())
    local d   = Dist3D({ x = pos.x, y = pos.y, z = pos.z }, truckerState.destCoords)
    if d <= 12.0 then break end
    Wait(500)
  end

  if truckerState.delivBlip and DoesBlipExist(truckerState.delivBlip) then
    RemoveBlipSafe(truckerState.delivBlip)
    truckerState.delivBlip = nil
  end

  if not MissionLoop then return false end

  -- Animation de dechargement
  local ped = PlayerPedId()
  local ok = lib.progressBar({
    duration        = cfg.LoadTime,
    label           = 'Dechargement...',
    useWhileDead    = false,
    canCancel       = false,
    disable         = { move = true, car = false, combat = true },
    anim            = { dict = 'anim@heists@box_carry@', clip = 'idle' },
  })

  if not ok then return false end

  -- Paiement serveur
  local palettes = truckerState.loadedPalettes
  lib.callback.await('sl-jobmissions:trucker:pay', false, palettes)

  return true
end

-- ---------------------------------------------------------------------------
-- Boucle principale trucker
-- ---------------------------------------------------------------------------
function TruckerLoop()
  cfg = JobMissions.Trucker

  CreateThread(function()
    while MissionLoop and OnDuty and ActiveJob == 'trucker' do
      cleanTrucker()

      -- Charger au depot
      local loaded = doDepotPhase()
      if not loaded then
        cleanTrucker()
        Wait(3000)
        goto continue
      end

      -- Livrer
      doDeliveryPhase()
      cleanTrucker()

      -- Pause avant prochain trajet
      if MissionLoop and OnDuty then
        lib.notify({ description = 'Prochain trajet dans 5 secondes...', type = 'inform', duration = 4000 })
        Wait(5000)
      end

      ::continue::
    end

    cleanTrucker()
    MissionLoop = false
    print('[sl-jobmissions/trucker] boucle terminee')
  end)
end
