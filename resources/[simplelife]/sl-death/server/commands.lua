print('[sl-death/server] commands.lua loaded')

-- ============================================================
-- /revive [id]  : revive soi ou la cible (admin)
-- ============================================================
RegisterCommand('revive', function(source, args)
  -- Autorisations : ace sl.admin OU console (source==0)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Acces refuse.',
        type        = 'error',
      })
    end
    return
  end

  local target = tonumber(args[1])
  if not target then
    -- Pas de cible : revive soi-meme (seulement si pas console)
    if source == 0 then
      print('[sl-death/commands] /revive : specifiez un ID joueur.')
      return
    end
    target = source
  end

  -- Verifier que le joueur cible existe
  if not GetPlayerName(tostring(target)) then
    local msg = 'Joueur introuvable : ' .. tostring(target)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
    return
  end

  local ok, err = exports['sl-death']:Revive(target)
  if ok then
    local msg = ('Joueur %d revive avec succes.'):format(target)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'success' }) end
    -- Notif cible si different de soi
    if target ~= source then
      TriggerClientEvent('ox_lib:notify', target, {
        description = 'Un admin vous a revive.',
        type        = 'success',
      })
    end
  else
    local msg = 'Erreur revive : ' .. tostring(err)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
  end
end, false)

-- ============================================================
-- /respawn [id]  : force respawn hopital (admin)
-- ============================================================
RegisterCommand('respawn', function(source, args)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Acces refuse.',
        type        = 'error',
      })
    end
    return
  end

  local target = tonumber(args[1])
  if not target then
    if source == 0 then
      print('[sl-death/commands] /respawn : specifiez un ID joueur.')
      return
    end
    target = source
  end

  if not GetPlayerName(tostring(target)) then
    local msg = 'Joueur introuvable : ' .. tostring(target)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
    return
  end

  exports['sl-death']:Respawn(target)

  local msg = ('Joueur %d envoye a l hopital.'):format(target)
  if source == 0 then print('[sl-death/commands] ' .. msg)
  else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'success' }) end
end, false)

-- ============================================================
-- /setbleed [id] [level 0-3]  : set le niveau de saignement (admin)
-- ============================================================
RegisterCommand('setbleed', function(source, args)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'sl.admin') then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Acces refuse.',
        type        = 'error',
      })
    end
    return
  end

  local target = tonumber(args[1])
  local level  = tonumber(args[2])

  if not target or not level then
    local msg = 'Usage : /setbleed <id> <level 0-3>'
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
    return
  end

  if not GetPlayerName(tostring(target)) then
    local msg = 'Joueur introuvable : ' .. tostring(target)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
    return
  end

  local ok, err = exports['sl-death']:SetBleed(target, level)
  if ok then
    local msg = ('Joueur %d bleed level=%d.'):format(target, level)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'success' }) end
    TriggerClientEvent('ox_lib:notify', target, {
      description = ('Niveau de saignement modifie : %d'):format(level),
      type        = 'inform',
    })
  else
    local msg = 'Erreur setbleed : ' .. tostring(err)
    if source == 0 then print('[sl-death/commands] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', source, { description = msg, type = 'error' }) end
  end
end, false)
