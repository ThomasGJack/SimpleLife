local SL = exports['sl-core']

local function reply(source, msg)
  if source == 0 then print(msg)
  else TriggerClientEvent('chat:addMessage', source, { args = { '[Job]', msg } }) end
end

RegisterCommand('setjob', function(source, args)
  local target = tonumber(args[1])
  local jobName = args[2]
  local gradeId = tonumber(args[3]) or 0
  if not target or not jobName then
    reply(source, 'usage: /setjob <src> <jobName> [grade]')
    return
  end
  if not Jobs.IsValid(jobName, gradeId) then
    reply(source, 'job/grade invalide. Jobs dispos: ' .. table.concat((function()
      local t = {}
      for n in pairs(Jobs.Catalog) do table.insert(t, n) end
      return t
    end)(), ', '))
    return
  end
  local ok, err = exports['sl-jobs']:SetJob(target, jobName, gradeId)
  if ok then
    reply(source, ('src=%d -> %s grade %d'):format(target, jobName, gradeId))
  else
    reply(source, 'echec: ' .. tostring(err))
  end
end, true)

RegisterCommand('setgrade', function(source, args)
  local target = tonumber(args[1])
  local gradeId = tonumber(args[2])
  if not target or not gradeId then reply(source, 'usage: /setgrade <src> <grade>'); return end
  local ok, err = exports['sl-jobs']:SetGrade(target, gradeId)
  reply(source, ok and 'ok' or ('echec: ' .. tostring(err)))
end, true)

RegisterCommand('fire', function(source, args)
  local target = tonumber(args[1])
  if not target then reply(source, 'usage: /fire <src>'); return end
  local ok = exports['sl-jobs']:SetJob(target, Jobs.DefaultJob, 0)
  reply(source, ok and ('src=%d viré'):format(target) or 'echec')
end, true)

RegisterCommand('jobs', function(source)
  local list = {}
  for name, job in pairs(Jobs.Catalog) do
    table.insert(list, ('  - %s (%s) grades=%d%s'):format(
      name, job.label, (function() local n=0; for _ in pairs(job.grades) do n=n+1 end; return n end)(),
      job.isPublic and ' [public]' or ' [privé]'
    ))
  end
  table.sort(list)
  reply(source, ('%d jobs dans le catalogue:'):format(#list))
  for _, l in ipairs(list) do reply(source, l) end
end, true)

RegisterCommand('paycheck_now', function(source)
  local n = exports['sl-jobs']:TriggerPaycheck()
  reply(source, 'paycheck déclenché')
end, true)

RegisterCommand('myjob', function(source)
  local job = exports['sl-jobs']:GetJob(source)
  if not job then reply(source, 'pas chargé'); return end
  reply(source, ('Job: %s | Grade: %s | Duty: %s'):format(
    job.label, job.gradeLabel, job.onDuty and 'ON' or 'OFF'
  ))
end, false)
