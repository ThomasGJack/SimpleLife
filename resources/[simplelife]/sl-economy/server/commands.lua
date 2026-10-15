local SL = exports['sl-core']

local function reply(source, msg)
  if source == 0 then
    print(msg)
  else
    TriggerClientEvent('chat:addMessage', source, { args = { '[Money]', msg } })
  end
end

RegisterCommand('slmoney', function(source, args)
  local sub = args[1]

  if sub == 'show' or sub == 'balance' or sub == 'me' then
    local target = tonumber(args[2]) or source
    if target == 0 then reply(source, 'pour console, donne un src: /slmoney show <id>'); return end
    local b = exports['sl-economy']:GetBalances(target)
    if not b then reply(source, 'no player at source ' .. target); return end
    reply(source, ('src=%d cash=%s bank=%s crypto=%s'):format(
      target, Economy.FormatMoney(b.cash or 0), Economy.FormatMoney(b.bank or 0), Economy.FormatMoney(b.crypto or 0)
    ))
    return
  end

  if sub == 'list' then
    local players = exports['sl-core']:GetPlayers()
    reply(source, ('%d player(s) en ligne:'):format(#players))
    for _, p in ipairs(players) do
      local entry = Cache[p.source]
      reply(source, ('  src=%d cid=%s cash=%s bank=%s crypto=%s'):format(
        p.source, p.citizenId or 'none',
        Economy.FormatMoney(entry and entry.cash or 0),
        Economy.FormatMoney(entry and entry.bank or 0),
        Economy.FormatMoney(entry and entry.crypto or 0)
      ))
    end
    return
  end

  if sub == 'give' or sub == 'add' then
    local target = tonumber(args[2])
    local account = args[3]
    local amount = tonumber(args[4])
    if not target or not account or not amount then
      reply(source, 'usage: /slmoney give <src> <cash|bank|crypto> <amount>'); return
    end
    local ok, res = exports['sl-economy']:AddMoney(target, account, amount, 'admin:give')
    if ok then
      reply(source, ('+%s %s sur src=%d, new balance=%s'):format(Economy.FormatMoney(amount), account, target, Economy.FormatMoney(res)))
    else
      reply(source, 'echec: ' .. tostring(res))
    end
    return
  end

  if sub == 'remove' or sub == 'take' then
    local target = tonumber(args[2])
    local account = args[3]
    local amount = tonumber(args[4])
    if not target or not account or not amount then
      reply(source, 'usage: /slmoney remove <src> <cash|bank|crypto> <amount>'); return
    end
    local ok, res = exports['sl-economy']:RemoveMoney(target, account, amount, 'admin:remove')
    if ok then
      reply(source, ('-%s %s sur src=%d, new balance=%s'):format(Economy.FormatMoney(amount), account, target, Economy.FormatMoney(res)))
    else
      reply(source, 'echec: ' .. tostring(res))
    end
    return
  end

  if sub == 'log' then
    local target = tonumber(args[2]) or source
    local rows = exports['sl-economy']:GetRecentTransactions(target, 10)
    reply(source, ('%d derniers mouvements pour src=%d:'):format(#rows, target))
    for _, r in ipairs(rows) do
      reply(source, ('  [%s] %s %s%s -> %s (%s)'):format(
        tostring(r.created_at), r.account,
        r.delta >= 0 and '+' or '',
        Economy.FormatMoney(r.delta),
        Economy.FormatMoney(r.balance_after),
        r.reason or ''
      ))
    end
    return
  end

  if sub == 'transfer' then
    local from = tonumber(args[2])
    local to = tonumber(args[3])
    local account = args[4]
    local amount = tonumber(args[5])
    if not from or not to or not account or not amount then
      reply(source, 'usage: /slmoney transfer <fromSrc> <toSrc> <account> <amount>'); return
    end
    local ok, err = exports['sl-economy']:Transfer(from, to, account, amount, 'admin:transfer')
    if ok then
      reply(source, ('virement %d -> %d : %s %s'):format(from, to, Economy.FormatMoney(amount), account))
    else
      reply(source, 'echec: ' .. tostring(err))
    end
    return
  end

  reply(source, 'usage: /slmoney <show|give|remove|transfer|log> ...')
end, true)
