print('[sl-jobmissions/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Enregistrement module (pattern standard SimpleLife)
-- ===========================================================================
local registered = false
local function tryIsReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end

local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name    = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps    = { 'sl-core@^0.1', 'sl-jobs@^0.1', 'sl-economy@^0.1', 'sl-inventory@^0.1', 'sl-interact@^0.1' },
  })
  print('[sl-jobmissions/server] module registered')
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- NOTE duty changes :
-- sl-jobs (server/api.lua setDuty) emet DEJA 'sl:jobs:dutyChanged' a la fois
-- en event serveur ET en TriggerClientEvent('sl:bus:dispatch', src, ...) vers
-- le client concerne. On ne RE-relaie donc PAS ici, sinon le client recevrait
-- l event en double (double notif + double StartMissionLoop). Le client ecoute
-- directement sl:bus:dispatch.
-- ===========================================================================

-- ===========================================================================
-- Paiement de course taxi (appel depuis le client via callback)
-- ===========================================================================
lib.callback.register('sl-jobmissions:taxi:pay', function(source, amount, reason)
  if type(amount) ~= 'number' or amount <= 0 then return false, 'montant invalide' end
  amount = math.min(math.floor(amount), JobMissions.Taxi.MaxFare)
  local ok, err = pcall(function()
    exports['sl-economy']:AddMoney(source, 'cash', amount, reason or 'course-taxi')
  end)
  if not ok then
    print(('[sl-jobmissions] taxi:pay pcall error: %s'):format(tostring(err)))
    return false, 'economy error'
  end
  -- XP driving (optionnel, pcall)
  pcall(function()
    exports['sl-skills']:AddXP(source, 'driving', JobMissions.Taxi.XpPerFare)
  end)
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Course terminee : +$%d'):format(amount),
    type = 'success',
  })
  return true
end)

-- ===========================================================================
-- Paiement livraison trucker
-- ===========================================================================
lib.callback.register('sl-jobmissions:trucker:pay', function(source, palettes)
  if type(palettes) ~= 'number' or palettes <= 0 then return false end
  local amount = math.floor(palettes) * JobMissions.Trucker.PayPerPallet
  pcall(function()
    exports['sl-economy']:AddMoney(source, 'cash', amount, 'livraison-trucker')
  end)
  pcall(function()
    exports['sl-skills']:AddXP(source, 'driving', JobMissions.Trucker.XpPerDelivery)
  end)
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Livraison complete : +$%d'):format(amount),
    type = 'success',
  })
  return true
end)

-- ===========================================================================
-- Paiement reparation mecano
-- Le paiement vient du proprio du vehicule (si connecte) sinon cash direct au mecano
-- ===========================================================================
lib.callback.register('sl-jobmissions:mechanic:pay', function(source, vehicleNetId)
  local cfg = JobMissions.Mechanic
  -- Verifier que le mecano a bien un repair_kit
  local hasKit = pcall(function()
    return exports['sl-inventory']:HasItem(source, cfg.RepairItem, 1)
  end)
  -- Retirer le repair_kit
  local removed = false
  pcall(function()
    removed = exports['sl-inventory']:RemoveItem(source, cfg.RepairItem, 1, nil, 'repair-used')
  end)
  if not removed then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Il vous faut un kit de reparation.',
      type = 'error',
    })
    return false, 'no_kit'
  end
  -- Paiement au mecano
  pcall(function()
    exports['sl-economy']:AddMoney(source, 'cash', cfg.BasePayment, 'reparation-mecano')
  end)
  pcall(function()
    exports['sl-skills']:AddXP(source, 'mechanic', cfg.XpPerRepair)
  end)
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Vehicule repare : +$%d'):format(cfg.BasePayment),
    type = 'success',
  })
  return true
end)

-- ===========================================================================
-- Vente ble au moulin
-- ===========================================================================
lib.callback.register('sl-jobmissions:farmer:sell', function(source, amount)
  if type(amount) ~= 'number' or amount <= 0 then return false, 0 end
  amount = math.floor(amount)
  local cfg = JobMissions.Farmer
  -- Verifier stock
  local hasEnough = false
  pcall(function()
    hasEnough = exports['sl-inventory']:HasItem(source, cfg.HarvestItem, amount)
  end)
  if not hasEnough then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Ble insuffisant.', type = 'error' })
    return false, 0
  end
  -- Retirer
  local removed = false
  pcall(function()
    removed = exports['sl-inventory']:RemoveItem(source, cfg.HarvestItem, amount, nil, 'vente-ble')
  end)
  if not removed then return false, 0 end
  local gain = amount * cfg.PricePerKg
  pcall(function()
    exports['sl-economy']:AddMoney(source, 'cash', gain, 'vente-ble')
  end)
  pcall(function()
    exports['sl-skills']:AddXP(source, 'farming', cfg.XpPerSell * amount)
  end)
  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Ble vendu (%d kg) : +$%d'):format(amount, gain),
    type = 'success',
  })
  return true, gain
end)

-- ===========================================================================
-- Plantation : consomme une graine de ble (autoritatif serveur)
-- Le client ne peut pas retirer un item lui-meme (pas d export RemoveItem client)
-- ===========================================================================
lib.callback.register('sl-jobmissions:farmer:plant', function(source)
  local cfg = JobMissions.Farmer
  local hasSeed = false
  pcall(function()
    hasSeed = exports['sl-inventory']:HasItem(source, cfg.SeedItem, 1)
  end)
  if not hasSeed then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Pas de graines de ble.', type = 'error' })
    return false
  end
  local removed = false
  pcall(function()
    removed = exports['sl-inventory']:RemoveItem(source, cfg.SeedItem, 1, nil, 'plantation-ble')
  end)
  return removed == true
end)

-- ===========================================================================
-- Donner item ble apres recolte (appel depuis client)
-- ===========================================================================
lib.callback.register('sl-jobmissions:farmer:harvest', function(source)
  local cfg = JobMissions.Farmer
  local canCarry = true
  pcall(function()
    canCarry = exports['sl-inventory']:CanCarry(source, cfg.HarvestItem, cfg.HarvestGive)
  end)
  if not canCarry then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Inventaire plein.', type = 'error' })
    return false
  end
  local added = false
  pcall(function()
    added = exports['sl-inventory']:AddItem(source, cfg.HarvestItem, cfg.HarvestGive, nil, 'recolte-champ')
  end)
  if added then
    pcall(function()
      exports['sl-skills']:AddXP(source, 'farming', cfg.XpPerHarvest)
    end)
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('+%d ble recolte'):format(cfg.HarvestGive),
      type = 'success',
    })
    return true
  end
  return false
end)

-- ===========================================================================
-- Cleanup au drop joueur
-- (pas de cache serveur, tout est client-side runtime)
-- ===========================================================================
AddEventHandler('sl:core:playerDropped', function(payload)
  -- rien a persister, les missions sont runtime pur
end)
