print('[sl-inventory/server] commands.lua loaded')

local function isAdmin(source)
  if source == 0 then return true end
  return IsPlayerAceAllowed(source, 'command.sl') or IsPlayerAceAllowed(source, 'sl.admin')
end

local function notify(source, msg, type_)
  if source == 0 then print('[sl-inventory] ' .. msg); return end
  TriggerClientEvent('ox_lib:notify', source, { description = msg, type = type_ or 'inform' })
end

-- /giveitem <serverId> <item> [count]
RegisterCommand('giveitem', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1])
  local item   = args[2]
  local count  = tonumber(args[3]) or 1
  if not target or not item then
    notify(source, 'Usage : /giveitem <id> <item> [count]', 'error'); return
  end
  if not Items.Exists(item) then
    notify(source, ('Item inconnu : %s'):format(item), 'error'); return
  end
  local ok, err = InventoryAddItem(target, item, count, nil, 'admin-give')
  if ok then
    notify(source, ('Donné %d x %s à %d'):format(count, item, target), 'success')
    notify(target, ('Vous avez reçu %d x %s'):format(count, Items.Get(item).label or item), 'success')
  else
    notify(source, ('Échec : %s'):format(tostring(err)), 'error')
  end
end, false)

-- /removeitem <serverId> <item> [count]
RegisterCommand('removeitem', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1])
  local item   = args[2]
  local count  = tonumber(args[3]) or 1
  if not target or not item then
    notify(source, 'Usage : /removeitem <id> <item> [count]', 'error'); return
  end
  local ok, err = InventoryRemoveItem(target, item, count, nil, 'admin-remove')
  if ok then
    notify(source, ('Retiré %d x %s à %d'):format(count, item, target), 'success')
    notify(target, ('Un admin vous a retiré %d x %s'):format(count, Items.Get(item) and Items.Get(item).label or item), 'inform')
  else
    notify(source, ('Échec : %s'):format(tostring(err)), 'error')
  end
end, false)

-- /clearinv <serverId>
RegisterCommand('clearinv', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1]) or source
  local entry = GetCache(target)
  if not entry then notify(source, 'Inventaire non chargé.', 'error'); return end
  for slot, _ in pairs(entry.slots) do
    PersistDelete(entry.characterId, slot)
  end
  entry.slots = {}
  PushInventoryToClient(target)
  notify(source, ('Inventaire vidé pour %d'):format(target), 'success')
end, false)

-- /listinv <serverId?>
RegisterCommand('listinv', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1]) or source
  local entry = GetCache(target)
  if not entry then notify(source, 'Inventaire non chargé.', 'error'); return end
  local lines = {}
  for slot = 1, Inventory.SlotCount do
    local s = entry.slots[slot]
    if s then
      lines[#lines+1] = ('  slot %02d : %s x%d'):format(slot, s.item, s.count or 1)
    end
  end
  if #lines == 0 then
    notify(source, 'Inventaire vide.', 'inform')
  else
    print(('[sl-inventory] inventory of src=%d:'):format(target))
    for _, l in ipairs(lines) do print(l) end
    notify(source, ('Inventaire imprimé dans la console serveur (%d slots).'):format(#lines), 'inform')
  end
end, false)

-- /items — liste tous les items du catalogue
RegisterCommand('items', function(source)
  if not isAdmin(source) then return end
  local list = Items.List()
  print(('[sl-inventory] catalog (%d items) :'):format(#list))
  for _, it in ipairs(list) do
    print(('  %-22s | %-32s | %4dg | stack=%d | %s%s'):format(
      it.name, it.label, it.weight or 0, it.stack or 1,
      it.usable and 'usable ' or '       ',
      it.unique and 'unique ' or ''))
  end
  notify(source, ('Catalogue (%d items) imprimé dans la console serveur.'):format(#list), 'inform')
end, false)
