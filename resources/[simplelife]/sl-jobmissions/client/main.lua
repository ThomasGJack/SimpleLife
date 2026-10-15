print('[sl-jobmissions/client] main.lua loaded')

-- ===========================================================================
-- Etat global du module (partagé entre les sous-fichiers client)
-- ===========================================================================
ActiveJob   = nil      -- nom du job actif ('taxi'|'trucker'|'mechanic'|'farmer'|nil)
OnDuty      = false    -- est-ce que le joueur est en service ?
MissionLoop = false    -- une mission est-elle en cours ?

-- ===========================================================================
-- Utilitaire : distance 2D entre deux tables {x,y,z}
-- ===========================================================================
function Dist3D(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  local dz = a.z - b.z
  return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Table config choisie selon le job actif
function GetJobCfg()
  if ActiveJob == 'taxi'     then return JobMissions.Taxi     end
  if ActiveJob == 'trucker'  then return JobMissions.Trucker  end
  if ActiveJob == 'mechanic' then return JobMissions.Mechanic end
  if ActiveJob == 'farmer'   then return JobMissions.Farmer   end
  return nil
end

-- ===========================================================================
-- Ecoute bus duty : 'sl:jobs:dutyChanged'
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  -- Duty change
  if event == 'sl:jobs:dutyChanged' then
    if not payload then return end
    local jobName = payload.name
    local duty    = payload.onDuty == true

    -- Determine si ca nous concerne
    local isMine = (jobName == 'taxi')
                or (jobName == 'trucker' or jobName == 'camionneur')
                or (jobName == 'mechanic' or jobName == 'mecano')
                or (jobName == 'farmer'  or jobName == 'fermier')

    if not isMine then return end

    -- Normalise le nom
    local norm = jobName
    if jobName == 'camionneur' then norm = 'trucker' end
    if jobName == 'mecano'     then norm = 'mechanic' end
    if jobName == 'fermier'    then norm = 'farmer' end

    if duty then
      ActiveJob = norm
      OnDuty    = true
      lib.notify({ description = ('Prise de service : %s'):format(norm), type = 'inform' })
      -- Lance automatiquement la boucle de mission
      CreateThread(function()
        Wait(500)
        StartMissionLoop()
      end)
    else
      OnDuty    = false
      MissionLoop = false
      -- La boucle active se terminera d elle-meme via MissionLoop == false
      lib.notify({ description = 'Fin de service.', type = 'inform' })
    end
  end

  -- Force stop (admin)
  if event == 'sl:jobmissions:forceStop' then
    MissionLoop = false
    OnDuty      = false
    lib.notify({ description = '[Admin] Mission stoppee.', type = 'error' })
  end

  -- Force start (admin)
  if event == 'sl:jobmissions:forceStart' then
    if payload and payload.name then
      ActiveJob   = payload.name
      OnDuty      = true
      MissionLoop = false
      CreateThread(function()
        Wait(200)
        StartMissionLoop()
      end)
    end
  end
end)

-- ===========================================================================
-- /work : (re)lancer une mission manuellement
-- ===========================================================================
RegisterCommand('work', function()
  if not OnDuty or not ActiveJob then
    lib.notify({ description = 'Vous n etes pas en service.', type = 'error' })
    return
  end
  if MissionLoop then
    lib.notify({ description = 'Une mission est deja en cours.', type = 'inform' })
    return
  end
  StartMissionLoop()
end, false)

-- ===========================================================================
-- Dispatcher : lance la boucle du bon metier
-- ===========================================================================
function StartMissionLoop()
  if not OnDuty or not ActiveJob then return end
  if MissionLoop then return end

  -- Valider que le job correspond a une boucle connue avant d armer MissionLoop,
  -- sinon (ex: nom invalide passe par /missionstart) on resterait bloque en
  -- MissionLoop=true sans aucune boucle ni nettoyage.
  if ActiveJob ~= 'taxi' and ActiveJob ~= 'trucker'
     and ActiveJob ~= 'mechanic' and ActiveJob ~= 'farmer' then
    lib.notify({ description = ('Metier inconnu : %s'):format(tostring(ActiveJob)), type = 'error' })
    return
  end

  MissionLoop = true

  if ActiveJob == 'taxi'     then TaxiLoop()     end
  if ActiveJob == 'trucker'  then TruckerLoop()  end
  if ActiveJob == 'mechanic' then MechanicLoop() end
  if ActiveJob == 'farmer'   then FarmerLoop()   end
end

-- ===========================================================================
-- Helpers generiques
-- ===========================================================================

-- Charge un modele de ped de facon bloquante
function LoadPedModel(model)
  local hash = GetHashKey(model)
  if not IsModelInCdimage(hash) then return nil end
  RequestModel(hash)
  local t = 0
  while not HasModelLoaded(hash) do
    Wait(100)
    t = t + 100
    if t > 10000 then return nil end
  end
  return hash
end

-- Cree un PNJ fige
function SpawnFreezePed(model, coords, heading)
  local hash = LoadPedModel(model)
  if not hash then return nil end
  local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
  SetEntityInvincible(ped, true)
  FreezeEntityPosition(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedFleeAttributes(ped, 0, false)
  SetPedCombatAttributes(ped, 46, true)
  SetModelAsNoLongerNeeded(hash)
  return ped
end

-- Supprime un ped proprement
function DeletePed(ped)
  if ped and DoesEntityExist(ped) then
    DeleteEntity(ped)
  end
end

-- Ajoute un blip simple
function AddBlip(coords, sprite, color, label, scale)
  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipSprite(blip, sprite or 1)
  SetBlipColour(blip, color or 3)
  SetBlipScale(blip, scale or 0.8)
  SetBlipAsShortRange(blip, false)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(label or 'Destination')
  EndTextCommandSetBlipName(blip)
  return blip
end

-- Supprime un blip
-- NOTE: ne PAS nommer cette fonction 'RemoveBlip' : un global de ce nom
-- masquerait la native RemoveBlip et provoquerait une recursion infinie
-- (stack overflow) a chaque suppression de blip.
function RemoveBlipSafe(blip)
  if blip and DoesBlipExist(blip) then
    RemoveBlip(blip)  -- native FiveM (non masquee ici)
  end
end

-- Attend que le joueur soit dans un rayon autour de coords
function WaitNearCoords(coords, radius, checkFn)
  while MissionLoop do
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local d   = Dist3D({ x = pos.x, y = pos.y, z = pos.z }, coords)
    if d <= radius then return true end
    if checkFn and not checkFn() then return false end
    Wait(500)
  end
  return false
end

-- Aleatoire dans une table
function TableRandom(t)
  return t[math.random(1, #t)]
end
