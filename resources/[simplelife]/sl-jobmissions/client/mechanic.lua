print('[sl-jobmissions/client] mechanic.lua loaded')

-- ===========================================================================
-- MECANO — logique complete
-- Cycle en continu : scanner les vehicules joueurs proches (< ScanRadius).
-- Pour chaque vehicule bless (body ou engine < max), ajouter une interaction
-- 'Reparer [E]' si le mecano a un repair_kit.
-- Reparation = anim progressBar → SetVehicleFixed (via sl-vehicles si dispo
-- sinon natives) → facture le mecano (paiement au click, pas au proprio).
-- ===========================================================================

local cfg = nil

-- Map netId -> interactId pour eviter les doublons
local activeInteracts = {}
-- Map netId -> true pour les vehicules repares recemment (cooldown)
local recentlyRepaired = {}

-- ---------------------------------------------------------------------------
-- Nettoyage de toutes les interactions
-- ---------------------------------------------------------------------------
local function cleanMechanic()
  for netId, iid in pairs(activeInteracts) do
    pcall(function() exports['sl-interact']:Remove(iid) end)
  end
  activeInteracts  = {}
  recentlyRepaired = {}
end

-- ---------------------------------------------------------------------------
-- Verifier si un vehicule a besoin de reparation
-- ---------------------------------------------------------------------------
local function vehicleNeedsRepair(veh)
  if not veh or not DoesEntityExist(veh) then return false end
  local body   = GetVehicleBodyHealth(veh)
  local engine = GetVehicleEngineHealth(veh)
  return body < (cfg.MaxBodyHealth - 50) or engine < (cfg.MaxEngineHealth - 50)
end

-- ---------------------------------------------------------------------------
-- Reparer un vehicule (sl-vehicles si disponible, sinon natives)
-- ---------------------------------------------------------------------------
local function repairVehicle(veh)
  -- Tenter sl-vehicles en premier
  local ok = pcall(function()
    exports['sl-vehicles']:RepairVehicle(NetworkGetNetworkIdFromEntity(veh))
  end)
  if not ok then
    -- Fallback natif
    SetVehicleFixed(veh)
    SetVehicleBodyHealth(veh, cfg.MaxBodyHealth)
    SetVehicleEngineHealth(veh, cfg.MaxEngineHealth)
    SetVehicleTyresCanBurst(veh, false)
    -- Re-autoriser les crevaisons apres la reparation
    CreateThread(function()
      Wait(1000)
      SetVehicleTyresCanBurst(veh, true)
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Ajoute une interaction sur un vehicule si elle n existe pas encore
-- ---------------------------------------------------------------------------
local function addVehicleInteract(veh)
  local netId = NetworkGetNetworkIdFromEntity(veh)
  if activeInteracts[netId] then return end
  if recentlyRepaired[netId] then return end
  if not vehicleNeedsRepair(veh) then return end

  local iid = exports['sl-interact']:AddEntity(veh, {
    label    = 'Reparer [E]',
    key      = 'E',
    distance = cfg.InteractDist,
    onSelect = function()
      cfg = JobMissions.Mechanic
      if not MissionLoop then return end

      -- Verifier repair_kit (cote client via exports sl-inventory client)
      local hasKit = false
      pcall(function()
        hasKit = exports['sl-inventory']:HasItem(cfg.RepairItem, 1)
      end)
      if not hasKit then
        lib.notify({ description = 'Il vous faut un kit de reparation.', type = 'error' })
        return
      end

      -- Animation de reparation
      local ped   = PlayerPedId()
      local coords = GetEntityCoords(veh)

      -- Charger anim dict
      RequestAnimDict('mini@repair')
      local t2 = 0
      while not HasAnimDictLoaded('mini@repair') do
        Wait(100)
        t2 = t2 + 100
        if t2 > 5000 then break end
      end

      local ok = lib.progressBar({
        duration        = cfg.RepairTime,
        label           = 'Reparation en cours...',
        useWhileDead    = false,
        canCancel       = true,
        disable         = { move = true, car = false, combat = true },
        anim            = { dict = 'mini@repair', clip = 'fixing_a_ped' },
      })

      if not ok then
        lib.notify({ description = 'Reparation annulee.', type = 'inform' })
        return
      end

      -- Retirer l interaction provisoirement
      pcall(function() exports['sl-interact']:Remove(activeInteracts[netId]) end)
      activeInteracts[netId] = nil
      recentlyRepaired[netId] = true

      -- Appel serveur : retire le kit + paiement
      local paid = lib.callback.await('sl-jobmissions:mechanic:pay', false, netId)
      if paid then
        repairVehicle(veh)
      end

      -- Cooldown 30s avant de re-proposer
      CreateThread(function()
        Wait(30000)
        recentlyRepaired[netId] = nil
      end)
    end,
  })

  activeInteracts[netId] = iid
end

-- ---------------------------------------------------------------------------
-- Retirer les interactions des vehicules hors portee ou deja repares
-- ---------------------------------------------------------------------------
local function pruneInteracts()
  local ped = PlayerPedId()
  local pos = GetEntityCoords(ped)

  for netId, iid in pairs(activeInteracts) do
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then
      pcall(function() exports['sl-interact']:Remove(iid) end)
      activeInteracts[netId] = nil
    elseif not vehicleNeedsRepair(veh) then
      pcall(function() exports['sl-interact']:Remove(iid) end)
      activeInteracts[netId] = nil
    else
      local vCoords = GetEntityCoords(veh)
      local d = Dist3D({ x = pos.x, y = pos.y, z = pos.z }, { x = vCoords.x, y = vCoords.y, z = vCoords.z })
      if d > cfg.ScanRadius * 2.0 then
        pcall(function() exports['sl-interact']:Remove(iid) end)
        activeInteracts[netId] = nil
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Boucle principale mecano
-- ---------------------------------------------------------------------------
function MechanicLoop()
  cfg = JobMissions.Mechanic

  lib.notify({ description = 'Mode mecano actif — reparez les vehicules proches.', type = 'inform' })

  CreateThread(function()
    while MissionLoop and OnDuty and ActiveJob == 'mechanic' do
      local ped = PlayerPedId()
      local pos = GetEntityCoords(ped)

      -- Scanner tous les vehicules proches
      local nearby = GetGamePool('CVehicle')
      for _, veh in ipairs(nearby) do
        if DoesEntityExist(veh) and not IsEntityDead(veh) then
          local vCoords = GetEntityCoords(veh)
          local d = Dist3D(
            { x = pos.x, y = pos.y, z = pos.z },
            { x = vCoords.x, y = vCoords.y, z = vCoords.z }
          )
          if d <= cfg.ScanRadius and vehicleNeedsRepair(veh) then
            addVehicleInteract(veh)
          end
        end
      end

      -- Nettoyer les interactions obsoletes
      pruneInteracts()

      Wait(1000)
    end

    cleanMechanic()
    MissionLoop = false
    print('[sl-jobmissions/mechanic] boucle terminee')
  end)
end
