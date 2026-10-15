print('[sl-crime/server] api.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- API publique exports sl-crime
-- ===========================================================================

-- IsOnCooldown(kind, target) -> bool
-- Utilisable par d'autres modules : exports['sl-crime']:IsOnCooldown(kind, target)
exports('IsOnCooldown', function(kind, target)
  if not kind or not target then return false end
  local db = SL:DB()
  local row = db.single(
    'SELECT until_ts FROM sl_crime_cooldowns WHERE kind = ? AND target = ?',
    { tostring(kind), tostring(target) }
  )
  if not row then return false end
  local ts = tonumber(row.until_ts) or 0
  return ts > math.floor(os.time())
end)

-- GetCooldownRemaining(kind, target) -> secondes restantes (0 si pas de cooldown)
exports('GetCooldownRemaining', function(kind, target)
  if not kind or not target then return 0 end
  local db = SL:DB()
  local row = db.single(
    'SELECT until_ts FROM sl_crime_cooldowns WHERE kind = ? AND target = ?',
    { tostring(kind), tostring(target) }
  )
  if not row then return 0 end
  local rem = (tonumber(row.until_ts) or 0) - math.floor(os.time())
  return rem > 0 and rem or 0
end)

-- GetActivePlants() -> table des plants en memoire (usage debug/admin)
exports('GetActivePlants', function()
  local out = {}
  for pid, p in pairs(Plants or {}) do
    out[tostring(pid)] = {
      id          = pid,
      characterId = p.characterId,
      coords      = { x = p.coords.x, y = p.coords.y, z = p.coords.z },
      grownAt     = p.grownAt,
      harvested   = p.harvested,
    }
  end
  return out
end)

-- ===========================================================================
-- Commandes admin
-- ===========================================================================
RegisterCommand('crime:clearcooldown', function(source, args)
  if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'sl.admin') then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Permission refusee.', type = 'error' })
    end
    return
  end
  local kind   = args[1]
  local target = args[2]
  if not kind or not target then
    if source == 0 then print('[sl-crime] usage: crime:clearcooldown <kind> <target>') end
    return
  end
  SL:DB().update(
    'DELETE FROM sl_crime_cooldowns WHERE kind = ? AND target = ?',
    { kind, target }
  )
  local msg = ('[sl-crime] cooldown %s/%s efface'):format(kind, target)
  if source == 0 then
    print(msg)
  else
    TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'success' })
  end
end, false)

RegisterCommand('crime:clearallcooldowns', function(source, args)
  if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'sl.admin') then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Permission refusee.', type = 'error' })
    end
    return
  end
  SL:DB().update('DELETE FROM sl_crime_cooldowns WHERE until_ts <= ?', { math.floor(os.time()) + 99999999 })
  local msg = '[sl-crime] tous les cooldowns effaces'
  if source == 0 then print(msg) else
    TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'success' })
  end
end, false)

RegisterCommand('crime:giveseed', function(source, args)
  if source ~= 0 and not IsPlayerAceAllowed(tostring(source), 'sl.admin') then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Permission refusee.', type = 'error' })
    end
    return
  end
  local target = tonumber(args[1]) or source
  local count  = tonumber(args[2]) or 1
  if target == 0 then
    print('[sl-crime] usage: /crime:giveseed <src> [count]'); return
  end
  pcall(function()
    exports['sl-inventory']:AddItem(target, 'weed_seed', count, nil, 'admin_give')
  end)
  TriggerClientEvent('ox_lib:notify', target, {
    description = ('Vous avez recu %d weed_seed (admin)'):format(count),
    type = 'success'
  })
end, false)
