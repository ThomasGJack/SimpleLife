print('[sl-gangs/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, citizenId, gangId, gangName, gangColor, grade }
-- GangMembers : gangId -> { [source] = true }   (membres connectes par gang)
-- Territories : zone -> { zone, gang_id, gang_name, gang_color, influence }
-- ===========================================================================
Cache        = Cache        or {}
GangMembers  = GangMembers  or {}   -- gangId (string) -> set de sources
Territories  = Territories  or {}   -- zone (string)   -> row en memoire

-- ===========================================================================
-- Bootstrap sl-core
-- ===========================================================================
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
    deps    = { 'sl-core@^0.1', 'sl-economy@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Helpers DB
-- ===========================================================================
local function db() return SL:DB() end

local function getGangById(gangId)
  return db().single('SELECT * FROM sl_gangs WHERE id = ?', { gangId })
end

local function getGangByName(name)
  return db().single('SELECT * FROM sl_gangs WHERE name = ?', { name })
end

local function getMemberRow(characterId)
  return db().single(
    'SELECT gm.*, g.name AS gang_name, g.color AS gang_color, g.boss_citizen_id FROM sl_gang_members gm'
    .. ' INNER JOIN sl_gangs g ON g.id = gm.gang_id'
    .. ' WHERE gm.character_id = ?',
    { characterId })
end

-- ===========================================================================
-- Seed territoires manquants au boot
-- ===========================================================================
local function seedTerritories()
  for _, t in ipairs(Gangs.Territories) do
    local exists = db().scalar(
      'SELECT COUNT(*) FROM sl_gang_territories WHERE zone = ?', { t.zone })
    if (exists or 0) == 0 then
      db().insert(
        'INSERT INTO sl_gang_territories (zone, gang_id, influence) VALUES (?, NULL, 0)',
        { t.zone })
    end
  end
end

-- Charge toutes les zones en memoire
local function loadTerritories()
  local rows = db().query(
    'SELECT gt.*, g.name AS gang_name, g.color AS gang_color'
    .. ' FROM sl_gang_territories gt'
    .. ' LEFT JOIN sl_gangs g ON g.id = gt.gang_id', {})
  for _, row in ipairs(rows or {}) do
    Territories[row.zone] = {
      id         = row.id,
      zone       = row.zone,
      gang_id    = row.gang_id,
      gang_name  = row.gang_name,
      gang_color = row.gang_color,
      influence  = tonumber(row.influence) or 0,
    }
  end
  print(('[sl-gangs] %d territories loaded'):format(#(rows or {})))
end

-- ===========================================================================
-- Hydration characterSelected
-- ===========================================================================
local function hydrate(source, characterId, citizenId)
  local row = getMemberRow(characterId)
  if row then
    Cache[source] = {
      characterId = characterId,
      citizenId   = citizenId,
      gangId      = row.gang_id,
      gangName    = row.gang_name,
      gangColor   = row.gang_color,
      grade       = tonumber(row.grade) or 0,
    }
    -- Enregistre dans le set GangMembers
    local gidKey = tostring(row.gang_id)
    GangMembers[gidKey] = GangMembers[gidKey] or {}
    GangMembers[gidKey][source] = true
  else
    Cache[source] = {
      characterId = characterId,
      citizenId   = citizenId,
      gangId      = nil,
      gangName    = nil,
      gangColor   = nil,
      grade       = nil,
    }
  end
  -- Push au client
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:gangs:hydrate', {
    gangName  = Cache[source].gangName,
    gangColor = Cache[source].gangColor,
    grade     = Cache[source].grade,
  })
end

AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  hydrate(payload.source, payload.characterId, payload.citizenId)
  print(('[sl-gangs] hydrated src=%d cid=%d gang=%s'):format(
    payload.source, payload.characterId, tostring(Cache[payload.source] and Cache[payload.source].gangName or 'none')))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if not payload or not payload.source then return end
  local src = payload.source
  local entry = Cache[src]
  if entry and entry.gangId then
    local gidKey = tostring(entry.gangId)
    if GangMembers[gidKey] then
      GangMembers[gidKey][src] = nil
      if next(GangMembers[gidKey]) == nil then
        GangMembers[gidKey] = nil
      end
    end
  end
  Cache[src] = nil
end)

-- ===========================================================================
-- Tick influence territoires
-- ===========================================================================
-- Retourne la liste des sources (connectes) appartenant a un gang
local function getOnlineMembers(gangId)
  local gidKey = tostring(gangId)
  local members = GangMembers[gidKey]
  if not members then return {} end
  local list = {}
  for src in pairs(members) do
    list[#list + 1] = src
  end
  return list
end

-- Verifie si un joueur est dans le rayon d'une zone
local function isPlayerInZone(src, zoneCfg)
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return false end
  local coords = GetEntityCoords(ped)
  if not coords then return false end
  local dx = coords.x - zoneCfg.coords.x
  local dy = coords.y - zoneCfg.coords.y
  local dz = coords.z - zoneCfg.coords.z
  local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
  return dist <= (Gangs.PresenceRadius or 60.0)
end

-- Compte le nombre de membres d'un gang presents dans une zone
local function countPresent(gangId, zoneCfg)
  local members = getOnlineMembers(gangId)
  local count = 0
  for _, src in ipairs(members) do
    if isPlayerInZone(src, zoneCfg) then
      count = count + 1
    end
  end
  return count
end

-- Retourne la liste des gangs avec au moins un membre dans la zone
local function gangsInZone(zoneCfg)
  local result = {}
  for gidKey, memberSet in pairs(GangMembers) do
    local gid = tonumber(gidKey)
    if gid then
      local n = 0
      for src in pairs(memberSet) do
        if isPlayerInZone(src, zoneCfg) then n = n + 1 end
      end
      if n > 0 then
        result[#result + 1] = { gangId = gid, count = n }
      end
    end
  end
  return result
end

local function persistTerritory(t)
  db().update(
    'UPDATE sl_gang_territories SET gang_id = ?, influence = ? WHERE zone = ?',
    { t.gang_id, t.influence, t.zone })
end

local function broadcastTerritories()
  local payload = {}
  for _, t in pairs(Territories) do
    payload[#payload + 1] = {
      zone      = t.zone,
      gang_name = t.gang_name,
      gang_color= t.gang_color,
      influence = t.influence,
    }
  end
  TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:territories', payload)
end

CreateThread(function()
  -- Attendre que sl-core soit pret
  while not tryIsReady() do Wait(500) end
  Wait(2000)  -- delai supplementaire pour les migrations
  seedTerritories()
  loadTerritories()
  broadcastTerritories()

  local tickMs = (Gangs.InfluenceTick or 30) * 1000

  while true do
    Wait(tickMs)

    local changed = false

    for _, zoneCfg in ipairs(Gangs.Territories) do
      local t = Territories[zoneCfg.zone]
      if not t then goto continue end

      local present = gangsInZone(zoneCfg)

      if #present == 0 then
        -- Decay passif si zone non gardee
        if t.influence > 0 then
          t.influence = math.max(0, t.influence - (Gangs.InfluenceDecayPerTick or 1))
          persistTerritory(t)
          changed = true
        end
      else
        -- Le gang dominant (le plus de membres) gagne de l'influence
        local dominant = present[1]
        for _, p in ipairs(present) do
          if p.count > dominant.count then dominant = p end
        end

        -- Si le gang dominant est deja proprietaire, il accumule
        if t.gang_id == dominant.gangId then
          t.influence = math.min(999, t.influence + (Gangs.InfluencePerMember or 2) * dominant.count)
          persistTerritory(t)
          changed = true
        else
          -- Un autre gang est present : si son influence depasse le proprietaire actuel
          -- on reduit l'influence du proprietaire, puis si 0 -> capture
          t.influence = math.max(0, t.influence - (Gangs.InfluencePerMember or 2) * dominant.count)
          if t.influence <= 0 then
            -- Capture !
            local newGang = getGangById(dominant.gangId)
            if newGang then
              t.gang_id    = dominant.gangId
              t.gang_name  = newGang.name
              t.gang_color = newGang.color
              t.influence  = Gangs.InfluencePerMember or 2
              persistTerritory(t)
              -- Event bus
              TriggerEvent('sl:gangs:territory', { zone = t.zone, gang = t.gang_name })
              TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:territory',
                { zone = t.zone, gang = t.gang_name })
              -- Notif globale
              for _, src in ipairs(GetPlayers()) do
                TriggerClientEvent('ox_lib:notify', tonumber(src), {
                  description = ('[Territoire] %s a capture %s !'):format(t.gang_name, zoneCfg.label),
                  type = 'inform',
                })
              end
              print(('[sl-gangs] territory %s captured by %s'):format(t.zone, t.gang_name))
            end
          else
            persistTerritory(t)
          end
          changed = true
        end
      end

      ::continue::
    end

    if changed then
      broadcastTerritories()
    end
  end
end)

-- ===========================================================================
-- Helpers exposes aux autres fichiers server
-- ===========================================================================
function GetCache(source) return Cache[source] end

function GetGangIdByName(name)
  local row = getGangByName(name)
  return row and row.id or nil
end

-- Recharge l'entree d'un joueur depuis la DB et notifie le client
function RefreshMember(source)
  local entry = Cache[source]
  if not entry then return end
  -- Retire de l'ancien GangMembers si necessaire
  if entry.gangId then
    local old = tostring(entry.gangId)
    if GangMembers[old] then
      GangMembers[old][source] = nil
      if next(GangMembers[old]) == nil then GangMembers[old] = nil end
    end
  end
  hydrate(source, entry.characterId, entry.citizenId)
end

-- Save sync au shutdown du resource
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  -- Rien a persister en runtime (tout est ecrit au fil de l'eau)
end)
