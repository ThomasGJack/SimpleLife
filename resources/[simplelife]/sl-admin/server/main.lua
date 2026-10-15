print('[sl-admin/server] main.lua loaded')

local SL = exports['sl-core']

-- Check robuste : essaie plusieurs perms parce que les serveurs configurent
-- différemment leurs ACEs. Console (source=0) toujours admin.
local function isAdmin(source)
  if source == 0 then return true end
  if IsPlayerAceAllowed(source, 'sl.admin')        then return true end
  if IsPlayerAceAllowed(source, 'command.sladmin') then return true end
  if IsPlayerAceAllowed(source, 'command.sl')      then return true end
  if IsPlayerAceAllowed(source, 'command')         then return true end
  if IsPlayerAceAllowed(source, 'group.admin')     then return true end
  return false
end

-- ===========================================================================
-- Helpers callable depuis le client uniquement si admin
-- ===========================================================================

-- /sladmin (chat ou console) : ouvre le menu admin client
RegisterCommand('sladmin', function(source)
  if not isAdmin(source) then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Accès refusé (vous n\'êtes pas admin).', type = 'error' })
    return
  end
  TriggerClientEvent('sl-admin:open', source)
end, false)

-- Event déclenché par le client (keybind F7 ou /sladmin via client)
RegisterNetEvent('sl-admin:requestOpen', function()
  local src = source
  if not isAdmin(src) then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Accès refusé (vous n\'êtes pas admin).', type = 'error' })
    print(('[sl-admin] %s (src=%d) refused : not admin'):format(GetPlayerName(src) or '?', src))
    return
  end
  TriggerClientEvent('sl-admin:open', src)
end)

-- /myace via client → debug dump des permissions
RegisterNetEvent('sl-admin:requestAceDump', function()
  local src = source
  local identifiers = GetPlayerIdentifiers(src)
  local dump = {
    source = src,
    name = GetPlayerName(src),
    identifiers = table.concat(identifiers, ', '),
    isAdmin = isAdmin(src),
    ['ace:sl.admin']        = IsPlayerAceAllowed(src, 'sl.admin'),
    ['ace:command']         = IsPlayerAceAllowed(src, 'command'),
    ['ace:command.sl']      = IsPlayerAceAllowed(src, 'command.sl'),
    ['ace:command.sladmin'] = IsPlayerAceAllowed(src, 'command.sladmin'),
    ['ace:group.admin']     = IsPlayerAceAllowed(src, 'group.admin'),
  }
  -- print aussi côté serveur pour debug
  print(('[sl-admin] /myace by %s (src=%d):'):format(GetPlayerName(src) or '?', src))
  for k, v in pairs(dump) do print(('  %-22s = %s'):format(tostring(k), tostring(v))) end
  TriggerClientEvent('sl-admin:aceDump', src, dump)
end)

-- Liste joueurs en ligne pour le sous-menu admin
lib.callback.register('sl-admin:getPlayers', function(source)
  if not isAdmin(source) then return {} end
  local out = {}
  for _, src in ipairs(GetPlayers()) do
    local s = tonumber(src)
    local name = GetPlayerName(s) or 'Unknown'
    local player = SL:GetPlayer(s)
    out[#out+1] = {
      source = s,
      name = name,
      ping = GetPlayerPing(s),
      characterId = player and player.characterId or nil,
    }
  end
  table.sort(out, function(a, b) return a.source < b.source end)
  return out
end)

-- isAdmin pour le client (check côté client → empêche d'ouvrir le menu si non admin)
lib.callback.register('sl-admin:isAdmin', function(source)
  return isAdmin(source)
end)

-- ===========================================================================
-- Actions admin server-side
-- ===========================================================================

local function notifyAdmin(source, text, type_)
  TriggerClientEvent('ox_lib:notify', source, { description = text, type = type_ or 'inform' })
end

-- Refill HP / armor
RegisterNetEvent('sl-admin:heal', function()
  local src = source
  if not isAdmin(src) then return end
  TriggerClientEvent('sl-admin:applyHeal', src)
  notifyAdmin(src, '✓ Soigné.', 'success')
end)

-- Téléportation vers coords
RegisterNetEvent('sl-admin:tp', function(coords)
  local src = source
  if not isAdmin(src) then return end
  if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then return end
  TriggerClientEvent('sl-admin:applyTp', src, coords)
end)

-- Téléportation vers un joueur
RegisterNetEvent('sl-admin:tpToPlayer', function(targetSrc)
  local src = source
  if not isAdmin(src) then return end
  targetSrc = tonumber(targetSrc); if not targetSrc then return end
  TriggerClientEvent('sl-admin:fetchPlayerCoords', src, targetSrc)
end)

-- Pour la téléportation joueur → joueur (le client cible envoie ses coords)
RegisterNetEvent('sl-admin:reportCoords', function(requesterSrc, coords)
  if not isAdmin(requesterSrc) then return end
  TriggerClientEvent('sl-admin:applyTp', requesterSrc, coords)
end)

-- Donne de l'argent (cash ou bank)
RegisterNetEvent('sl-admin:giveMoney', function(targetSrc, account, amount)
  local src = source
  if not isAdmin(src) then return end
  targetSrc = tonumber(targetSrc) or src
  amount = tonumber(amount) or 0
  if amount <= 0 then return end
  if account ~= 'cash' and account ~= 'bank' then return end
  local ok = exports['sl-economy']:AddMoney(targetSrc, account, amount, 'admin:give')
  if ok then
    notifyAdmin(src, ('+%d %s à %d'):format(amount, account, targetSrc), 'success')
  else
    notifyAdmin(src, 'Échec.', 'error')
  end
end)

-- Refill faim/soif
RegisterNetEvent('sl-admin:refillHunger', function(targetSrc)
  local src = source
  if not isAdmin(src) then return end
  targetSrc = tonumber(targetSrc) or src
  pcall(function() exports['sl-hunger']:RefillAll(targetSrc) end)
  notifyAdmin(src, ('Faim/soif refill pour %d'):format(targetSrc), 'success')
end)

-- Give item
RegisterNetEvent('sl-admin:giveItem', function(targetSrc, item, qty)
  local src = source
  if not isAdmin(src) then return end
  targetSrc = tonumber(targetSrc) or src
  qty = tonumber(qty) or 1
  if not item or item == '' then return end
  local ok, err = exports['sl-inventory']:AddItem(targetSrc, item, qty, nil, 'admin:give')
  if ok then notifyAdmin(src, ('+%d %s à %d'):format(qty, item, targetSrc), 'success')
  else notifyAdmin(src, 'Échec : ' .. tostring(err), 'error') end
end)

-- Reveal map / restore wanted / etc. → côté client, juste un trigger
