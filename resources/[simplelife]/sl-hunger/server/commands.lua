print('[sl-hunger/server] commands.lua loaded')

local function isAdmin(source)
  if source == 0 then return true end
  return IsPlayerAceAllowed(source, 'command.sl') or IsPlayerAceAllowed(source, 'sl.admin')
end

local function notify(src, msg, type_)
  if src == 0 then print('[sl-hunger] ' .. msg); return end
  TriggerClientEvent('ox_lib:notify', src, { description = msg, type = type_ or 'inform' })
end

-- /hunger : affiche ses stats
RegisterCommand('hunger', function(source)
  local s = GetStats(source)
  if not s then notify(source, 'Stats non chargées.', 'error'); return end
  notify(source, ('🍖 Faim : %d  ·  💧 Soif : %d'):format(s.hunger, s.thirst), 'inform')
end, false)

-- /sethunger <id> <value> : admin
RegisterCommand('sethunger', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1])
  local value  = tonumber(args[2])
  if not target or not value then
    notify(source, 'Usage : /sethunger <id> <0-100>', 'error'); return
  end
  local ok = HungerSet(target, value)
  if ok then notify(source, ('Faim de %d → %d'):format(target, value), 'success')
  else notify(source, 'Échec (joueur pas chargé)', 'error') end
end, false)

-- /setthirst <id> <value> : admin
RegisterCommand('setthirst', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1])
  local value  = tonumber(args[2])
  if not target or not value then
    notify(source, 'Usage : /setthirst <id> <0-100>', 'error'); return
  end
  local ok = ThirstSet(target, value)
  if ok then notify(source, ('Soif de %d → %d'):format(target, value), 'success')
  else notify(source, 'Échec (joueur pas chargé)', 'error') end
end, false)

-- /refill <id?> : remet faim+soif à 100 (admin)
RegisterCommand('refill', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1]) or source
  RefillAll(target)
  notify(source, ('Faim/Soif de %d → 100'):format(target), 'success')
end, false)

-- /starve <id?> : met faim+soif à 0 (debug / pour tester les dégâts)
RegisterCommand('starve', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1]) or source
  HungerSet(target, 0); ThirstSet(target, 0)
  notify(source, ('%d → famine totale'):format(target), 'inform')
end, false)
