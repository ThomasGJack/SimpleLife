print('[sl-shops/server] commands.lua loaded')

local function isAdmin(source)
  if source == 0 then return true end
  return IsPlayerAceAllowed(source, 'command.sl') or IsPlayerAceAllowed(source, 'sl.admin')
end

local function notify(src, msg, type_)
  if src == 0 then print('[sl-shops] ' .. msg); return end
  TriggerClientEvent('ox_lib:notify', src, { description = msg, type = type_ or 'inform' })
end

-- /shoplist : imprime tous les shops + items + prix dans la console serveur
RegisterCommand('shoplist', function(source)
  if not isAdmin(source) then return end
  local lines = { ('[sl-shops] %d shops configurés :'):format((function() local n=0 for _ in pairs(Shops.List) do n=n+1 end return n end)()) }
  for key, shop in pairs(Shops.List) do
    lines[#lines+1] = ('  • %s (%s) — %d points de vente, %d items'):format(
      key, shop.label, #shop.spawns, #shop.inventory)
    for _, line in ipairs(shop.inventory) do
      lines[#lines+1] = ('      - %-20s $%d'):format(line.item, line.price)
    end
  end
  for _, l in ipairs(lines) do print(l) end
  notify(source, 'Liste shops imprimée dans la console serveur.', 'inform')
end, false)

-- /shoptxlog [character_id?] [limit?] : derniers achats de cet user (ou tous)
RegisterCommand('shoptxlog', function(source, args)
  if not isAdmin(source) then return end
  local SL = exports['sl-core']
  local limit = math.min(tonumber(args[2]) or 20, 100)
  local rows
  if args[1] then
    rows = SL:DB().query([[
      SELECT id, shop_key, item, qty, total, payment, created_at
      FROM sl_shop_transactions
      WHERE character_id = ?
      ORDER BY created_at DESC
      LIMIT ]] .. limit, { tonumber(args[1]) }) or {}
  else
    rows = SL:DB().query([[
      SELECT id, character_id, shop_key, item, qty, total, payment, created_at
      FROM sl_shop_transactions
      ORDER BY created_at DESC
      LIMIT ]] .. limit) or {}
  end
  print(('[sl-shops] %d transactions :'):format(#rows))
  for _, r in ipairs(rows) do
    print(('  [%s] cid=%s %s × %d → $%d (%s) @ %s'):format(
      r.shop_key, tostring(r.character_id), r.item, r.qty, r.total, r.payment, r.created_at))
  end
  notify(source, ('%d transactions imprimées (console serveur).'):format(#rows), 'inform')
end, false)
