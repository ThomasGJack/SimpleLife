print('[sl-ems/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, citizenId, onDuty, reviveCooldowns }
-- reviveCooldowns : { [targetSrc] = timestamp }
-- ===========================================================================
Cache = Cache or {}

local function tryIsReady()
  local ok, ready = pcall(function() return SL:IsReady() end)
  return ok and ready == true
end

local registered = false
local function registerSelf()
  if registered then return end
  registered = true
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  SL:RegisterModule({
    name    = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps    = { 'sl-core@^0.1', 'sl-death@^0.1', 'sl-jobs@^0.1', 'sl-inventory@^0.1', 'sl-economy@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Hydration / cleanup
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source then return end
  local source     = payload.source
  local characterId = payload.characterId
  local citizenId   = payload.citizenId

  -- Recupere le job actuel pour savoir si on duty ambulance
  local onDuty = false
  local ok, jobInfo = pcall(function() return exports['sl-jobs']:GetJob(source) end)
  if ok and jobInfo and jobInfo.name == EMS.JobName and jobInfo.onDuty then
    onDuty = true
  end

  Cache[source] = {
    characterId     = characterId,
    citizenId       = citizenId,
    onDuty          = onDuty,
    reviveCooldowns = {},
  }
  print(('[sl-ems] hydrated src=%d cid=%d'):format(source, characterId or 0))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    Cache[payload.source] = nil
  end
end)

-- ===========================================================================
-- Hook : duty changed (sl-jobs emet cet event cote serveur)
-- ===========================================================================
AddEventHandler('sl:jobs:dutyChanged', function(payload)
  if not payload or not payload.source then return end
  local source = payload.source
  local entry  = Cache[source]
  if not entry then return end

  entry.onDuty = (payload.name == EMS.JobName and payload.onDuty == true)

  -- Donne le kit EMS si prise de service ambulancier
  if entry.onDuty then
    local kitOk, kitErr = pcall(function()
      exports['sl-inventory']:GiveJobKit(source, EMS.JobName)
    end)
    if not kitOk then
      print(('[sl-ems] GiveJobKit error: %s'):format(tostring(kitErr)))
    end
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Kit EMS recu. Bonne intervention.',
      type = 'success',
    })
  end
end)

-- ===========================================================================
-- Helpers internes
-- ===========================================================================
local function getEntry(source)
  local c = Cache[source]
  if not c then return nil, 'ems not loaded' end
  return c
end

local function checkReviveCooldown(medicSrc, targetSrc)
  local entry = Cache[medicSrc]
  if not entry then return true end
  local cd = entry.reviveCooldowns[targetSrc]
  if cd and (os.time() - cd) < EMS.ReviveCooldown then
    return false, EMS.ReviveCooldown - (os.time() - cd)
  end
  return true
end

local function setReviveCooldown(medicSrc, targetSrc)
  local entry = Cache[medicSrc]
  if not entry then return end
  entry.reviveCooldowns[targetSrc] = os.time()
end

function GetCacheEntry(source) return Cache[source] end

-- ===========================================================================
-- Heal target via dispatch cote client (applique HP)
-- ===========================================================================
local function applyHealthToTarget(targetSrc, amount)
  TriggerClientEvent('sl:bus:dispatch', targetSrc, 'sl:ems:applyHealth', { amount = amount })
end

-- ===========================================================================
-- Export : GetInjuries(src) -> table zones + gravite basee sur HP
-- ===========================================================================
local function computeInjuries(source)
  -- On ne peut pas lire le HP GTA depuis le serveur directement sans callback,
  -- donc on utilise un callback client ou on stocke la derniere valeur connue.
  -- Ici, on fait un callback asynchrone puis retourne via event.
  -- Mais comme GetInjuries est un export synchrone (appele serveur->serveur),
  -- on utilise les donnees de sante stockees via l'event sl:ems:reportHealth.
  local entry = Cache[source]
  if not entry then return {} end

  local hp = entry.lastKnownHealth or 200
  local injuries = {}

  for _, zone in ipairs(EMS.BodyZones) do
    -- Simule la gravite : on distribue aleatoirement basee sur HP global
    -- (en production on utiliserait un systeme de degats par zone)
    local zoneHp = hp + math.random(-20, 20)
    zoneHp = math.max(0, math.min(200, zoneHp))

    local severity = EMS.InjurySeverity[#EMS.InjurySeverity]
    for _, s in ipairs(EMS.InjurySeverity) do
      if zoneHp >= s.threshold then
        severity = s
        break
      end
    end

    injuries[#injuries + 1] = {
      zone     = zone.id,
      label    = zone.label,
      severity = severity.label,
      color    = severity.color,
      hp       = zoneHp,
    }
  end

  return injuries
end

-- Client signale son HP periodiquement
RegisterNetEvent('sl:ems:reportHealth', function(hp)
  local source = source
  local entry = Cache[source]
  if entry then
    entry.lastKnownHealth = tonumber(hp) or 200
  end
end)

-- ===========================================================================
-- Export : ReviveTarget(medicSrc, targetSrc)
-- Appele par client/commands apres la barre de progression
-- ===========================================================================
function DoRevive(medicSrc, targetSrc)
  local medicEntry = getEntry(medicSrc)
  if not medicEntry then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Donnees EMS non chargees.', type = 'error' })
    return false, 'not loaded'
  end

  -- Verifie cooldown
  local ok, remaining = checkReviveCooldown(medicSrc, targetSrc)
  if not ok then
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = ('Cooldown revive : %ds restants.'):format(remaining),
      type = 'error' })
    return false, 'cooldown'
  end

  -- Appelle sl-death:Revive
  local revOk, revErr = pcall(function()
    exports['sl-death']:Revive(targetSrc)
  end)
  if not revOk then
    print(('[sl-ems] Revive error: %s'):format(tostring(revErr)))
    TriggerClientEvent('ox_lib:notify', medicSrc, {
      description = 'Impossible de reveiller ce joueur.', type = 'error' })
    return false, 'revive_failed'
  end

  -- Stop le saignement
  pcall(function() exports['sl-death']:SetBleed(targetSrc, 0) end)

  -- Cooldown
  setReviveCooldown(medicSrc, targetSrc)

  -- Notifs
  TriggerClientEvent('ox_lib:notify', medicSrc, {
    description = 'Patient reveille avec succes.', type = 'success' })
  TriggerClientEvent('ox_lib:notify', targetSrc, {
    description = 'Un medecin vous a ranime.', type = 'success' })

  -- XP medical : delegue a sl-skills via le bus event 'sl:ems:revivedTarget'
  -- (consommateur officiel du contrat). On NE rappelle PAS AddXP ici pour
  -- eviter un double credit.

  -- Event bus
  local medicCitizenId = medicEntry.citizenId
  local targetEntry    = Cache[targetSrc]
  local targetCitizenId = targetEntry and targetEntry.citizenId or 0

  TriggerEvent('sl:ems:revivedTarget', {
    medic  = medicSrc,
    target = targetSrc,
    medicCitizenId  = medicCitizenId,
    targetCitizenId = targetCitizenId,
  })

  print(('[sl-ems] Revive: medic=%d target=%d'):format(medicSrc, targetSrc))
  return true
end

-- ===========================================================================
-- Export : HealTarget(medicSrc, targetSrc, amount)
-- ===========================================================================
function DoHeal(medicSrc, targetSrc, amount)
  amount = tonumber(amount) or EMS.DefaultHealAmount

  -- Applique la sante cote client target
  applyHealthToTarget(targetSrc, amount)

  -- Stop le saignement
  pcall(function() exports['sl-death']:SetBleed(targetSrc, 0) end)

  -- Notifs
  TriggerClientEvent('ox_lib:notify', medicSrc, {
    description = ('Soin applique : +%d HP.'):format(amount), type = 'success' })
  TriggerClientEvent('ox_lib:notify', targetSrc, {
    description = 'Vous avez ete soigne par un medecin.', type = 'inform' })

  -- XP medical
  pcall(function()
    exports['sl-skills']:AddXP(medicSrc, 'medical', EMS.XP.heal)
  end)

  print(('[sl-ems] Heal: medic=%d target=%d amount=%d'):format(medicSrc, targetSrc, amount))
  return true
end

-- ===========================================================================
-- Exports publics (appeles cross-resource)
-- ===========================================================================
exports('ReviveTarget', DoRevive)
exports('HealTarget',   DoHeal)
exports('GetInjuries',  computeInjuries)

-- ===========================================================================
-- Event : commande /revivep (medic revive un joueur proche)
-- Emis par le client apres la barre de progression
-- ===========================================================================
RegisterNetEvent('sl:ems:requestRevive', function(targetSrc)
  local medicSrc = source
  DoRevive(medicSrc, targetSrc)
end)

-- ===========================================================================
-- Event : commande /heal (medic soigne un joueur)
-- ===========================================================================
RegisterNetEvent('sl:ems:requestHeal', function(targetSrc, amount)
  local medicSrc = source
  DoHeal(medicSrc, targetSrc, amount)
end)

-- (facturation geree dans api.lua via RegisterNetEvent sl:ems:requestBill)

-- ===========================================================================
-- Callback : liste des blessures pour le MDT
-- ===========================================================================
lib.callback.register('sl-ems:getInjuries', function(source, targetSrc)
  targetSrc = tonumber(targetSrc) or source
  return computeInjuries(targetSrc)
end)

-- ===========================================================================
-- Callback : liste des patients (joueurs downed) pour le MDT
-- ===========================================================================
lib.callback.register('sl-ems:getPatients', function(source)
  local patients = {}
  for src, entry in pairs(Cache) do
    -- Verifie si le joueur est downed via sl-death
    local ok, isDowned = pcall(function()
      return exports['sl-death']:IsDowned(src)
    end)
    if ok and isDowned then
      patients[#patients + 1] = {
        source    = src,
        citizenId = entry.citizenId,
        health    = entry.lastKnownHealth or 0,
      }
    end
  end
  return patients
end)

-- ===========================================================================
-- Callback : obtenir les donnees perso pour le MDT
-- ===========================================================================
lib.callback.register('sl-ems:getSelfData', function(source)
  local entry = Cache[source]
  if not entry then return nil end
  return {
    citizenId = entry.citizenId,
    onDuty    = entry.onDuty,
    injuries  = computeInjuries(source),
  }
end)
