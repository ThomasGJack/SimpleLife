print('[sl-skills/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, skills = { [skill] = xp }, dirty }
-- ===========================================================================
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

-- ===========================================================================
-- Helpers internes
-- ===========================================================================

-- Insere les lignes manquantes pour toutes les competences d un personnage
local function ensureAllSkills(characterId)
  local db = SL:DB()
  for _, skill in ipairs(Skills.List) do
    -- INSERT IGNORE si la ligne n existe pas deja
    db.query(
      'INSERT IGNORE INTO sl_skills (character_id, skill, xp) VALUES (?, ?, 0)',
      { characterId, skill })
  end
end

-- Charge toutes les competences depuis la DB
local function loadSkills(characterId)
  local db = SL:DB()
  local rows = db.query(
    'SELECT skill, xp FROM sl_skills WHERE character_id = ?',
    { characterId })
  local map = {}
  if rows then
    for _, row in ipairs(rows) do
      map[row.skill] = tonumber(row.xp) or 0
    end
  end
  -- Remplit les competences manquantes a 0
  for _, skill in ipairs(Skills.List) do
    if not map[skill] then map[skill] = 0 end
  end
  return map
end

-- Persiste toutes les competences dirty d une entree cache
local function persistEntry(entry)
  if not entry or not entry.characterId then return end
  local db = SL:DB()
  for _, skill in ipairs(Skills.List) do
    local xp = entry.skills[skill]
    if xp then
      db.query(
        'INSERT INTO sl_skills (character_id, skill, xp) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp)',
        { entry.characterId, skill, xp })
    end
  end
  entry.dirty = false
end

-- ===========================================================================
-- Chargement au characterSelected
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source      = payload.source
  local characterId = payload.characterId

  -- Cree les lignes manquantes
  ensureAllSkills(characterId)
  -- Charge
  local skills = loadSkills(characterId)

  Cache[source] = {
    characterId = characterId,
    skills      = skills,
    dirty       = false,
  }

  print(('[sl-skills] hydrated src=%d cid=%d skills=%d'):format(
    source, characterId, #Skills.List))

  -- Dispatch initial au client
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:skills:sync', { skills = BuildPublicTable(source) })
end)

-- ===========================================================================
-- Nettoyage + persistance au playerDropped
-- ===========================================================================
AddEventHandler('sl:core:playerDropped', function(payload)
  if not payload or not payload.source then return end
  local entry = Cache[payload.source]
  if entry and entry.dirty then persistEntry(entry) end
  Cache[payload.source] = nil
end)

-- ===========================================================================
-- Sauvegarde periodique (dirty entries)
-- ===========================================================================
local lastSaveCheck = os.time()

CreateThread(function()
  while true do
    Wait((Skills.SaveIntervalSec or 120) * 1000)
    local now = os.time()
    if (now - lastSaveCheck) >= (Skills.SaveIntervalSec or 120) then
      lastSaveCheck = now
      for _, entry in pairs(Cache) do
        if entry.dirty then persistEntry(entry) end
      end
    end
  end
end)

-- Sauvegarde au shutdown du resource
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for _, entry in pairs(Cache) do
    if entry.dirty then persistEntry(entry) end
  end
end)

-- ===========================================================================
-- Helper public : construit la table lisible {skill->{xp,level}} pour un joueur
-- ===========================================================================
function BuildPublicTable(source)
  local entry = Cache[source]
  if not entry then return {} end
  local result = {}
  for _, skill in ipairs(Skills.List) do
    local xp = entry.skills[skill] or 0
    result[skill] = {
      xp    = xp,
      level = Skills.XpToLevel(xp),
    }
  end
  return result
end

function GetCacheEntry(source)
  return Cache[source]
end
