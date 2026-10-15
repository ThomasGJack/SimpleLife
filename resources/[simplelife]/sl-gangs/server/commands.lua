print('[sl-gangs/server] commands.lua loaded')

local SL = exports['sl-core']

local function notify(source, description, ntype)
  TriggerClientEvent('ox_lib:notify', source, { description = description, type = ntype or 'inform' })
end

local function isAdmin(source)
  return IsPlayerAceAllowed(tostring(source), 'sl.admin') or tonumber(source) == 0
end

-- Trouve un joueur connecte par server ID
local function findOnline(serverId)
  local src = tonumber(serverId)
  if not src then return nil end
  -- Verifie que la source existe dans le Cache
  if Cache[src] then return src end
  return nil
end

-- ===========================================================================
-- /gang       — affiche son propre gang
-- ===========================================================================
RegisterCommand('gang', function(source, _args, _raw)
  local entry = Cache[source]
  if not entry or not entry.gangId then
    notify(source, 'Vous n apparttenez a aucun gang.', 'error')
    return
  end
  local gradeLabel = (Gangs.Grades[entry.grade or 0] or {}).label or tostring(entry.grade)
  notify(source,
    ('Gang : %s | Grade : %s (%d)'):format(entry.gangName, gradeLabel, entry.grade or 0),
    'inform')
end, false)

-- ===========================================================================
-- /gangleave  — quitter son gang
-- ===========================================================================
RegisterCommand('gangleave', function(source, _args, _raw)
  local ok, err = LeaveGang(source)
  if not ok then
    notify(source, 'Erreur : ' .. (err or 'inconnue'), 'error')
  end
end, false)

-- ===========================================================================
-- /ganginvite <serverId>  — inviter un joueur (grade >= Officier)
-- ===========================================================================
RegisterCommand('ganginvite', function(source, args, _raw)
  local targetSrc = findOnline(args[1])
  if not targetSrc then
    notify(source, 'Joueur introuvable ou non connecte.', 'error')
    return
  end
  if targetSrc == source then
    notify(source, 'Vous ne pouvez pas vous inviter vous-meme.', 'error')
    return
  end
  local ok, err = InviteMember(source, targetSrc)
  if not ok then
    notify(source, 'Erreur : ' .. (err or 'inconnue'), 'error')
  end
end, false)

-- ===========================================================================
-- /gangkick <serverId>  — exclure un membre
-- ===========================================================================
RegisterCommand('gangkick', function(source, args, _raw)
  local targetSrc = findOnline(args[1])
  if not targetSrc then
    notify(source, 'Joueur introuvable ou non connecte.', 'error')
    return
  end
  if targetSrc == source then
    notify(source, 'Utilisez /gangleave pour quitter.', 'error')
    return
  end
  local ok, err = KickMember(source, targetSrc)
  if not ok then
    notify(source, 'Erreur : ' .. (err or 'inconnue'), 'error')
  end
end, false)

-- ===========================================================================
-- /gangpromote <serverId> [delta]  — promouvoir (+1) ou retrograder (-1)
-- delta optionnel : +1 par defaut, -1 pour retrograder
-- ===========================================================================
RegisterCommand('gangpromote', function(source, args, _raw)
  local targetSrc = findOnline(args[1])
  if not targetSrc then
    notify(source, 'Joueur introuvable ou non connecte.', 'error')
    return
  end
  local delta = tonumber(args[2]) or 1
  if delta == 0 then delta = 1 end
  -- Clamp entre -1 et 1 pour eviter les sauts brutaux
  if delta > 1 then delta = 1 end
  if delta < -1 then delta = -1 end

  local ok, err = PromoteMember(source, targetSrc, delta)
  if not ok then
    notify(source, 'Erreur : ' .. (err or 'inconnue'), 'error')
  end
end, false)

-- ===========================================================================
-- /gangdemote <serverId>  — retrograder d un grade
-- ===========================================================================
RegisterCommand('gangdemote', function(source, args, _raw)
  local targetSrc = findOnline(args[1])
  if not targetSrc then
    notify(source, 'Joueur introuvable ou non connecte.', 'error')
    return
  end
  local ok, err = PromoteMember(source, targetSrc, -1)
  if not ok then
    notify(source, 'Erreur : ' .. (err or 'inconnue'), 'error')
  end
end, false)

-- ===========================================================================
-- /creategang <name> <bossServerId> [color]  — admin only
-- ===========================================================================
RegisterCommand('creategang', function(source, args, _raw)
  if not isAdmin(source) then
    notify(source, 'Permission refusee.', 'error')
    return
  end
  local name       = args[1]
  local bossSrc    = findOnline(args[2])
  local color      = args[3] or 'red'

  if not name then
    notify(source, 'Usage : /creategang <nom> <serverId> [couleur]', 'error')
    return
  end
  if not bossSrc then
    notify(source, 'Boss introuvable ou non connecte.', 'error')
    return
  end

  local bossEntry = Cache[bossSrc]
  if not bossEntry then
    notify(source, 'Boss non hydrate.', 'error')
    return
  end
  if bossEntry.gangId then
    notify(source, 'Ce joueur est deja dans un gang.', 'error')
    return
  end

  local ok, idOrErr = CreateGang(name, bossEntry.citizenId, color)
  if not ok then
    notify(source, 'Erreur : ' .. (idOrErr or 'inconnue'), 'error')
    return
  end

  local gangId = idOrErr
  -- Insere le boss en grade 4
  SL:DB().insert(
    'INSERT INTO sl_gang_members (gang_id, character_id, grade) VALUES (?, ?, ?)',
    { gangId, bossEntry.characterId, Gangs.BossGrade })

  RefreshMember(bossSrc)

  TriggerEvent('sl:gangs:memberChanged', {
    source = bossSrc, gang = name, grade = Gangs.BossGrade })
  TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:memberChanged',
    { source = bossSrc, gang = name, grade = Gangs.BossGrade })

  notify(bossSrc, ('Vous etes maintenant le boss du gang %s.'):format(name), 'success')
  if source ~= 0 then
    notify(source, ('Gang "%s" cree avec succes (id=%s).'):format(name, tostring(gangId)), 'success')
  else
    print(('[sl-gangs] creategang "%s" id=%s boss_src=%d'):format(name, tostring(gangId), bossSrc))
  end
end, false)

-- ===========================================================================
-- /gangs      — admin : liste tous les gangs
-- ===========================================================================
RegisterCommand('gangs', function(source, _args, _raw)
  if not isAdmin(source) then
    notify(source, 'Permission refusee.', 'error')
    return
  end

  local rows = SL:DB().query(
    'SELECT g.id, g.name, g.color,'
    .. ' (SELECT COUNT(*) FROM sl_gang_members gm WHERE gm.gang_id = g.id) AS member_count'
    .. ' FROM sl_gangs g ORDER BY g.name', {})

  if not rows or #rows == 0 then
    notify(source, 'Aucun gang enregistre.', 'inform')
    return
  end

  if source == 0 then
    for _, row in ipairs(rows) do
      print(('[sl-gangs] id=%s name=%s color=%s members=%s'):format(
        tostring(row.id), row.name, row.color, tostring(row.member_count)))
    end
  else
    local lines = {}
    for _, row in ipairs(rows) do
      lines[#lines + 1] = ('[%s] %s (%s) — %d membres'):format(
        tostring(row.id), row.name, row.color, tonumber(row.member_count) or 0)
    end
    notify(source, table.concat(lines, '\n'), 'inform')
  end
end, false)

-- ===========================================================================
-- /dissolvgang <id>  — admin : supprimer un gang
-- ===========================================================================
RegisterCommand('dissolvegang', function(source, args, _raw)
  if not isAdmin(source) then
    notify(source, 'Permission refusee.', 'error')
    return
  end
  local gangId = tonumber(args[1])
  if not gangId then
    notify(source, 'Usage : /dissolvegang <id>', 'error')
    return
  end
  local ok = DissolveGang(gangId)
  if ok then
    if source ~= 0 then
      notify(source, ('Gang #%d dissous.'):format(gangId), 'success')
    else
      print(('[sl-gangs] gang #%d dissolved'):format(gangId))
    end
  else
    notify(source, 'Gang introuvable.', 'error')
  end
end, false)

-- ===========================================================================
-- /gangsetcolor <gangId> <color>  — admin : changer la couleur d un gang
-- ===========================================================================
RegisterCommand('gangsetcolor', function(source, args, _raw)
  if not isAdmin(source) then
    notify(source, 'Permission refusee.', 'error')
    return
  end
  local gangId = tonumber(args[1])
  local color  = args[2]
  if not gangId or not color then
    notify(source, 'Usage : /gangsetcolor <id> <color>', 'error')
    return
  end
  local aff = SL:DB().update('UPDATE sl_gangs SET color = ? WHERE id = ?', { color, gangId })
  if aff and aff > 0 then
    -- Rafraichit les membres en cache
    for src, entry in pairs(Cache) do
      if entry.gangId == gangId then
        entry.gangColor = color
        TriggerClientEvent('sl:bus:dispatch', src, 'sl:gangs:hydrate', {
          gangName  = entry.gangName,
          gangColor = entry.gangColor,
          grade     = entry.grade,
        })
      end
    end
    -- Rafraichit les territoires en memoire
    for _, t in pairs(Territories) do
      if t.gang_id == gangId then t.gang_color = color end
    end
    notify(source, ('Couleur du gang #%d mise a jour : %s'):format(gangId, color), 'success')
  else
    notify(source, 'Gang introuvable.', 'error')
  end
end, false)
