local function reply(source, msg)
  if source == 0 then
    print(msg)
  else
    TriggerClientEvent('chat:addMessage', source, { args = { '[SL]', msg } })
  end
end

local function bold(s) return '^5' .. s .. '^7' end

RegisterCommand('sl', function(source, args)
  local sub = args[1]
  if not sub then
    reply(source, 'usage: /sl <info|modules|save|reload|db>')
    return
  end

  if sub == 'info' then
    local target = tonumber(args[2]) or source
    local p = SL.Players.Get(target)
    if not p then
      reply(source, ('no player loaded at source %d'):format(target))
      return
    end
    reply(source, ('src=%d account=%d license=%s citizen=%s'):format(
      p.source, p.accountId, (p.identifiers.license or '?'):sub(1, 20) .. '...',
      p.citizenId or '(none)'
    ))
    return
  end

  if sub == 'modules' then
    local list = SL.Modules.List()
    reply(source, ('%d modules loaded:'):format(#list))
    for _, m in ipairs(list) do
      reply(source, ('  - %s v%s (api=%d)'):format(m.name, m.version, m.coreApi))
    end
    return
  end

  if sub == 'save' then
    local n = SL.Players.SaveAll('manual')
    reply(source, ('saved %d players'):format(n))
    return
  end

  if sub == 'reload' then
    local mod = args[2]
    if not mod then reply(source, 'usage: /sl reload <module>'); return end
    ExecuteCommand('restart ' .. mod)
    reply(source, 'restarted ' .. mod)
    return
  end

  if sub == 'restart-stack' then
    local mods = SL.Modules.List()
    local others = {}
    for _, m in ipairs(mods) do
      if m.name ~= GetCurrentResourceName() then table.insert(others, m.name) end
    end
    for _, name in ipairs(others) do
      reply(source, 'restarting ' .. name)
      ExecuteCommand('restart ' .. name)
    end
    reply(source, ('done — %d modules restarted (sl-core stays up)'):format(#others))
    return
  end

  if sub == 'db' then
    local action = args[2]
    if action == 'ping' then
      local t0 = os.clock()
      local ok = SL.DB.ping()
      local ms = (os.clock() - t0) * 1000
      reply(source, ('db ping: %s (%.1fms) target=%s'):format(ok and 'OK' or 'FAIL', ms, SL.DB.dbName()))
      return
    end
    if action == 'status' then
      reply(source, ('env=%s db=%s'):format(Config.Env, SL.DB.dbName()))
      local stats = SL.DB.query([[
        SELECT TABLE_NAME AS name, TABLE_ROWS AS rows
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'sl_%'
        ORDER BY TABLE_NAME
      ]])
      for _, t in ipairs(stats or {}) do
        reply(source, ('  %s: ~%s rows'):format(t.name, tostring(t.rows)))
      end
      return
    end
    if action == 'migrations' then
      local applied, pending = SL.Migrations.Status()
      reply(source, ('migrations: %d applied, %d pending'):format(#applied, #pending))
      for _, m in ipairs(applied) do
        reply(source, ('  [OK] %s/%s'):format(m.resource, m.filename))
      end
      for _, m in ipairs(pending) do
        reply(source, ('  [..] %s/%s (pending)'):format(m.resource, m.filename))
      end
      return
    end
    if action == 'migrate' then
      local applied, skipped = SL.Migrations.ApplyAll()
      reply(source, ('migrate done: %d applied, %d skipped'):format(applied, skipped))
      return
    end
    reply(source, 'usage: /sl db <ping|status|migrations|migrate>')
    return
  end

  reply(source, 'unknown subcommand: ' .. sub)
end, true)

RegisterCommand('slhelp', function(source)
  reply(source, bold('SimpleLife admin commands:'))
  reply(source, '  /sl info [src]        - player state')
  reply(source, '  /sl modules           - loaded modules')
  reply(source, '  /sl save              - save all players')
  reply(source, '  /sl reload <module>   - restart resource')
  reply(source, '  /sl db ping           - test DB')
  reply(source, '  /sl db status         - DB stats')
  reply(source, '  /sl db migrations     - migration state')
  reply(source, '  /sl db migrate        - apply pending migrations')
end, true)
