SL._ready = false

CreateThread(function()
  print(('^5[sl-core] booting v%s (api=%d, env=%s)^7'):format(SL_CORE_VERSION, SL_CORE_API, Config.Env))

  local pinged = false
  for i = 1, 30 do
    if SL.DB.ping() then pinged = true; break end
    Wait(500)
  end
  if not pinged then
    print('^1[sl-core] FATAL: cannot connect to DB after 15s — check mysql_connection_string^0')
    return
  end
  print(('^2[sl-core] db ping ok (target: %s)^0'):format(SL.DB.dbName()))

  local ok, err = pcall(SL.Migrations.ApplyAll)
  if not ok then
    print(('^1[sl-core] FATAL: migrations failed: %s^0'):format(tostring(err)))
    return
  end

  SL.Modules.Register({
    name = GetCurrentResourceName(),
    version = SL_CORE_VERSION,
    coreApi = SL_CORE_API,
    deps = {},
  })

  SL.SaveManager.Start()

  SL._ready = true
  SL.Bus.Emit('sl:core:ready', { version = SL_CORE_VERSION, env = Config.Env })
  print(('^2[sl-core] ready (env=%s)^0'):format(Config.Env))
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
  local src = source
  deferrals.defer()
  Wait(0)

  if not SL._ready then
    deferrals.update('SimpleLife démarre, patiente...')
    local waited = 0
    while not SL._ready and waited < 20000 do
      Wait(200)
      waited = waited + 200
    end
    if not SL._ready then
      deferrals.done('SimpleLife: le core n\'est pas prêt. Réessaie dans 30 secondes.')
      return
    end
  end

  deferrals.update('Bienvenue sur SimpleLife !')
  Wait(300)
  deferrals.done()
end)

AddEventHandler('playerJoining', function()
  local src = source
  CreateThread(function()
    Wait(100)
    local ok, err = pcall(function() SL.Players.Load(src) end)
    if not ok then
      print(('^1[sl-core] failed to load player %d: %s^0'):format(src, tostring(err)))
    end
  end)
end)

RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  local src = source
  SL.Bus.Emit(event, payload and (function() payload._source = src; return payload end)() or { _source = src })
end)

RegisterNetEvent('sl:core:updatePosition', function(pos)
  local src = source
  local player = SL.Players[src]
  if not player or not player.characterId then return end
  if type(pos) ~= 'table' or not pos.x or not pos.y or not pos.z then return end
  player.position = {
    x = tonumber(pos.x) + 0.0,
    y = tonumber(pos.y) + 0.0,
    z = tonumber(pos.z) + 0.0,
    heading = tonumber(pos.heading) or 0.0,
  }
  player.modified = true
end)
