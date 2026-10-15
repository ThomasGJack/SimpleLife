print('[sl-death/server] main.lua loaded')

local SL = exports['sl-core']

-- ============================================================
-- Cache : source -> { state='alive'|'downed'|'dead',
--                     bleedLevel=0..3,
--                     downedAt=os.time() (nil si alive),
--                     characterId=nil }
-- ============================================================
Cache = Cache or {}

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
    deps    = { 'sl-core@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ============================================================
-- Hydration au character selected
-- ============================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source then return end
  local source = payload.source
  Cache[source] = {
    state       = 'alive',
    bleedLevel  = 0,
    downedAt    = nil,
    characterId = payload.characterId,
  }
  print(('[sl-death] hydrated src=%d cid=%s state=alive'):format(
    source, tostring(payload.characterId)))
end)

-- ============================================================
-- Cleanup au drop
-- ============================================================
AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    Cache[payload.source] = nil
  end
end)

-- ============================================================
-- Helper : dispatch vers le client via le bus
-- ============================================================
local function dispatchClient(source, event, payload)
  TriggerClientEvent('sl:bus:dispatch', source, event, payload)
end

-- ============================================================
-- Helper : clamp
-- ============================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

-- ============================================================
-- SetState interne : met a jour le cache et emet les events bus
-- ============================================================
local function setState(source, newState, by)
  local entry = Cache[source]
  if not entry then return end
  local old = entry.state
  entry.state = newState

  if newState == 'downed' and old ~= 'downed' then
    entry.downedAt = os.time()
    entry.bleedLevel = clamp(entry.bleedLevel, 0, 3)
    -- event global (sl-ems, sl-hud, sl-police)
    TriggerEvent('sl:death:downed', { source = source })
    dispatchClient(source, 'sl:death:downed', { source = source })

  elseif newState == 'alive' and old ~= 'alive' then
    entry.downedAt   = nil
    entry.bleedLevel = 0
    local revivPayload = { source = source, by = by or 0 }
    TriggerEvent('sl:death:revived', revivPayload)
    dispatchClient(source, 'sl:death:revived', revivPayload)

  elseif newState == 'dead' and old ~= 'dead' then
    entry.downedAt = nil
    -- pas d event 'dead' specifique : on enchaine direct respawn
  end
end

-- ============================================================
-- Tick serveur : surveille le timer de mort pour les joueurs downed
-- ============================================================
CreateThread(function()
  while true do
    Wait(Death.BleedTickMs or 5000)
    local now = os.time()
    for source, entry in pairs(Cache) do
      if entry.state == 'downed' and entry.downedAt then
        local elapsed    = now - entry.downedAt
        local extraDrain = Death.BleedDrainPerLevel[entry.bleedLevel] or 0
        -- On simule le drain : elapsed + bonus bleed > DeathTimerSec => respawn
        local effective = elapsed + (extraDrain * math.floor(elapsed / ((Death.BleedTickMs or 5000) / 1000)))
        if effective >= (Death.DeathTimerSec or 300) then
          -- Timer epuise : respawn hopital force
          print(('[sl-death] timer expired for src=%d -> respawn'):format(source))
          -- on passe par l API Respawn (definie dans api.lua)
          RespawnToHospital(source)
        else
          -- Sync timer restant vers client
          local remaining = math.max(0, (Death.DeathTimerSec or 300) - effective)
          dispatchClient(source, 'sl:death:timerTick', {
            source    = source,
            remaining = math.floor(remaining),
            bleed     = entry.bleedLevel,
          })
        end
      end
    end
  end
end)

-- ============================================================
-- Event client : joueur signale qu il vient de tomber (HP <= seuil)
-- ============================================================
RegisterNetEvent('sl:death:clientDowned', function()
  local source = source
  local entry  = Cache[source]
  if not entry or entry.state ~= 'alive' then return end
  setState(source, 'downed')
  print(('[sl-death] src=%d is now downed'):format(source))
end)

-- ============================================================
-- Helpers globaux utilises par api.lua + commands.lua
-- ============================================================
function GetEntry(source)
  return Cache[source]
end

function SetBleedInternal(source, level)
  local entry = Cache[source]
  if not entry then return false, 'not loaded' end
  level = math.floor(tonumber(level) or 0)
  level = clamp(level, 0, 3)
  entry.bleedLevel = level
  TriggerEvent('sl:death:bleedChanged', { source = source, level = level })
  dispatchClient(source, 'sl:death:bleedChanged', { source = source, level = level })
  return true
end

function SetStatePublic(source, newState, by)
  setState(source, newState, by)
end

function DispatchClient(source, event, payload)
  dispatchClient(source, event, payload)
end

-- RespawnToHospital est defini dans api.lua (besoin des exports sl-economy)
-- On pre-declare pour que main.lua puisse l appeler depuis le tick
RespawnToHospital = RespawnToHospital or function(source)
  -- sera remplace par la vraie fonction dans api.lua
  print('[sl-death] WARNING: RespawnToHospital called before api.lua loaded for src=' .. tostring(source))
end
