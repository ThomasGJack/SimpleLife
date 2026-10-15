print('[sl-clothing/server] main.lua loaded')

local SL = exports['sl-core']
Cache = Cache or {}

local registered = false
local function tryReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end
local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps = { 'sl-core@^0.1', 'sl-economy@^0.1' },
  })
end
AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryReady() do Wait(200) end
  registerSelf()
end)

-- Normalise une table de components/props pour qu'elle utilise UNIQUEMENT
-- des clés string ("0", "1", "11"). Évite les bugs de cjson sur tables mixtes
-- (cf. shop.lua) qui faisaient disparaître certains composants au save.
local function normalizeKeys(t)
  if type(t) ~= 'table' then return {} end
  local out = {}
  for k, v in pairs(t) do
    out[tostring(k)] = v
  end
  return out
end

local function loadOrCreate(characterId, sex)
  local row = SL:DB().single(
    'SELECT model, components, props, head_blend FROM sl_appearance WHERE character_id = ?',
    { characterId }
  )
  if row then
    local components = (type(row.components) == 'string' and json.decode(row.components)) or row.components or {}
    local props      = (type(row.props)      == 'string' and json.decode(row.props))      or row.props      or {}
    return {
      model      = row.model,
      components = normalizeKeys(components),
      props      = normalizeKeys(props),
      headBlend  = row.head_blend and (type(row.head_blend) == 'string' and json.decode(row.head_blend) or row.head_blend) or nil,
    }
  end
  local def = Clothing.DefaultAppearance(sex)
  -- Normalise les clés AVANT save pour avoir une représentation stable dès le départ
  def.components = normalizeKeys(def.components)
  def.props      = normalizeKeys(def.props)
  SL:DB().insert(
    'INSERT INTO sl_appearance (character_id, model, components, props, head_blend) VALUES (?, ?, ?, ?, NULL)',
    { characterId, def.model, json.encode(def.components), json.encode(def.props) }
  )
  return def
end

AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local sex = (payload.data and payload.data.identity and payload.data.identity.sex) or 'm'
  local appearance = loadOrCreate(payload.characterId, sex)
  Cache[payload.source] = {
    characterId = payload.characterId,
    appearance = appearance,
  }
  TriggerClientEvent('sl:bus:dispatch', payload.source, 'sl:clothing:apply', appearance)
  print(('[sl-clothing] applied appearance src=%d cid=%d model=%s'):format(
    payload.source, payload.characterId, appearance.model))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then Cache[payload.source] = nil end
end)
