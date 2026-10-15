local SL = exports['sl-core']

lib.callback.register('sl-identity:select', function(source, slot)
  local player = SL:GetPlayer(source)
  if not player then return { ok = false, error = 'player not loaded' } end
  if type(slot) ~= 'number' then return { ok = false, error = 'invalid slot' } end

  local row = SL:DB().single(
    'SELECT id, slot, citizen_id, data, position FROM sl_characters WHERE account_id = ? AND slot = ?',
    { player.accountId, slot }
  )
  if not row then return { ok = false, error = 'character not found' } end

  SL:HydrateCharacter(source, row)

  local data = type(row.data) == 'string' and json.decode(row.data) or row.data or {}
  return {
    ok = true,
    character = {
      id = row.id,
      slot = row.slot,
      citizenId = row.citizen_id,
      identity = data.identity or {},
      position = type(row.position) == 'string' and json.decode(row.position) or row.position,
    },
  }
end)

lib.callback.register('sl-identity:delete', function(source, slot)
  local player = SL:GetPlayer(source)
  if not player then return { ok = false, error = 'player not loaded' } end

  local row = SL:DB().single(
    'SELECT id, citizen_id FROM sl_characters WHERE account_id = ? AND slot = ?',
    { player.accountId, slot }
  )
  if not row then return { ok = false, error = 'no character at slot' } end

  SL:DB().query('DELETE FROM sl_characters WHERE id = ?', { row.id })
  SL:EmitBus('sl:identity:characterDeleted', {
    source = source,
    citizenId = row.citizen_id,
  })
  return { ok = true }
end)

exports('GetCharacters', function(source)
  local player = SL:GetPlayer(source)
  if not player then return {} end
  return SL:DB().query(
    'SELECT id, slot, citizen_id, data FROM sl_characters WHERE account_id = ? AND deleted_at IS NULL ORDER BY slot',
    { player.accountId }
  ) or {}
end)

exports('GetActiveCharacter', function(source)
  local player = SL:GetPlayer(source)
  if not player or not player.characterId then return nil end
  return {
    id = player.characterId,
    citizenId = player.citizenId,
    data = player.data,
  }
end)
