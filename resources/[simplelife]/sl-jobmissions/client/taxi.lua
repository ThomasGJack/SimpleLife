print('[sl-jobmissions/client] taxi.lua loaded')

-- ===========================================================================
-- TAXI — logique complete
-- Cycle : spawn PNJ a un coin de rue → interaction 'Prendre en charge' →
--         passager monte → blip destination → arrive → paiement distance.
-- ===========================================================================

local cfg = nil   -- reference vers JobMissions.Taxi (initialisee au debut de la boucle)

-- Etat courant de la mission taxi
local taxiState = {
  ped         = nil,    -- entite PNJ passager
  blip        = nil,    -- blip actif
  interactId  = nil,    -- id sl-interact
  passenger   = false,  -- passager a bord ?
  pickupCoords= nil,
  destCoords  = nil,
  startCoords = nil,    -- position du taxi au moment du pickup (calcul distance)
}

-- ---------------------------------------------------------------------------
-- Nettoyage complet de l etat en cours
-- ---------------------------------------------------------------------------
local function cleanTaxi()
  if taxiState.interactId then
    pcall(function() exports['sl-interact']:Remove(taxiState.interactId) end)
    taxiState.interactId = nil
  end
  if taxiState.blip and DoesBlipExist(taxiState.blip) then
    RemoveBlipSafe(taxiState.blip)
    taxiState.blip = nil
  end
  DeletePed(taxiState.ped)
  taxiState.ped         = nil
  taxiState.passenger   = false
  taxiState.pickupCoords= nil
  taxiState.destCoords  = nil
  taxiState.startCoords = nil
end

-- ---------------------------------------------------------------------------
-- Phase 1 : spawn PNJ a un coin de rue aleatoire, attendre que le taxi arrive
-- ---------------------------------------------------------------------------
local function spawnPassenger()
  cfg = JobMissions.Taxi

  -- Choisir un spot de pickup aleatoire
  local pickupRaw = TableRandom(cfg.PickupSpawns)
  local pickup    = { x = pickupRaw.x, y = pickupRaw.y, z = pickupRaw.z }

  -- Spawn PNJ
  local model   = TableRandom(cfg.PedModels)
  local ped     = SpawnFreezePed(model, pickup, math.random(0, 359))
  if not ped then
    lib.notify({ description = 'Impossible de spawner le passager.', type = 'error' })
    return false
  end
  taxiState.ped          = ped
  taxiState.pickupCoords = pickup

  -- Blip passager
  taxiState.blip = AddBlip(pickup, 361, 5, 'Client taxi', 0.9)
  SetBlipRoute(taxiState.blip, true)

  lib.notify({ description = 'Client taxi disponible — allez le chercher !', type = 'inform' })
  return true
end

-- ---------------------------------------------------------------------------
-- Phase 2 : interaction sur le PNJ pour le prendre en charge
-- ---------------------------------------------------------------------------
local function waitPickup()
  cfg = JobMissions.Taxi
  local picked = false

  taxiState.interactId = exports['sl-interact']:AddEntity(taxiState.ped, {
    label    = 'Prendre en charge [E]',
    key      = 'E',
    distance = cfg.PickupRadius,
    onSelect = function()
      -- Doit etre dans un vehicule (taxi)
      local ped = PlayerPedId()
      if not IsPedInAnyVehicle(ped, false) then
        lib.notify({ description = 'Montez dans votre vehicule d abord.', type = 'error' })
        return
      end
      picked = true
    end,
  })

  -- Attente de l interaction ou annulation
  while MissionLoop and not picked do
    Wait(300)
    -- Si le PNJ a disparu (bug), on abandonne
    if taxiState.ped and not DoesEntityExist(taxiState.ped) then
      break
    end
  end

  if taxiState.interactId then
    pcall(function() exports['sl-interact']:Remove(taxiState.interactId) end)
    taxiState.interactId = nil
  end

  return picked and MissionLoop
end

-- ---------------------------------------------------------------------------
-- Phase 3 : passager a bord → blip destination
-- ---------------------------------------------------------------------------
local function startRide()
  cfg = JobMissions.Taxi

  -- Retirer blip pickup, poser blip destination
  if taxiState.blip and DoesBlipExist(taxiState.blip) then
    RemoveBlipSafe(taxiState.blip)
    taxiState.blip = nil
  end

  -- Choisir destination differente du pickup
  local dest
  repeat
    dest = TableRandom(cfg.Destinations)
  until Dist3D({ x = dest.x, y = dest.y, z = dest.z }, taxiState.pickupCoords) > 200.0

  taxiState.destCoords  = { x = dest.x, y = dest.y, z = dest.z }
  taxiState.startCoords = GetEntityCoords(PlayerPedId())
  taxiState.passenger   = true

  taxiState.blip = AddBlip(taxiState.destCoords, 307, 2, dest.label or 'Destination', 0.9)
  SetBlipRoute(taxiState.blip, true)

  -- Le passager "monte" (animation de salutation du PNJ)
  TaskStartScenarioInPlace(taxiState.ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

  lib.notify({ description = ('Destination : %s'):format(dest.label or 'inconnue'), type = 'inform' })
end

-- ---------------------------------------------------------------------------
-- Phase 4 : attendre que le joueur arrive a destination
-- ---------------------------------------------------------------------------
local function waitDestination()
  cfg = JobMissions.Taxi
  local dest = taxiState.destCoords

  while MissionLoop do
    local pos = GetEntityCoords(PlayerPedId())
    local d   = Dist3D({ x = pos.x, y = pos.y, z = pos.z }, dest)
    if d <= cfg.DropRadius then return true end
    Wait(500)
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Phase 5 : paiement
-- ---------------------------------------------------------------------------
local function payFare()
  cfg = JobMissions.Taxi

  -- Calcul de la distance parcourue
  local startPos = taxiState.startCoords
  local endPos   = GetEntityCoords(PlayerPedId())
  local distance = Dist3D(
    { x = startPos.x, y = startPos.y, z = startPos.z },
    { x = endPos.x,   y = endPos.y,   z = endPos.z }
  )

  local fare = math.floor(distance / cfg.DistanceDivisor * cfg.TariffPerUnit)
  fare = math.max(cfg.MinFare, math.min(fare, cfg.MaxFare))

  -- Paiement via callback serveur
  local ok = lib.callback.await('sl-jobmissions:taxi:pay', false, fare, 'course-taxi')
  -- La notif est deja envoyee server-side en cas de succes
  if not ok then
    lib.notify({ description = 'Erreur de paiement.', type = 'error' })
  end
end

-- ---------------------------------------------------------------------------
-- Boucle principale taxi (appelee par StartMissionLoop)
-- ---------------------------------------------------------------------------
function TaxiLoop()
  cfg = JobMissions.Taxi

  CreateThread(function()
    while MissionLoop and OnDuty and ActiveJob == 'taxi' do
      cleanTaxi()

      -- Phase 1 : spawn passager
      if not spawnPassenger() then
        Wait(3000)
        goto continue
      end

      -- Phase 2 : aller chercher le client
      if not waitPickup() then
        cleanTaxi()
        goto continue
      end

      -- Phase 3 : prendre en charge → destination
      startRide()

      -- Phase 4 : conduire jusqu a la destination
      if not waitDestination() then
        cleanTaxi()
        goto continue
      end

      -- Phase 5 : paiement
      payFare()
      cleanTaxi()

      -- Pause avant prochain client
      if MissionLoop and OnDuty then
        lib.notify({ description = 'Prochain client dans 5 secondes...', type = 'inform', duration = 4000 })
        Wait(5000)
      end

      ::continue::
    end

    -- Fin de boucle : nettoyage
    cleanTaxi()
    MissionLoop = false
    print('[sl-jobmissions/taxi] boucle terminee')
  end)
end
