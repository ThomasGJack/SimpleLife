print('[sl-jobs/client] main.lua loaded')

ClientJob = ClientJob or { name = 'unemployed', grade = 0, onDuty = false, label = '—', gradeLabel = '—' }

local function notify(payload)
  lib.notify(payload)
end

AddEventHandler('sl:jobs:hydrated', function(payload)
  if not payload then return end
  ClientJob = {
    name = payload.name,
    grade = payload.grade,
    onDuty = payload.onDuty,
    label = payload.label or payload.name,
    gradeLabel = payload.gradeLabel or '?',
  }
end)

AddEventHandler('sl:jobs:jobChanged', function(payload)
  if not payload then return end
  ClientJob = {
    name = payload.name,
    grade = payload.grade,
    onDuty = payload.onDuty,
    label = payload.label or payload.name,
    gradeLabel = payload.gradeLabel or '?',
  }
  notify({
    type = 'inform',
    title = 'Métier mis à jour',
    description = ('%s — %s'):format(ClientJob.label, ClientJob.gradeLabel),
    duration = 5000,
  })
end)

AddEventHandler('sl:jobs:dutyChanged', function(payload)
  if not payload then return end
  ClientJob.onDuty = payload.onDuty
  notify({
    type = payload.onDuty and 'success' or 'inform',
    title = 'Service',
    description = payload.onDuty and 'Tu es maintenant EN SERVICE' or 'Tu es maintenant HORS SERVICE',
    duration = 4000,
  })
end)

AddEventHandler('sl:jobs:paycheck', function(payload)
  if not payload then return end
  notify({
    type = 'success',
    title = 'Paie',
    description = ('+%d $ — %s (%s)'):format(payload.amount, payload.jobLabel, payload.gradeLabel),
    duration = 6000,
  })
end)

exports('GetClientJob', function() return ClientJob end)

RegisterCommand('duty', function()
  local res = lib.callback.await('sl-jobs:setDuty', false, not ClientJob.onDuty)
  if not res or not res.ok then
    notify({ type = 'error', title = 'Service', description = 'Action refusée' })
  end
end, false)

RegisterCommand('job', function()
  notify({
    type = 'inform',
    title = ClientJob.label,
    description = ('Grade : %s\nService : %s'):format(
      ClientJob.gradeLabel,
      ClientJob.onDuty and 'EN SERVICE' or 'HORS SERVICE'
    ),
    duration = 6000,
  })
end, false)

RegisterCommand('joinjob', function(_, args)
  local jobName = args[1]
  if not jobName then
    local list = lib.callback.await('sl-jobs:publicList', false)
    local labels = {}
    for _, j in ipairs(list or {}) do table.insert(labels, j.name .. ' (' .. j.label .. ')') end
    notify({
      type = 'inform',
      title = 'Métiers publics',
      description = table.concat(labels, '\n'),
      duration = 10000,
    })
    return
  end
  local res = lib.callback.await('sl-jobs:apply', false, jobName)
  if not res or not res.ok then
    notify({ type = 'error', title = 'Candidature refusée', description = res and res.error or 'unknown' })
  end
end, false)

-- Keymap centralisé dans sl-keybinds (catégorie "SimpleLife" dans Settings, touche B)
