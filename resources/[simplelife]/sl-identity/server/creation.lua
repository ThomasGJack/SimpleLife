local SL = exports['sl-core']

local function uniqueCitizenId()
  for _ = 1, 20 do
    local cid = SL:GenCitizenId()
    if SL:IsCitizenIdAvailable(cid) then return cid end
  end
  error('citizenId generation failed after 20 retries')
end

local function validatePayload(p)
  if type(p) ~= 'table' then return false, 'invalid payload' end
  if type(p.firstName) ~= 'string' or #p.firstName < 2 or #p.firstName > 30 then return false, 'firstName invalide (2-30 chars)' end
  if type(p.lastName) ~= 'string' or #p.lastName < 2 or #p.lastName > 30 then return false, 'lastName invalide (2-30 chars)' end
  if type(p.dob) ~= 'string' or not p.dob:match('^%d%d%d%d%-%d%d%-%d%d$') then return false, 'date de naissance invalide (YYYY-MM-DD)' end
  if p.sex ~= 'm' and p.sex ~= 'f' then return false, 'sexe invalide' end
  if type(p.nationality) ~= 'string' or #p.nationality < 2 then return false, 'nationalité invalide' end
  return true
end

lib.callback.register('sl-identity:listCharacters', function(source)
  local player = SL:GetPlayer(source)
  if not player then return {} end
  local rows = SL:DB().query(
    'SELECT id, slot, citizen_id, data, position FROM sl_characters WHERE account_id = ? ORDER BY slot',
    { player.accountId }
  ) or {}
  local out = {}
  for _, r in ipairs(rows) do
    local data = type(r.data) == 'string' and json.decode(r.data) or r.data or {}
    table.insert(out, {
      id = r.id,
      slot = r.slot,
      citizenId = r.citizen_id,
      identity = data.identity or {},
    })
  end
  return out
end)

lib.callback.register('sl-identity:create', function(source, slot, payload)
  local player = SL:GetPlayer(source)
  if not player then return { ok = false, error = 'player not loaded' } end
  if type(slot) ~= 'number' or slot < 1 or slot > Identity.MaxSlots then return { ok = false, error = 'invalid slot' } end
  local ok, err = validatePayload(payload)
  if not ok then return { ok = false, error = err } end

  local existing = SL:DB().single(
    'SELECT id FROM sl_characters WHERE account_id = ? AND slot = ?',
    { player.accountId, slot }
  )
  if existing then return { ok = false, error = 'slot déjà utilisé' } end

  local citizenId = uniqueCitizenId()
  local data = {
    identity = {
      firstName = payload.firstName,
      lastName = payload.lastName,
      dob = payload.dob,
      sex = payload.sex,
      nationality = payload.nationality,
      phone = '',
    },
  }

  local id = SL:DB().insert(
    'INSERT INTO sl_characters (account_id, slot, citizen_id, data) VALUES (?, ?, ?, ?)',
    { player.accountId, slot, citizenId, json.encode(data) }
  )

  SL:Bus().Emit('sl:identity:characterCreated', {
    source = source,
    citizenId = citizenId,
    characterId = id,
    slot = slot,
  })

  return {
    ok = true,
    character = {
      id = id,
      slot = slot,
      citizenId = citizenId,
      identity = data.identity,
    },
  }
end)
