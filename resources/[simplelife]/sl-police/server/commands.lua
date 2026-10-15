print('[sl-police/server] commands.lua loaded')

-- ===========================================================================
-- /cuff <id> — Menotter le joueur cible (le cop cote client gere la proximite
-- mais on accepte aussi la commande directe pour les admins)
-- ===========================================================================
RegisterCommand('cuff', function(source, args)
  local src = source
  if src == 0 then
    print('[sl-police] /cuff : commande console non supportee (utiliser exports)')
    return
  end
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  if not targetId then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Usage : /cuff <id>', type = 'error' })
    return
  end
  local ok, err = CuffFn(src, targetId)
  if not ok then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Erreur : ' .. tostring(err), type = 'error' })
  end
end, false)

-- ===========================================================================
-- /uncuff <id> — Demenotter
-- ===========================================================================
RegisterCommand('uncuff', function(source, args)
  local src = source
  if src == 0 then return end
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  if not targetId then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Usage : /uncuff <id>', type = 'error' })
    return
  end
  local ok, err = UncuffFn(src, targetId)
  if not ok then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Erreur : ' .. tostring(err), type = 'error' })
  end
end, false)

-- ===========================================================================
-- /drag <id> — Commencer l escorte du menotte
-- ===========================================================================
RegisterCommand('drag', function(source, args)
  local src = source
  if src == 0 then return end
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  if not targetId then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Usage : /drag <id>', type = 'error' })
    return
  end
  -- Logique d escorte (identique a sl:police:net:drag, mais on est deja serveur :
  -- TriggerNetEvent n existe pas cote serveur, on traite directement ici).
  if not Cuffed[targetId] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Ce joueur n est pas menotte.', type = 'error' })
    return
  end
  TriggerClientEvent('ox_lib:notify', targetId, { description = 'Un officier vous escorte.', type = 'inform' })
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:startDrag', { target = targetId })
end, false)

-- ===========================================================================
-- /stopdrag — Arreter l escorte
-- ===========================================================================
RegisterCommand('stopdrag', function(source)
  local src = source
  if src == 0 then return end
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:stopDrag', {})
end, false)

-- ===========================================================================
-- /putin <id> [seat] — Mettre un menotte dans le vehicule (passager arriere par defaut)
-- ===========================================================================
RegisterCommand('putin', function(source, args)
  local src = source
  if src == 0 then return end
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  local seat     = tonumber(args[2]) or -2
  if not targetId then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Usage : /putin <id> [siege]', type = 'error' })
    return
  end
  if not Cuffed[targetId] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Ce joueur n est pas menotte.', type = 'error' })
    return
  end
  -- Le vehicule du cop est gere cote client, on demande au client de fournir le netId
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:requestPutin', {
    target = targetId,
    seat   = seat,
  })
end, false)

-- ===========================================================================
-- /search <id> — Fouiller un joueur (ouvre la NUI fouille)
-- ===========================================================================
RegisterCommand('search', function(source, args)
  local src = source
  if src == 0 then return end
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  if not targetId then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Usage : /search <id>', type = 'error' })
    return
  end
  if not GetPlayerName(targetId) then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Joueur introuvable.', type = 'error' })
    return
  end
  -- Recuperer l inventaire du target et ouvrir la NUI fouille cote cop
  local ok, items = pcall(function()
    return exports['sl-inventory']:GetItems(targetId)
  end)
  if not ok then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Erreur inventaire.', type = 'error' })
    return
  end
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:openSearch', {
    targetSrc = targetId,
    items     = items or {},
  })
end, false)

-- ===========================================================================
-- /jail <id> <secondes> — Emprisonner
-- ===========================================================================
RegisterCommand('jail', function(source, args)
  local src = source
  -- Admins + cops en service
  local isAdmin = (src == 0) or IsPlayerAceAllowed(tostring(src), 'sl.admin')
  if src ~= 0 and not isAdmin and not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Acces refuse.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  local seconds  = tonumber(args[2]) or 300
  if not targetId then
    if src == 0 then
      print('[sl-police] Usage : /jail <id> <secondes>')
    else
      TriggerClientEvent('ox_lib:notify', src, { description = 'Usage : /jail <id> <secondes>', type = 'error' })
    end
    return
  end
  local ok, err = JailFn(targetId, seconds)
  if not ok then
    if src == 0 then
      print('[sl-police] JailFn erreur : ' .. tostring(err))
    else
      TriggerClientEvent('ox_lib:notify', src, { description = 'Erreur : ' .. tostring(err), type = 'error' })
    end
  else
    if src ~= 0 then
      TriggerClientEvent('ox_lib:notify', src, {
        description = ('Joueur %d emprisonne pour %ds.'):format(targetId, seconds),
        type        = 'success',
      })
    end
  end
end, false)

-- ===========================================================================
-- /fine <id> <montant> <motif> — Dresser une amende
-- ===========================================================================
RegisterCommand('fine', function(source, args)
  local src = source
  local isAdmin = (src == 0) or IsPlayerAceAllowed(tostring(src), 'sl.admin')
  if src ~= 0 and not isAdmin and not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Acces refuse.', type = 'error' })
    return
  end
  local targetId = tonumber(args[1])
  local amount   = tonumber(args[2]) or 0
  local motif    = table.concat(args, ' ', 3) or 'Infraction'

  if not targetId or amount <= 0 then
    local msg = 'Usage : /fine <id> <montant> <motif>'
    if src == 0 then print('[sl-police] ' .. msg) else
      TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'error' })
    end
    return
  end

  local czid = GetCitizenId(targetId)
  if not czid then
    local msg = 'Joueur introuvable ou personnage non charge.'
    if src == 0 then print('[sl-police] ' .. msg) else
      TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'error' })
    end
    return
  end

  local ok, err = AddChargeFn(czid, motif, amount)
  if ok then
    local msg = ('Amende $%d — %s — citoyen %s'):format(amount, motif, czid)
    if src == 0 then print('[sl-police] ' .. msg) else
      TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'success' })
    end
  else
    local msg = 'Erreur : ' .. tostring(err)
    if src == 0 then print('[sl-police] ' .. msg) else
      TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'error' })
    end
  end
end, false)

-- ===========================================================================
-- /mdt — Ouvrir le terminal MDT (ouvre la NUI, gere cote client)
-- ===========================================================================
RegisterCommand('mdt', function(source)
  local src = source
  if src == 0 then return end
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service pour utiliser le MDT.', type = 'error' })
    return
  end
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:openMDT', {})
end, false)

-- ===========================================================================
-- /addcharge <citizenId> <montant> <motif> — Admin : ajouter une charge
-- ===========================================================================
RegisterCommand('addcharge', function(source, args)
  local src = source
  local isAdmin = (src == 0) or IsPlayerAceAllowed(tostring(src), 'sl.admin')
  if not isAdmin and (src ~= 0 and not OnDuty[src]) then
    if src ~= 0 then
      TriggerClientEvent('ox_lib:notify', src, { description = 'Acces refuse.', type = 'error' })
    end
    return
  end
  local czid   = tostring(args[1] or '')
  local fine   = tonumber(args[2]) or 0
  local charge = table.concat(args, ' ', 3) or 'Infraction'
  if czid == '' then
    local msg = 'Usage : /addcharge <citizenId> <montant> <motif>'
    if src == 0 then print('[sl-police] ' .. msg) else
      TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'error' })
    end
    return
  end
  local ok, err = AddChargeFn(czid, charge, fine)
  local msg = ok and ('Charge ajoutee : ' .. czid) or ('Erreur : ' .. tostring(err))
  if src == 0 then print('[sl-police] ' .. msg) else
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = ok and 'success' or 'error' })
  end
end, false)
