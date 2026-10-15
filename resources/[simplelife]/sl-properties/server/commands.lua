print('[sl-properties/server] commands.lua loaded')

-- ===========================================================================
-- /shareprop <serverId> : partage l'une de ses proprietes avec un autre joueur
-- Usage : le proprietaire doit etre DANS la propriete (propId tracked dans Cache)
--         OU on partage la premiere propriete possedee si une seule.
-- Pour simplifier V1 : partage la propriete dans laquelle le joueur se trouve.
-- Si pas dans une propriete, on prend la premiere possedee.
-- ===========================================================================
RegisterCommand('shareprop', function(source, args)
  if source == 0 then print('[sl-properties] /shareprop n\'est pas disponible depuis la console.') return end

  local cid = GetCharId(source)
  if not cid then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Vous devez avoir un personnage actif.', type = 'error' })
    return
  end

  local targetServerId = tonumber(args[1])
  if not targetServerId or targetServerId <= 0 then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Usage : /shareprop <serveurId>', type = 'error' })
    return
  end

  -- Determine la propriete a partager
  local propId = Cache[source] and Cache[source].propId or nil
  if not propId then
    -- Prend la premiere propriete possedee
    local row = SL:DB().single(
      'SELECT id FROM sl_properties WHERE owner_character_id = ? LIMIT 1',
      { cid }
    )
    if not row then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Vous ne possedez aucune propriete.', type = 'error' })
      return
    end
    propId = tonumber(row.id)
  end

  -- Recupere le characterId de la cible
  local targetCacheEntry = Cache[targetServerId]
  if not targetCacheEntry or not targetCacheEntry.characterId then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Joueur introuvable ou pas connecte.', type = 'error' })
    return
  end
  local targetCid = targetCacheEntry.characterId

  local ok, reason = AddPropertyAccess(source, propId, targetCid)
  if not ok then
    local msgs = {
      not_owner          = 'Vous n\'etes pas proprietaire de cette propriete.',
      prop_not_found     = 'Propriete introuvable.',
      already_has_access = 'Ce joueur a deja acces a cette propriete.',
      not_loaded         = 'Erreur interne.',
    }
    TriggerClientEvent('ox_lib:notify', source, {
      description = msgs[reason] or ('Erreur : ' .. tostring(reason)),
      type = 'error',
    })
    return
  end

  -- Donne une cle au joueur cible
  exports['sl-inventory']:AddItem(targetServerId, 'cle_maison', 1, { propId = propId }, 'shareprop')

  -- Notifie les deux joueurs
  local prop = LoadProperty(propId)
  local propLabel = prop and prop.label or ('Propriete #' .. propId)

  TriggerClientEvent('ox_lib:notify', source, {
    description = 'Acces partage avec succes pour : ' .. propLabel,
    type = 'success',
  })
  TriggerClientEvent('ox_lib:notify', targetServerId, {
    description = 'Vous avez recu un acces a : ' .. propLabel,
    type = 'inform',
  })

  -- Met a jour les zones cote client de la cible
  TriggerClientEvent('sl:bus:dispatch', targetServerId, 'sl:properties:owned', { propId = propId })
  print(('[sl-properties] shareprop propId=%d de cid=%d vers cid=%d'):format(propId, cid, targetCid))
end, false)

-- ===========================================================================
-- /unshareprop <serverId> : retire l'acces d'un joueur a sa propriete
-- ===========================================================================
RegisterCommand('unshareprop', function(source, args)
  if source == 0 then return end

  local cid = GetCharId(source)
  if not cid then return end

  local targetServerId = tonumber(args[1])
  if not targetServerId or targetServerId <= 0 then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Usage : /unshareprop <serveurId>', type = 'error' })
    return
  end

  local propId = Cache[source] and Cache[source].propId or nil
  if not propId then
    local row = SL:DB().single('SELECT id FROM sl_properties WHERE owner_character_id = ? LIMIT 1', { cid })
    if not row then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Vous ne possedez aucune propriete.', type = 'error' })
      return
    end
    propId = tonumber(row.id)
  end

  local targetCacheEntry = Cache[targetServerId]
  if not targetCacheEntry or not targetCacheEntry.characterId then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Joueur introuvable ou pas connecte.', type = 'error' })
    return
  end
  local targetCid = targetCacheEntry.characterId

  local ok, reason = RemovePropertyAccess(source, propId, targetCid)
  if not ok then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Erreur : ' .. tostring(reason), type = 'error' })
    return
  end

  TriggerClientEvent('ox_lib:notify', source, { description = 'Acces retire avec succes.', type = 'success' })
  print(('[sl-properties] unshareprop propId=%d de cid=%d vers cid=%d'):format(propId, cid, targetCid))
end, false)

-- ===========================================================================
-- /propinfo : info sur la propriete actuelle (admin debug)
-- ===========================================================================
RegisterCommand('propinfo', function(source, args)
  if source == 0 then return end
  if not IsPlayerAceAllowed(source, 'sl.admin') then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' })
    return
  end

  local propId = Cache[source] and Cache[source].propId or nil
  if not propId then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Vous n\'etes dans aucune propriete.', type = 'inform' })
    return
  end

  local prop = LoadProperty(propId)
  if not prop then return end

  local info = ('Prop #%d [%s] | Owner cid=%s | Prix=%d$'):format(
    prop.id, prop.label,
    tostring(prop.owner or 'libre'),
    prop.price
  )
  TriggerClientEvent('ox_lib:notify', source, { description = info, type = 'inform', duration = 8000 })
end, false)

-- ===========================================================================
-- /giveprop <propId> <serverId> : admin donne une propriete a un joueur
-- ===========================================================================
RegisterCommand('giveprop', function(source, args)
  if not (source == 0 or IsPlayerAceAllowed(source, 'sl.admin')) then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' })
    end
    return
  end

  local propId   = tonumber(args[1])
  local targetId = tonumber(args[2])
  if not propId or not targetId then
    print('[sl-properties] /giveprop <propId> <serverId>')
    return
  end

  local targetCache = Cache[targetId]
  if not targetCache or not targetCache.characterId then
    print('[sl-properties] /giveprop : joueur non trouve')
    return
  end

  SL:DB().update('UPDATE sl_properties SET owner_character_id = ? WHERE id = ?', { targetCache.characterId, propId })
  PropOwners[propId] = targetCache.characterId

  exports['sl-inventory']:AddItem(targetId, 'cle_maison', 1, { propId = propId }, 'admin_giveprop')
  TriggerClientEvent('ox_lib:notify', targetId, {
    description = 'Un administrateur vous a attribue une propriete.',
    type = 'inform',
  })
  TriggerClientEvent('sl:bus:dispatch', targetId, 'sl:properties:owned', { propId = propId })
  print(('[sl-properties] giveprop propId=%d -> cid=%d'):format(propId, targetCache.characterId))
end, false)
