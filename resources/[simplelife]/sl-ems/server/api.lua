print('[sl-ems/server] api.lua loaded')

-- Acces a sl-core pour la DB (SL est local dans main.lua, on re-declare ici)
local SL = exports['sl-core']

-- ===========================================================================
-- Hooks et evenements complementaires.
-- Les exports publics (ReviveTarget, HealTarget, GetInjuries) sont declares
-- dans main.lua. Ce fichier ajoute les hooks items et evenements bus.
-- ===========================================================================

-- ===========================================================================
-- Hook : utilisation d un item de soin depuis sl-inventory
-- sl-inventory emet 'sl:inventory:itemUsed' cote serveur
-- ===========================================================================
AddEventHandler('sl:inventory:itemUsed', function(payload)
  if not payload or not payload.source or not payload.item then return end
  if not payload.consumed then return end

  local item    = payload.item
  local source  = payload.source
  local healAmt = EMS.HealItems[item]

  if not healAmt then return end

  -- Applique HP cote client (via bus dispatch)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:ems:applyHealth', { amount = healAmt })

  -- Stop saignement
  pcall(function() exports['sl-death']:SetBleed(source, 0) end)

  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Soin applique : +%d HP.'):format(healAmt),
    type = 'success',
  })

  -- XP minimal auto-soin
  pcall(function()
    exports['sl-skills']:AddXP(source, 'medical', 2)
  end)
end)

-- ===========================================================================
-- Hook : ecoute sl:death:downed pour notifier les medecins en service
-- ===========================================================================
AddEventHandler('sl:death:downed', function(payload)
  if not payload or not payload.source then return end
  local downedSrc = payload.source

  for src, entry in pairs(Cache) do
    if entry.onDuty and src ~= downedSrc then
      TriggerClientEvent('ox_lib:notify', src, {
        description = 'Un joueur est a terre ! Verifiez le MDT.',
        type        = 'error',
        duration    = 8000,
      })
    end
  end
end)

-- ===========================================================================
-- Network event : requestBill (emis par la commande client /emsbill
-- ou par la NUI, redirige ici pour centraliser la logique)
-- ===========================================================================
RegisterNetEvent('sl:ems:requestBill', function(targetSrc, amount)
  local medicSrc   = source
  local medicEntry = Cache[medicSrc]
  if not medicEntry then return end

  amount = math.floor(tonumber(amount) or EMS.DefaultBillAmount)
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

  local targetEntry = Cache[targetSrc]
  if not targetEntry then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Joueur introuvable.', type = 'error' })
    return
  end

  local debitOk = pcall(function()
    exports['sl-economy']:RemoveMoney(targetSrc, 'bank', amount, 'soins_medicaux')
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
  TriggerClientEvent('ox_lib:notify', targetSrc, {
    description = ('Facture medicale : -$%d prelevee.'):format(amount), type = 'error' })

  pcall(function()
    exports['sl-skills']:AddXP(medicSrc, 'medical', EMS.XP.bill)
  end)

  print(('[sl-ems] Bill: medic=%d target=%d amount=%d'):format(medicSrc, targetSrc, amount))
end)
