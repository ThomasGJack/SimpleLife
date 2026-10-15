print('[sl-police/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache source -> { characterId, citizenId, cuffed, cuffedBy, jailTimer, dirty }
-- OnDuty : table { [source] = true } pour les flics en service
-- ===========================================================================
Cache    = Cache    or {}
OnDuty   = OnDuty   or {}
Cuffed   = Cuffed   or {}   -- [target_src] = by_src
Jailed   = Jailed   or {}   -- [target_src] = { endAt, timer }

local function tryIsReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end

local registered = false
local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name    = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps    = { 'sl-core@^0.1', 'sl-jobs@^0.1', 'sl-inventory@^0.1', 'sl-economy@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Hydration / cleanup
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source then return end
  local src   = payload.source
  local cid   = payload.characterId
  local czid  = payload.citizenId or ''
  Cache[src]  = {
    characterId = cid,
    citizenId   = czid,
    cuffed      = false,
    cuffedBy    = nil,
  }
  print(('[sl-police] hydrated src=%s cid=%s czid=%s'):format(tostring(src), tostring(cid), tostring(czid)))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if not payload or not payload.source then return end
  local src = payload.source
  -- Liberer les entraves si le joueur drop
  if Cuffed[src] then
    Cuffed[src] = nil
    TriggerEvent('sl:police:uncuffed', { target = src })
  end
  if Jailed[src] then
    if Jailed[src].thread then
      -- on ne peut pas stopper un thread mais le callback n'aura plus de src valide
    end
    Jailed[src] = nil
  end
  Cache[src]  = nil
  OnDuty[src] = nil
end)

-- ===========================================================================
-- DUTY hook : 'sl:jobs:dutyChanged'
-- ===========================================================================
AddEventHandler('sl:jobs:dutyChanged', function(payload)
  if not payload or not payload.source then return end
  local src    = payload.source
  local name   = payload.name
  local onDuty = payload.onDuty

  if name ~= Police.JobName then return end

  if onDuty then
    OnDuty[src] = true
    -- Distribution du kit police
    local ok, err = pcall(function()
      exports['sl-inventory']:GiveJobKit(src, Police.JobKit)
    end)
    if not ok then
      print('[sl-police] GiveJobKit error: ' .. tostring(err))
    end
    TriggerClientEvent('ox_lib:notify', src, {
      description = 'Kit police distribue. Bonne patrouille.',
      type = 'success',
    })
  else
    OnDuty[src] = nil
    local ok, err = pcall(function()
      exports['sl-inventory']:RemoveJobKit(src, Police.JobKit)
    end)
    if not ok then
      print('[sl-police] RemoveJobKit error: ' .. tostring(err))
    end
  end
end)

-- ===========================================================================
-- ALERTE crime : ecoute 'sl:crime:robberyStarted'
-- ===========================================================================
AddEventHandler('sl:crime:robberyStarted', function(payload)
  if not payload then return end
  local shopName = payload.shop   or 'Inconnu'
  local coords   = payload.coords or { x=0, y=0, z=0 }

  -- Notif + blip a tous les flics en service
  for src, _ in pairs(OnDuty) do
    TriggerClientEvent('ox_lib:notify', src, {
      title       = 'ALERTE — BRAQUAGE EN COURS',
      description = ('Commerce : %s'):format(shopName),
      type        = 'error',
      duration    = 8000,
    })
    -- Envoie coords pour blip GPS temporaire
    TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:robberyAlert', {
      shop   = shopName,
      coords = coords,
    })
  end
end)

-- ===========================================================================
-- Helper : obtenir le citizenId d'une source connectee
-- ===========================================================================
function GetCitizenId(src)
  local entry = Cache[src]
  return entry and entry.citizenId or nil
end

function GetCharId(src)
  local entry = Cache[src]
  return entry and entry.characterId or nil
end
