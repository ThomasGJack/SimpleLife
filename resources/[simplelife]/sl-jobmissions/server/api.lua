print('[sl-jobmissions/server] api.lua loaded')

-- ===========================================================================
-- Exports publics sl-jobmissions
-- ===========================================================================

-- Forcer l arret/demarrage d une mission pour un joueur (admin / integration)
-- Usage : exports['sl-jobmissions']:StopMission(src)
exports('StopMission', function(src)
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:jobmissions:forceStop', {})
end)

exports('StartMission', function(src, jobName)
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:jobmissions:forceStart', { name = jobName })
end)

-- Commande admin /missionstop <id>
RegisterCommand('missionstop', function(source, args)
  local isAdmin = (source == 0) or IsPlayerAceAllowed(source, 'sl.admin')
  if not isAdmin then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' })
    end
    return
  end
  local targetId = tonumber(args[1])
  if not targetId then
    print('[sl-jobmissions] /missionstop <playerId>')
    return
  end
  TriggerClientEvent('sl:bus:dispatch', targetId, 'sl:jobmissions:forceStop', {})
  print(('[sl-jobmissions] admin stopped mission for player %d'):format(targetId))
end, true)

-- Commande admin /missionstart <id> <job>
RegisterCommand('missionstart', function(source, args)
  local isAdmin = (source == 0) or IsPlayerAceAllowed(source, 'sl.admin')
  if not isAdmin then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' })
    end
    return
  end
  local targetId = tonumber(args[1])
  local jobName  = args[2]
  if not targetId or not jobName then
    print('[sl-jobmissions] /missionstart <playerId> <jobName>')
    return
  end
  TriggerClientEvent('sl:bus:dispatch', targetId, 'sl:jobmissions:forceStart', { name = jobName })
  print(('[sl-jobmissions] admin started mission %s for player %d'):format(jobName, targetId))
end, true)
