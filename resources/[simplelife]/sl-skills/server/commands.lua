print('[sl-skills/server] commands.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- /skills : affiche les competences du joueur (self)
--   Usage : /skills
-- ===========================================================================
RegisterCommand('skills', function(source, args, rawCmd)
  if source == 0 then
    -- Console serveur : affiche tous les joueurs
    print('[sl-skills] Cache actuel :')
    for src, entry in pairs(Cache) do
      print(('  src=%d cid=%d'):format(src, entry.characterId))
      for _, skill in ipairs(Skills.List) do
        local xp = entry.skills[skill] or 0
        local lv = Skills.XpToLevel(xp)
        print(('    %s : xp=%d level=%d'):format(skill, xp, lv))
      end
    end
    return
  end

  local entry = Cache[source]
  if not entry then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Aucune donnee de competences chargee.',
      type        = 'error',
    })
    return
  end

  -- Construit un message lisible pour la notification
  local lines = {}
  for _, skill in ipairs(Skills.List) do
    local xp = entry.skills[skill] or 0
    local lv = Skills.XpToLevel(xp)
    local label = Skills.Labels[skill] or skill
    table.insert(lines, ('%s : Niv.%d (%d XP)'):format(label, lv, xp))
  end

  local msg = table.concat(lines, '\n')

  TriggerClientEvent('ox_lib:notify', source, {
    title       = 'Mes competences',
    description = msg,
    type        = 'inform',
    duration    = 10000,
  })
end, false)

-- ===========================================================================
-- /addxp <target_id> <skill> <amount> : admin uniquement
--   Usage : /addxp 1 driving 500
-- ===========================================================================
RegisterCommand('addxp', function(source, args, rawCmd)
  -- Verification admin
  local isAdmin = (source == 0) or IsPlayerAceAllowed(tostring(source), 'sl.admin')
  if not isAdmin then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Acces refuse.',
        type        = 'error',
      })
    end
    return
  end

  local targetSrc = tonumber(args[1])
  local skill     = args[2]
  local amount    = tonumber(args[3])

  if not targetSrc or not skill or not amount then
    local usage = 'Usage : /addxp <player_id> <skill> <amount>'
    if source == 0 then
      print(usage)
    else
      TriggerClientEvent('ox_lib:notify', source, { description = usage, type = 'error' })
    end
    return
  end

  -- Verifie que le joueur cible est en cache
  if not Cache[targetSrc] then
    local err = ('Joueur %d non charge (pas connecte ou pas de personnage).'):format(targetSrc)
    if source == 0 then
      print('[sl-skills] ' .. err)
    else
      TriggerClientEvent('ox_lib:notify', source, { description = err, type = 'error' })
    end
    return
  end

  local newXP, newLevel = AddXP(targetSrc, skill, amount)

  if not newXP then
    local err = 'Competence inconnue : ' .. tostring(skill)
    if source == 0 then
      print('[sl-skills] ' .. err)
    else
      TriggerClientEvent('ox_lib:notify', source, { description = err, type = 'error' })
    end
    return
  end

  local label = Skills.Labels[skill] or skill
  local msg = ('[%s] +%d XP -> %d XP (Niv. %d) pour le joueur %d'):format(
    label, amount, newXP, newLevel, targetSrc)

  if source == 0 then
    print('[sl-skills] ' .. msg)
  else
    TriggerClientEvent('ox_lib:notify', source, {
      title       = 'XP ajoute',
      description = msg,
      type        = 'success',
    })
  end
end, false)

-- ===========================================================================
-- /setxp <target_id> <skill> <xp> : admin uniquement
--   Usage : /setxp 1 driving 1000
-- ===========================================================================
RegisterCommand('setxp', function(source, args, rawCmd)
  local isAdmin = (source == 0) or IsPlayerAceAllowed(tostring(source), 'sl.admin')
  if not isAdmin then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Acces refuse.',
        type        = 'error',
      })
    end
    return
  end

  local targetSrc = tonumber(args[1])
  local skill     = args[2]
  local xpTarget  = tonumber(args[3])

  if not targetSrc or not skill or not xpTarget then
    local usage = 'Usage : /setxp <player_id> <skill> <xp>'
    if source == 0 then print(usage)
    else TriggerClientEvent('ox_lib:notify', source, { description = usage, type = 'error' }) end
    return
  end

  local entry = Cache[targetSrc]
  if not entry then
    local err = ('Joueur %d non charge.'):format(targetSrc)
    if source == 0 then print('[sl-skills] ' .. err)
    else TriggerClientEvent('ox_lib:notify', source, { description = err, type = 'error' }) end
    return
  end

  -- Valide le skill
  local valid = false
  for _, s in ipairs(Skills.List) do
    if s == skill then valid = true; break end
  end
  if not valid then
    local err = 'Competence inconnue : ' .. tostring(skill)
    if source == 0 then print('[sl-skills] ' .. err)
    else TriggerClientEvent('ox_lib:notify', source, { description = err, type = 'error' }) end
    return
  end

  -- On calcule la difference et on delegue a AddXP pour les side-effects (levelUp, notif, sync)
  local currentXP = entry.skills[skill] or 0
  local oldLevel  = Skills.XpToLevel(currentXP)
  -- Si la valeur cible est identique on ne fait rien
  if math.max(0, math.min(Skills.MaxXP, xpTarget)) == currentXP then return end

  -- On set directement pour pouvoir aller en dessous aussi
  entry.skills[skill] = math.max(0, math.min(Skills.MaxXP, xpTarget))
  entry.dirty = true

  local newLevel = Skills.XpToLevel(entry.skills[skill])
  local label    = Skills.Labels[skill] or skill

  -- N emet l event levelUp que si le niveau a reellement change (evite le bruit
  -- chez les consommateurs sl-hud / sl-phone qui reagissent au levelUp).
  if newLevel ~= oldLevel then
    TriggerEvent('sl:skills:levelUp', { source = targetSrc, skill = skill, level = newLevel })
    TriggerClientEvent('sl:bus:dispatch', targetSrc, 'sl:skills:levelUp', {
      skill = skill, level = newLevel, xp = entry.skills[skill],
    })
  end
  TriggerClientEvent('sl:bus:dispatch', targetSrc, 'sl:skills:sync', {
    skills = BuildPublicTable(targetSrc),
  })

  local msg = ('[%s] XP force a %d (Niv. %d) pour le joueur %d'):format(
    label, entry.skills[skill], newLevel, targetSrc)
  if source == 0 then print('[sl-skills] ' .. msg)
  else TriggerClientEvent('ox_lib:notify', source, { title = 'XP defini', description = msg, type = 'success' }) end
end, false)
