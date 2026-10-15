print('[sl-gangs/server] api.lua loaded')

local SL = exports['sl-core']
local function db() return SL:DB() end

-- ===========================================================================
-- Helpers internes
-- ===========================================================================

local function getEntry(source)
  local c = Cache[source]
  if not c then return nil, 'gang not loaded' end
  return c
end

local function notify(source, description, ntype)
  TriggerClientEvent('ox_lib:notify', source, { description = description, type = ntype or 'inform' })
end

-- Grade minimum pour qu'une action soit autorisee
local function canDo(grade, action)
  local def = Gangs.Grades[grade or 0]
  if not def then return false end
  return def[action] == true
end

-- ===========================================================================
-- Creer un gang
-- ===========================================================================
function CreateGang(name, bossCitizenId, color)
  if not name or name == '' then return false, 'nom invalide' end
  color = color or 'red'
  -- Verif unicite
  local exists = db().scalar('SELECT COUNT(*) FROM sl_gangs WHERE name = ?', { name })
  if (exists or 0) > 0 then return false, 'gang deja existant' end
  local id = db().insert(
    'INSERT INTO sl_gangs (name, color, boss_citizen_id) VALUES (?, ?, ?)',
    { name, color, bossCitizenId or '' })
  if not id then return false, 'erreur DB' end
  print(('[sl-gangs] gang created: %s (id=%s)'):format(name, tostring(id)))
  return true, id
end

-- ===========================================================================
-- Recruter un membre (inviter)
-- ===========================================================================
function InviteMember(source, targetSource)
  local entry, err = getEntry(source)
  if not entry then return false, err end
  if not entry.gangId then return false, 'pas dans un gang' end
  if not canDo(entry.grade, 'canInvite') then return false, 'grade insuffisant' end

  local targetEntry = Cache[targetSource]
  if not targetEntry then return false, 'cible non connectee' end
  if targetEntry.gangId then return false, 'cible deja dans un gang' end

  -- Insere le membre avec grade 0 (recrue)
  local existing = db().scalar(
    'SELECT COUNT(*) FROM sl_gang_members WHERE character_id = ?',
    { targetEntry.characterId })
  if (existing or 0) > 0 then return false, 'cible deja dans un gang (DB)' end

  db().insert(
    'INSERT INTO sl_gang_members (gang_id, character_id, grade) VALUES (?, ?, 0)',
    { entry.gangId, targetEntry.characterId })

  RefreshMember(targetSource)

  -- Events bus
  TriggerEvent('sl:gangs:memberChanged', {
    source = targetSource,
    gang   = entry.gangName,
    grade  = 0,
  })
  TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:memberChanged', {
    source = targetSource,
    gang   = entry.gangName,
    grade  = 0,
  })

  notify(targetSource, ('Vous avez rejoint le gang %s.'):format(entry.gangName), 'success')
  notify(source, ('Invitation envoyee a %s.'):format(GetPlayerName(targetSource)), 'success')
  return true
end

-- ===========================================================================
-- Exclure un membre
-- ===========================================================================
function KickMember(source, targetSource)
  local entry, err = getEntry(source)
  if not entry then return false, err end
  if not entry.gangId then return false, 'pas dans un gang' end
  if not canDo(entry.grade, 'canKick') then return false, 'grade insuffisant' end

  local targetEntry = Cache[targetSource]
  if not targetEntry then return false, 'cible non connectee' end
  if targetEntry.gangId ~= entry.gangId then return false, 'cible dans un autre gang' end
  if targetEntry.grade and targetEntry.grade >= entry.grade then
    return false, 'impossible d exclure un membre de grade egal ou superieur'
  end

  db().update(
    'DELETE FROM sl_gang_members WHERE character_id = ? AND gang_id = ?',
    { targetEntry.characterId, entry.gangId })

  local oldGang = targetEntry.gangName
  RefreshMember(targetSource)

  TriggerEvent('sl:gangs:memberChanged', { source = targetSource, gang = nil, grade = nil })
  TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:memberChanged',
    { source = targetSource, gang = nil, grade = nil })

  notify(targetSource, ('Vous avez ete exclu du gang %s.'):format(oldGang), 'error')
  notify(source, 'Membre exclu du gang.', 'success')
  return true
end

-- ===========================================================================
-- Promouvoir / retrograder
-- ===========================================================================
function PromoteMember(source, targetSource, delta)
  local entry, err = getEntry(source)
  if not entry then return false, err end
  if not entry.gangId then return false, 'pas dans un gang' end
  if not canDo(entry.grade, 'canPromote') then return false, 'grade insuffisant' end

  local targetEntry = Cache[targetSource]
  if not targetEntry then return false, 'cible non connectee' end
  if targetEntry.gangId ~= entry.gangId then return false, 'cible dans un autre gang' end

  local newGrade = (targetEntry.grade or 0) + (delta or 1)
  -- On ne peut pas promouvoir au-dessus de son propre grade - 1
  if newGrade >= entry.grade then return false, 'impossible de promouvoir a votre niveau ou au-dessus' end
  if newGrade < 0 then newGrade = 0 end
  if newGrade > Gangs.MaxGrade then newGrade = Gangs.MaxGrade end

  db().update(
    'UPDATE sl_gang_members SET grade = ? WHERE character_id = ? AND gang_id = ?',
    { newGrade, targetEntry.characterId, entry.gangId })

  RefreshMember(targetSource)

  TriggerEvent('sl:gangs:memberChanged', {
    source = targetSource, gang = entry.gangName, grade = newGrade })
  TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:memberChanged',
    { source = targetSource, gang = entry.gangName, grade = newGrade })

  local action = delta and delta > 0 and 'promu' or 'retrograde'
  local gradeLabel = (Gangs.Grades[newGrade] or {}).label or tostring(newGrade)
  notify(targetSource, ('Vous avez ete %s : %s.'):format(action, gradeLabel), 'success')
  notify(source, ('Membre %s au grade %s.'):format(action, gradeLabel), 'success')
  return true
end

-- ===========================================================================
-- Quitter le gang
-- ===========================================================================
function LeaveGang(source)
  local entry, err = getEntry(source)
  if not entry then return false, err end
  if not entry.gangId then return false, 'pas dans un gang' end
  -- Le boss ne peut pas partir (doit transmettre d abord)
  if entry.grade == Gangs.BossGrade then
    return false, 'le boss doit d abord transmettre le gang'
  end

  db().update(
    'DELETE FROM sl_gang_members WHERE character_id = ? AND gang_id = ?',
    { entry.characterId, entry.gangId })

  local oldGang = entry.gangName
  RefreshMember(source)

  TriggerEvent('sl:gangs:memberChanged', { source = source, gang = nil, grade = nil })
  TriggerClientEvent('sl:bus:dispatch', -1, 'sl:gangs:memberChanged',
    { source = source, gang = nil, grade = nil })

  notify(source, ('Vous avez quitte le gang %s.'):format(oldGang), 'inform')
  return true
end

-- ===========================================================================
-- Dissoudre un gang (admin)
-- ===========================================================================
function DissolveGang(gangId)
  -- ON DELETE CASCADE sur sl_gang_members -> tous les membres supprimes aussi
  local aff = db().update('DELETE FROM sl_gangs WHERE id = ?', { gangId })
  -- Reset des territoires de ce gang
  db().update(
    'UPDATE sl_gang_territories SET gang_id = NULL, influence = 0 WHERE gang_id = ?',
    { gangId })
  -- Recharge les territoires en memoire
  for _, t in pairs(Territories) do
    if t.gang_id == gangId then
      t.gang_id    = nil
      t.gang_name  = nil
      t.gang_color = nil
      t.influence  = 0
    end
  end
  -- Rafraichir les membres connectes
  for src, entry in pairs(Cache) do
    if entry.gangId == gangId then
      RefreshMember(src)
      notify(src, 'Votre gang a ete dissous.', 'error')
    end
  end
  return aff and aff > 0
end

-- ===========================================================================
-- Exports publics (signatures contrat INTEGRATION.md)
-- ===========================================================================

-- GetGang(src) -> { name, grade } | nil
exports('GetGang', function(source)
  local entry = Cache[source]
  if not entry or not entry.gangId then return nil end
  return { name = entry.gangName, grade = entry.grade }
end)

-- IsInGang(src, gangName) -> bool
exports('IsInGang', function(source, gangName)
  local entry = Cache[source]
  if not entry or not entry.gangId then return false end
  return entry.gangName == gangName
end)

-- GetTerritoryOwner(zone) -> gangName | nil
exports('GetTerritoryOwner', function(zone)
  local t = Territories[zone]
  if not t then return nil end
  return t.gang_name
end)

-- ===========================================================================
-- Callback lib pour la NUI / client
-- ===========================================================================

-- Retourne les infos du gang du joueur + liste membres connectes
lib.callback.register('sl-gangs:getMyGang', function(source)
  local entry = Cache[source]
  if not entry or not entry.gangId then return nil end

  -- Le nom du perso vit dans la colonne JSON data (data.identity.firstName/lastName),
  -- il n'existe PAS de colonnes firstname/lastname dans sl_characters.
  local members = SL:DB().query(
    'SELECT gm.grade, c.citizen_id,'
    .. " JSON_UNQUOTE(JSON_EXTRACT(c.data, '$.identity.firstName')) AS firstname,"
    .. " JSON_UNQUOTE(JSON_EXTRACT(c.data, '$.identity.lastName'))  AS lastname"
    .. ' FROM sl_gang_members gm'
    .. ' INNER JOIN sl_characters c ON c.id = gm.character_id'
    .. ' WHERE gm.gang_id = ?',
    { entry.gangId })

  return {
    name    = entry.gangName,
    color   = entry.gangColor,
    grade   = entry.grade,
    members = members or {},
  }
end)

-- Retourne les territoires
lib.callback.register('sl-gangs:getTerritories', function(_source)
  local list = {}
  for _, t in pairs(Territories) do
    list[#list + 1] = {
      zone      = t.zone,
      gang_name = t.gang_name,
      gang_color= t.gang_color,
      influence = t.influence,
    }
  end
  return list
end)

-- Liste tous les gangs (admin)
lib.callback.register('sl-gangs:adminList', function(source)
  if not IsPlayerAceAllowed(tostring(source), 'sl.admin') and tonumber(source) ~= 0 then
    return nil
  end
  return SL:DB().query(
    'SELECT g.id, g.name, g.color, g.boss_citizen_id,'
    .. ' (SELECT COUNT(*) FROM sl_gang_members gm WHERE gm.gang_id = g.id) AS member_count'
    .. ' FROM sl_gangs g ORDER BY g.name', {})
end)
