print('[sl-ems/server] commands.lua loaded')

-- Acces a sl-core pour la DB (SL est local dans main.lua, on re-declare ici)
local SL = exports['sl-core']

-- ===========================================================================
-- Commandes console / admin
-- Les commandes joueur (/revivep, /carry, /emsbill) sont traitees cote
-- client sauf les variantes admin ci-dessous.
-- ===========================================================================

-- /revivep <id> — revive admin direct (sans restriction job ni cooldown)
RegisterCommand('revivep', function(source, args, rawCommand)
  local isCli   = (source == 0)
  local isAdmin = isCli or IsPlayerAceAllowed(source, 'sl.admin')

  -- Les joueurs utilisent la version client-side (barre de prog)
  -- Cette commande-ci sert uniquement aux admins en console ou in-game
  if not isAdmin then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Commande reservee aux admins.', type = 'error' })
    end
    return
  end

  local targetId = tonumber(args[1])
  if not targetId then
    if isCli then print('[sl-ems] Usage: /revivep <playerId>')
    else TriggerClientEvent('ox_lib:notify', source,
      { description = 'Usage: /revivep <playerId>', type = 'error' }) end
    return
  end

  -- Revive sans cooldown (admin bypass : appel direct sl-death)
  local ok, err = pcall(function()
    exports['sl-death']:Revive(targetId)
    exports['sl-death']:SetBleed(targetId, 0)
  end)
  if ok then
    TriggerClientEvent('ox_lib:notify', targetId, {
      description = 'Un admin vous a ranime.', type = 'success' })
    if isCli then
      print(('[sl-ems] Admin revive: target=%d'):format(targetId))
    else
      TriggerClientEvent('ox_lib:notify', source, {
        description = ('Joueur #%d ranime.'):format(targetId), type = 'success' })
    end
  else
    if isCli then print(('[sl-ems] revivep error: %s'):format(tostring(err)))
    else TriggerClientEvent('ox_lib:notify', source,
      { description = 'Erreur lors du revive.', type = 'error' }) end
  end
end, false)

-- /heal <id> [amount] — admin heal direct
RegisterCommand('heal', function(source, args, rawCommand)
  local isCli   = (source == 0)
  local isAdmin = isCli or IsPlayerAceAllowed(source, 'sl.admin')
  if not isAdmin then
    if source ~= 0 then
      TriggerClientEvent('ox_lib:notify', source, {
        description = 'Commande reservee aux admins.', type = 'error' })
    end
    return
  end

  local targetId = tonumber(args[1])
  local amount   = tonumber(args[2]) or EMS.MaxHealth
  if not targetId then
    if isCli then print('[sl-ems] Usage: /heal <playerId> [amount]')
    else TriggerClientEvent('ox_lib:notify', source,
      { description = 'Usage: /heal <playerId> [amount]', type = 'error' }) end
    return
  end

  -- Pour l admin, on passe medicSrc = targetId (heal sur soi-meme) pour eviter
  -- les notifs croisees non souhaitees. On appelle directement applyHealth.
  TriggerClientEvent('sl:bus:dispatch', targetId, 'sl:ems:applyHealth', { amount = amount })
  pcall(function() exports['sl-death']:SetBleed(targetId, 0) end)

  if isCli then
    print(('[sl-ems] Admin heal: target=%d amount=%d'):format(targetId, amount))
  else
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Joueur #%d soigne (+%d HP).'):format(targetId, amount), type = 'success' })
  end
  TriggerClientEvent('ox_lib:notify', targetId, {
    description = 'Un admin vous a soigne.', type = 'success' })
end, false)

-- /emsbill <id> <montant> — facturer un patient (EMS ou admin)
-- Passe par le RegisterNetEvent de api.lua pour la logique centralisee.
RegisterCommand('emsbill', function(source, args, rawCommand)
  if source == 0 then
    print('[sl-ems] /emsbill non disponible en console (necessite un joueur medecin).')
    return
  end

  local targetId = tonumber(args[1])
  local amount   = tonumber(args[2])
  if not targetId or not amount then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Usage: /emsbill <playerId> <montant>', type = 'error' })
    return
  end

  -- Declenche la logique de facturation via le NetworkEvent (api.lua)
  -- On simule le TriggerNetworkEvent depuis le serveur en appelant directement
  -- la logique : on passe le source manuellement
  local medicSrc   = source
  local medicEntry = Cache[medicSrc]
  if not medicEntry then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Donnees EMS non chargees.', type = 'error' })
    return
  end

  amount = math.floor(amount)
  if amount <= 0 or amount > EMS.MaxBillAmount then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = ('Montant invalide (1 - %d).'):format(EMS.MaxBillAmount),
      type = 'error' })
    return
  end

  local isAdmin = IsPlayerAceAllowed(medicSrc, 'sl.admin')
  if not medicEntry.onDuty and not isAdmin then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Vous devez etre en service ambulancier.', type = 'error' })
    return
  end

  local targetEntry = Cache[targetId]
  if not targetEntry then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Joueur introuvable ou non connecte.', type = 'error' })
    return
  end

  local debitOk = pcall(function()
    exports['sl-economy']:RemoveMoney(targetId, 'bank', amount, 'soins_medicaux')
  end)
  if not debitOk then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Paiement echoue (fonds insuffisants ?).', type = 'error' })
    return
  end

  pcall(function()
    exports['sl-economy']:AddMoney(medicSrc, 'bank', amount, 'honoraires_medicaux')
  end)

  local medicCitizenId  = medicEntry.citizenId  or 0
  local targetCitizenId = targetEntry.citizenId or 0
  pcall(function()
    SL:DB().insert(
      'INSERT INTO sl_ems_bills (patient_citizen_id, medic_citizen_id, amount) VALUES (?, ?, ?)',
      { targetCitizenId, medicCitizenId, amount })
  end)

  TriggerClientEvent('ox_lib:notify', medicSrc, {
    description = ('Facture envoyee : $%d.'):format(amount), type = 'success' })
  TriggerClientEvent('ox_lib:notify', targetId, {
    description = ('Facture medicale : -$%d.'):format(amount), type = 'error' })

  pcall(function()
    exports['sl-skills']:AddXP(medicSrc, 'medical', EMS.XP.bill)
  end)

  print(('[sl-ems] Bill cmd: medic=%d target=%d amount=%d'):format(medicSrc, targetId, amount))
end, false)
