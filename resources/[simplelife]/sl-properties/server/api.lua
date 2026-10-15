print('[sl-properties/server] api.lua loaded')

-- Les `local` Lua sont scopés au fichier (chunk). main.lua declare `local SL`
-- qui n'est PAS visible ici -> on le redeclare pour ce fichier, sinon tous les
-- SL:DB() crashent (nil deref). Meme correctif que sl-police/crime/gangs.
local SL = exports['sl-core']

-- ===========================================================================
-- Helpers internes
-- ===========================================================================

-- Verifie si source a acces a propId (owner OU access table)
function HasAccessInternal(source, propId)
  local cid = GetCharId(source)
  if not cid then return false end
  propId = tonumber(propId)

  -- Owner direct
  local prop = LoadProperty(propId)
  if not prop then return false end
  if prop.owner == cid then return true end

  -- Acces partage
  local row = SL:DB().single(
    'SELECT id FROM sl_property_access WHERE property_id = ? AND character_id = ?',
    { propId, cid }
  )
  return row ~= nil
end

-- ===========================================================================
-- EXPORTS PUBLICS
-- ===========================================================================

-- HasAccess(src, propId) -> bool
exports('HasAccess', function(src, propId)
  return HasAccessInternal(src, tonumber(propId))
end)

-- OpenStash(src, propId) -> force l'ouverture du coffre depuis un autre module
exports('OpenStash', function(src, propId)
  local cid = GetCharId(src)
  if not cid then return end
  propId = tonumber(propId)
  if not HasAccessInternal(src, propId) then return end

  local prop = LoadProperty(propId)
  if not prop then return end

  local rows = SL:DB().query(
    'SELECT slot, item, count, metadata FROM sl_property_stash WHERE property_id = ?',
    { propId }
  )
  local slots = {}
  if rows then
    for _, row in ipairs(rows) do
      local s = tostring(tonumber(row.slot))
      slots[s] = {
        item     = row.item,
        count    = tonumber(row.count),
        metadata = row.metadata and (type(row.metadata) == 'string' and json.decode(row.metadata) or row.metadata) or {},
      }
    end
  end
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:properties:stashOpen', {
    propId    = propId,
    label     = prop.label,
    slots     = slots,
    slotCount = Properties.StashSlots,
    maxWeight = Properties.StashMaxWeight,
    catalog   = GetItemCatalog(),
  })
end)

-- GetOwned(src) -> array des proprietes possedees
exports('GetOwned', function(src)
  local cid = GetCharId(src)
  if not cid then return {} end
  local rows = SL:DB().query(
    'SELECT * FROM sl_properties WHERE owner_character_id = ?', { cid }
  )
  local list = {}
  if rows then
    for _, row in ipairs(rows) do
      local enter = type(row.enter_pos) == 'string' and json.decode(row.enter_pos) or row.enter_pos
      local inter = type(row.interior_pos) == 'string' and json.decode(row.interior_pos) or row.interior_pos
      list[#list + 1] = {
        id           = tonumber(row.id),
        label        = row.label,
        type         = row.type,
        price        = tonumber(row.price),
        enter_pos    = enter,
        interior_pos = inter,
        ipl          = row.ipl,
      }
    end
  end
  return list
end)

-- EnterProperty(src, propId) -> force l'entree dans la propriete
exports('EnterProperty', function(src, propId)
  propId = tonumber(propId)
  if not HasAccessInternal(src, propId) then return false end
  local prop = LoadProperty(propId)
  if not prop then return false end

  if Cache[src] then Cache[src].propId = propId end
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:properties:doEnter', {
    propId       = propId,
    label        = prop.label,
    interior_pos = prop.interior_pos,
    ipl          = prop.ipl,
  })
  return true
end)

-- ===========================================================================
-- Partage d'acces : AddAccess / RemoveAccess
-- ===========================================================================
function AddPropertyAccess(src, propId, targetCid)
  local cid = GetCharId(src)
  if not cid then return false, 'not_loaded' end
  propId = tonumber(propId)
  targetCid = tonumber(targetCid)

  local prop = LoadProperty(propId)
  if not prop then return false, 'prop_not_found' end
  if prop.owner ~= cid then return false, 'not_owner' end

  -- Evite le doublon
  local existing = SL:DB().single(
    'SELECT id FROM sl_property_access WHERE property_id = ? AND character_id = ?',
    { propId, targetCid }
  )
  if existing then return false, 'already_has_access' end

  SL:DB().insert(
    'INSERT INTO sl_property_access (property_id, character_id) VALUES (?, ?)',
    { propId, targetCid }
  )
  return true, 'ok'
end

function RemovePropertyAccess(src, propId, targetCid)
  local cid = GetCharId(src)
  if not cid then return false, 'not_loaded' end
  propId = tonumber(propId)
  targetCid = tonumber(targetCid)

  local prop = LoadProperty(propId)
  if not prop then return false, 'prop_not_found' end
  if prop.owner ~= cid then return false, 'not_owner' end

  SL:DB().update(
    'DELETE FROM sl_property_access WHERE property_id = ? AND character_id = ?',
    { propId, targetCid }
  )
  return true, 'ok'
end

exports('AddAccess',    AddPropertyAccess)
exports('RemoveAccess', RemovePropertyAccess)
