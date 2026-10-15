SL = SL or {}
SL.SaveManager = {}

local started = false

function SL.SaveManager.Start()
  if started then return end
  started = true
  CreateThread(function()
    while true do
      Wait((Config.AutosaveIntervalMin or 5) * 60 * 1000)
      local n = SL.Players.SaveAll('autosave')
      if n > 0 then
        print(('^2[sl-core] autosave: %d players persisted^0'):format(n))
      end
    end
  end)
end

AddEventHandler('playerDropped', function(reason)
  local src = source
  pcall(function() SL.Players.Drop(src, reason or 'dropped') end)
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  print('^3[sl-core] shutdown: saving all players...^0')
  SL.Players.SaveAll('shutdown')
end)

AddEventHandler('txAdmin:events:scheduledRestart', function()
  print('^3[sl-core] scheduled restart detected: saving all...^0')
  SL.Players.SaveAll('scheduled-restart')
end)
