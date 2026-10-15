print('[sl-phone/server] commands.lua loaded')

local function isAdmin(source)
  if source == 0 then return true end
  return IsPlayerAceAllowed(source, 'command.sl') or IsPlayerAceAllowed(source, 'sl.admin')
end

local function notify(src, msg, type_)
  if src == 0 then print('[sl-phone] ' .. msg); return end
  TriggerClientEvent('ox_lib:notify', src, { description = msg, type = type_ or 'inform' })
end

-- /phonenumber : affiche le numéro du joueur
RegisterCommand('phonenumber', function(source)
  local entry = Cache[source]
  if not entry or not entry.number then
    notify(source, 'Téléphone non chargé.', 'error'); return
  end
  notify(source, ('Votre numéro : %s'):format(Phone.FormatNumber(entry.number)), 'inform')
end, false)

-- /phonelookup <serverId> : print en console serveur le numéro d'un joueur
RegisterCommand('phonelookup', function(source, args)
  if not isAdmin(source) then return end
  local target = tonumber(args[1])
  local entry = target and Cache[target]
  if not entry then
    print(('[sl-phone] no phone for src %s'):format(tostring(target)))
    return
  end
  print(('[sl-phone] src=%s cid=%s number=%s (%s)'):format(
    tostring(target), tostring(entry.characterId), entry.number, Phone.FormatNumber(entry.number)))
end, false)

-- /phoneset <serverId> <number> : force un numéro pour un joueur (admin)
-- Utile pour donner un numéro "mémorable" (ex: 555-1234) à un PNJ/business.
RegisterCommand('phoneset', function(source, args)
  if not isAdmin(source) then notify(source, 'Refusé.', 'error'); return end
  local target = tonumber(args[1])
  local number = Phone.NormalizeNumber(args[2])
  if not target or #number < 10 then
    notify(source, 'Usage : /phoneset <id> <10 chiffres>', 'error'); return
  end
  local entry = Cache[target]
  if not entry then notify(source, 'Téléphone non chargé pour ce joueur.', 'error'); return end

  local SL = exports['sl-core']
  -- Vérifie unicité
  local existing = SL:DB().single('SELECT character_id FROM sl_phone_numbers WHERE number = ?', { number })
  if existing and tonumber(existing.character_id) ~= entry.characterId then
    notify(source, 'Numéro déjà utilisé.', 'error'); return
  end

  SL:DB().query([[
    INSERT INTO sl_phone_numbers (character_id, number) VALUES (?, ?)
    ON DUPLICATE KEY UPDATE number = VALUES(number)
  ]], { entry.characterId, number })
  entry.number = number

  TriggerClientEvent('sl:bus:dispatch', target, 'sl:phone:hydrated', { number = number })
  notify(source, ('Numéro de %d : %s'):format(target, Phone.FormatNumber(number)), 'success')
  notify(target, ('Nouveau numéro : %s'):format(Phone.FormatNumber(number)), 'inform')
end, false)

-- /sms <number> <body...> : raccourci pour envoyer un SMS via commande
RegisterCommand('sms', function(source, args)
  if source == 0 then return end
  local number = Phone.NormalizeNumber(args[1])
  local body = table.concat(args, ' ', 2)
  if #number < 10 or body == '' then
    notify(source, 'Usage : /sms <numéro> <message>', 'error'); return
  end
  local ok, err = PhoneSendSMS(source, number, body)
  if ok then
    notify(source, '📤 SMS envoyé.', 'success')
  else
    notify(source, '❌ ' .. tostring(err), 'error')
  end
end, false)
