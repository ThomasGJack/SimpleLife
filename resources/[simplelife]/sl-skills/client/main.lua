print('[sl-skills/client] main.lua loaded')

-- ===========================================================================
-- Cache local : { skill -> { xp, level } }
-- ===========================================================================
local localSkills = {}

-- ===========================================================================
-- Reception du bus (sync complet + levelUp)
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:skills:sync' then
    if not payload or not payload.skills then return end
    localSkills = payload.skills
    -- Peut etre utilise par le HUD ou la phone-app via exports client
    -- On ne pousse pas de NUI depuis ce module (pas d overlay ddie)

  elseif event == 'sl:skills:levelUp' then
    if not payload then return end
    local skill = payload.skill
    local level = payload.level
    local label = (Skills.Labels and Skills.Labels[skill]) or skill

    -- Notification lib.notify (ox_lib cote client)
    lib.notify({
      title       = 'Competence amelioree !',
      description = ('[%s] Niveau %d'):format(label, level),
      type        = 'success',
      duration    = 5000,
    })
  end
end)

-- ===========================================================================
-- Fetch initial au characterSelected
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  CreateThread(function()
    Wait(800)
    local result = lib.callback.await('sl-skills:getMine', false)
    if result then
      localSkills = result
    end
  end)
end)

-- ===========================================================================
-- Exports client (pour lecture par d autres modules, ex sl-hud)
-- ===========================================================================
exports('GetAll', function()
  return localSkills
end)

exports('GetLevel', function(skill)
  local entry = localSkills[skill]
  if not entry then return 0 end
  return entry.level or 0
end)

exports('GetXP', function(skill)
  local entry = localSkills[skill]
  if not entry then return 0 end
  return entry.xp or 0
end)
