print('[sl-phone/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, number }
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
    name = GetCurrentResourceName(),
    version = '0.2.0',
    coreApi = apiOk and api or 1,
    deps = { 'sl-core@^0.1', 'sl-inventory@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Génération de numéro US unique : (NXX) NXX-XXXX
--   N = 2-9 (jamais 0 ou 1)
--   X = 0-9
-- Si Phone.NumberAreaCode est défini, l'area code est fixé. Sinon random N+digit+digit.
-- ===========================================================================

local function digitN()
  return tostring(math.random(2, 9))
end
local function digitX()
  return tostring(math.random(0, 9))
end

local function generateRawNumber()
  local areaCode = Phone.NumberAreaCode
  if not areaCode then
    areaCode = digitN() .. digitX() .. digitX()
  end
  -- exchange (NXX)
  local exchange = digitN() .. digitX() .. digitX()
  -- subscriber (4 chiffres)
  local subscriber = digitX() .. digitX() .. digitX() .. digitX()
  return areaCode .. exchange .. subscriber  -- 10 chiffres bruts
end

local function generateUniqueNumber()
  local db = SL:DB()
  for attempt = 1, 200 do
    local candidate = generateRawNumber()
    local existing = db.single('SELECT character_id FROM sl_phone_numbers WHERE number = ?', { candidate })
    if not existing then return candidate end
  end
  return nil
end

-- Récupère ou crée le numéro d'un personnage.
function GetOrCreateNumber(characterId)
  if not characterId then return nil end
  local db = SL:DB()
  local row = db.single('SELECT number FROM sl_phone_numbers WHERE character_id = ?', { characterId })
  if row then return row.number end
  local number = generateUniqueNumber()
  if not number then
    print('[sl-phone] ERROR: failed to generate unique number after 200 attempts')
    return nil
  end
  db.insert('INSERT INTO sl_phone_numbers (character_id, number) VALUES (?, ?)', { characterId, number })
  print(('[sl-phone] new number assigned to cid=%d : %s'):format(characterId, number))
  return number
end

-- ===========================================================================
-- Lookup helpers (utilisés par api.lua)
-- ===========================================================================

function FindPlayerByCharacterId(characterId)
  for source, entry in pairs(Cache) do
    if entry.characterId == characterId then return source end
  end
  return nil
end

-- Renvoie (source, characterId) pour un numéro.
-- source peut être nil si le joueur est hors-ligne mais le numéro existe.
function FindByNumber(rawNumber)
  if not rawNumber then return nil, nil end
  rawNumber = Phone.NormalizeNumber(rawNumber)
  for source, entry in pairs(Cache) do
    if entry.number == rawNumber then return source, entry.characterId end
  end
  local row = SL:DB().single('SELECT character_id FROM sl_phone_numbers WHERE number = ?', { rawNumber })
  if row then return nil, tonumber(row.character_id) end
  return nil, nil
end

-- ===========================================================================
-- Cycle de vie joueur
-- ===========================================================================

AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source = payload.source
  local characterId = payload.characterId
  local number = GetOrCreateNumber(characterId)
  Cache[source] = { characterId = characterId, number = number }
  print(('[sl-phone] hydrated src=%d cid=%d number=%s'):format(source, characterId, tostring(number)))
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:phone:hydrated', { number = number })
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    -- Si le joueur était en appel, raccroche pour son peer et nettoie
    if type(PhoneStopCallAudio) == 'function' then
      PhoneStopCallAudio(payload.source)
    end
    Cache[payload.source] = nil
  end
end)

function GetCache(source) return Cache[source] end
