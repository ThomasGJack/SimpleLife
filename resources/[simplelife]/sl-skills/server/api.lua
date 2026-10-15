print('[sl-skills/server] api.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Helpers internes
-- ===========================================================================

local function isValidSkill(skill)
  for _, s in ipairs(Skills.List) do
    if s == skill then return true end
  end
  return false
end

local function clampXP(xp)
  if xp < 0 then return 0 end
  if xp > Skills.MaxXP then return Skills.MaxXP end
  return xp
end

-- ===========================================================================
-- AddXP(src, skill, amount) -> nouveau xp, nouveau level
--   Emet 'sl:skills:levelUp' si le niveau change.
--   Persiste immediatement sur changement (dirty + tick de sauvegarde).
-- ===========================================================================
function AddXP(source, skill, amount)
  if not source or not skill or not amount then return nil, 'invalid args' end
  if not isValidSkill(skill) then return nil, 'unknown skill: ' .. tostring(skill) end

  local entry = Cache[source]
  if not entry then return nil, 'player not loaded' end

  local oldXP   = entry.skills[skill] or 0
  local oldLevel = Skills.XpToLevel(oldXP)

  local newXP   = clampXP(oldXP + math.floor(amount))
  local newLevel = Skills.XpToLevel(newXP)

  entry.skills[skill] = newXP
  entry.dirty = true

  -- Notif level up si le niveau a change
  if newLevel ~= oldLevel then
    local label = Skills.Labels[skill] or skill

    -- Event bus serveur (cross-resource)
    TriggerEvent('sl:skills:levelUp', {
      source = source,
      skill  = skill,
      level  = newLevel,
    })

    -- Dispatch client
    TriggerClientEvent('sl:bus:dispatch', source, 'sl:skills:levelUp', {
      skill  = skill,
      level  = newLevel,
      xp     = newXP,
    })

    -- Notification ox_lib
    TriggerClientEvent('ox_lib:notify', source, {
      title       = 'Competence amelioree !',
      description = ('[%s] Niveau %d'):format(label, newLevel),
      type        = 'success',
      duration    = 5000,
    })

    print(('[sl-skills] levelUp src=%d skill=%s lvl=%d->%d xp=%d'):format(
      source, skill, oldLevel, newLevel, newXP))
  end

  -- Sync client (table complete)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:skills:sync', { skills = BuildPublicTable(source) })

  return newXP, newLevel
end

-- ===========================================================================
-- GetXP(src, skill) -> xp (number)
-- ===========================================================================
function GetXP(source, skill)
  if not isValidSkill(skill) then return 0 end
  local entry = Cache[source]
  if not entry then return 0 end
  return entry.skills[skill] or 0
end

-- ===========================================================================
-- GetLevel(src, skill) -> level (number)
-- ===========================================================================
function GetLevel(source, skill)
  return Skills.XpToLevel(GetXP(source, skill))
end

-- ===========================================================================
-- GetAll(src) -> table { skill -> { xp, level } }
-- ===========================================================================
function GetAll(source)
  return BuildPublicTable(source)
end

-- ===========================================================================
-- Exports cross-resource
-- ===========================================================================
exports('AddXP',   AddXP)
exports('GetXP',   GetXP)
exports('GetLevel', GetLevel)
exports('GetAll',   GetAll)

-- ===========================================================================
-- Callback ox_lib : utilise par sl-phone app skills
-- ===========================================================================
lib.callback.register('sl-skills:getMine', function(source)
  return GetAll(source)
end)

-- ===========================================================================
-- Listeners bus inter-modules
-- Exemple : sl-ems emet 'sl:ems:revivedTarget' -> le medecin gagne de l XP medical
-- ===========================================================================

AddEventHandler('sl:ems:revivedTarget', function(payload)
  if not payload or not payload.medic then return end
  AddXP(payload.medic, 'medical', 80)
end)
