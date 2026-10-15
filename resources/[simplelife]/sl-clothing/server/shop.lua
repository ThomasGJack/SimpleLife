local SL = exports['sl-core']

lib.callback.register('sl-clothing:purchase', function(source, payload)
  local entry = Cache[source]
  if not entry then return { ok = false, error = 'not loaded' } end
  if type(payload) ~= 'table' or not payload.changes then return { ok = false, error = 'invalid payload' } end

  local price = 0
  for _, change in ipairs(payload.changes) do
    if change.kind == 'component' then
      for _, c in ipairs(Clothing.Components) do
        if c.id == change.id then price = price + (c.price or 0) end
      end
    elseif change.kind == 'prop' then
      for _, p in ipairs(Clothing.Props) do
        if p.id == change.id then price = price + (p.price or 0) end
      end
    end
  end

  if price <= 0 then return { ok = false, error = 'aucun changement' } end

  local cashBalance = exports['sl-economy']:GetMoney(source, 'cash') or 0
  local bankBalance = exports['sl-economy']:GetMoney(source, 'bank') or 0
  local account = (cashBalance >= price) and 'cash' or ((bankBalance >= price) and 'bank' or nil)
  if not account then return { ok = false, error = ('fonds insuffisants (besoin %d$)'):format(price) } end

  local ok, err = exports['sl-economy']:RemoveMoney(source, account, price, 'clothing:purchase')
  if not ok then return { ok = false, error = err or 'echec paiement' } end

  -- IMPORTANT : on force les clés en STRING pour rester cohérent avec ce que
  -- json.decode retourne après un cycle save/load. Sinon on se retrouve avec
  -- une table mixte { ["3"]=..., [11]=... } et cjson écrase des composants
  -- au prochain encode → vêtements "transparents" après reco.
  for _, change in ipairs(payload.changes) do
    if change.kind == 'component' and change.id ~= nil and change.drawable ~= nil then
      entry.appearance.components[tostring(change.id)] = { drawable = change.drawable, texture = change.texture or 0 }
      print(('[sl-clothing] commit component %s = draw %s tex %s'):format(change.id, change.drawable, change.texture or 0))
    elseif change.kind == 'prop' and change.id ~= nil then
      entry.appearance.props[tostring(change.id)] = { drawable = change.drawable, texture = change.texture or 0 }
      print(('[sl-clothing] commit prop %s = draw %s tex %s'):format(change.id, change.drawable, change.texture or 0))
    end
  end

  SL:DB().update(
    'UPDATE sl_appearance SET components = ?, props = ? WHERE character_id = ?',
    {
      json.encode(entry.appearance.components),
      json.encode(entry.appearance.props),
      entry.characterId,
    }
  )

  TriggerClientEvent('sl:bus:dispatch', source, 'sl:clothing:apply', entry.appearance)

  return { ok = true, account = account, price = price, newBalance = exports['sl-economy']:GetMoney(source, account) }
end)
