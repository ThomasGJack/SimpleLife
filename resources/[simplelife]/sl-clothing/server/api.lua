local SL = exports['sl-core']

local function persist(entry)
  SL:DB().update(
    'UPDATE sl_appearance SET model = ?, components = ?, props = ?, head_blend = ? WHERE character_id = ?',
    {
      entry.appearance.model,
      json.encode(entry.appearance.components or {}),
      json.encode(entry.appearance.props or {}),
      entry.appearance.headBlend and json.encode(entry.appearance.headBlend) or nil,
      entry.characterId,
    }
  )
end

local function getAppearance(source)
  local entry = Cache[source]
  if not entry then return nil end
  return entry.appearance
end

local function setAppearance(source, appearance)
  local entry = Cache[source]
  if not entry then return false, 'not loaded' end
  if type(appearance) ~= 'table' then return false, 'invalid appearance' end
  entry.appearance = {
    model = appearance.model or entry.appearance.model,
    components = appearance.components or entry.appearance.components,
    props = appearance.props or entry.appearance.props,
    headBlend = appearance.headBlend or entry.appearance.headBlend,
  }
  persist(entry)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:clothing:apply', entry.appearance)
  return true
end

exports('GetAppearance', getAppearance)
exports('SetAppearance', setAppearance)

lib.callback.register('sl-clothing:getAppearance', function(source)
  return getAppearance(source)
end)
