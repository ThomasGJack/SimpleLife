print('[sl-crime/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, citizenId }
-- ===========================================================================
Cache = Cache or {}

-- Plants actifs : plantId -> { characterId, kind, coords, grownAt, ownedBy }
Plants = Plants or {}
local nextPlantId = 1

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
    deps    = { 'sl-core@^0.1', 'sl-economy@^0.1', 'sl-inventory@^0.1', 'sl-interact@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- characterSelected / playerDropped
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  Cache[payload.source] = {
    characterId = payload.characterId,
    citizenId   = payload.citizenId,
  }
  print(('[sl-crime] hydrated src=%d cid=%d'):format(payload.source, payload.characterId))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    Cache[payload.source] = nil
  end
end)

-- ===========================================================================
-- Helpers cooldown
-- ===========================================================================
local function nowTs()
  return math.floor(os.time())
end

local function setCooldown(kind, target, minutes)
  local untilTs = nowTs() + (minutes * 60)
  local db = SL:DB()
  -- Upsert : on supprime puis on insere pour eviter l'ON DUPLICATE KEY (portabilite)
  db.update(
    'DELETE FROM sl_crime_cooldowns WHERE kind = ? AND target = ?',
    { kind, tostring(target) }
  )
  db.insert(
    'INSERT INTO sl_crime_cooldowns (kind, target, until_ts) VALUES (?, ?, ?)',
    { kind, tostring(target), untilTs }
  )
end

local function isOnCooldown(kind, target)
  local db = SL:DB()
  local row = db.single(
    'SELECT until_ts FROM sl_crime_cooldowns WHERE kind = ? AND target = ?',
    { kind, tostring(target) }
  )
  if not row then return false end
  return tonumber(row.until_ts) > nowTs()
end

local function getRemainingSeconds(kind, target)
  local db = SL:DB()
  local row = db.single(
    'SELECT until_ts FROM sl_crime_cooldowns WHERE kind = ? AND target = ?',
    { kind, tostring(target) }
  )
  if not row then return 0 end
  local rem = tonumber(row.until_ts) - nowTs()
  return rem > 0 and rem or 0
end

-- Nettoyage periodique des cooldowns expires
CreateThread(function()
  while true do
    Wait(300000) -- 5 minutes
    SL:DB().update('DELETE FROM sl_crime_cooldowns WHERE until_ts <= ?', { nowTs() })
  end
end)

-- ===========================================================================
-- BRAQUAGE — callback principal
-- ===========================================================================
lib.callback.register('sl-crime:checkRobbery', function(source, kind, targetId)
  -- kind = 'shop' | 'safe'
  -- targetId = id string de la config (ex: 'market_vinewood')
  local entry = Cache[source]
  if not entry then return { ok = false, reason = 'not_loaded' } end

  -- Cooldown global sur la caisse (pas par joueur, par caisse)
  if isOnCooldown(kind, targetId) then
    local rem = getRemainingSeconds(kind, targetId)
    return { ok = false, reason = 'cooldown', remaining = rem }
  end
  return { ok = true }
end)

lib.callback.register('sl-crime:finishRobbery', function(source, kind, targetId)
  local entry = Cache[source]
  if not entry then return { ok = false, reason = 'not_loaded' } end

  -- Re-verif cooldown (anti-exploit)
  if isOnCooldown(kind, targetId) then
    return { ok = false, reason = 'cooldown' }
  end

  -- Determine la config correspondante
  local cfg = nil
  local list = (kind == 'shop') and Crime.Shops or Crime.Safes
  for _, v in ipairs(list) do
    if v.id == targetId then cfg = v; break end
  end
  if not cfg then return { ok = false, reason = 'unknown_target' } end

  -- Verifie que le joueur a toujours l'item requis
  local hasItem = pcall(function()
    return exports['sl-inventory']:HasItem(source, cfg.requiredItem, 1)
  end)
  -- On tente quand meme mais on retire l'item (lockpick/drill/thermite = consommable)
  local removeOk = pcall(function()
    exports['sl-inventory']:RemoveItem(source, cfg.requiredItem, 1, nil, 'braquage')
  end)

  -- Calcul butin
  local loot = math.random(cfg.lootMin, cfg.lootMax)

  -- Ajoute le cash
  local econOk, econErr = pcall(function()
    exports['sl-economy']:AddMoney(source, 'cash', loot, 'braquage_' .. kind)
  end)
  if not econOk then
    print('[sl-crime] AddMoney error: ' .. tostring(econErr))
    return { ok = false, reason = 'economy_error' }
  end

  -- Set cooldown
  setCooldown(kind, targetId, cfg.cooldownMin)

  -- XP (pcall car sl-skills optionnel)
  pcall(function()
    local xpAmount = (kind == 'safe') and Crime.XP.robberyVault or Crime.XP.robberyCash
    exports['sl-skills']:AddXP(source, 'strength', xpAmount)
  end)

  -- Alerte police via bus
  TriggerEvent('sl:crime:robberyStarted', {
    shop   = targetId,
    source = source,
    coords = cfg.coords,
  })

  print(('[sl-crime] braquage %s/%s src=%d loot=%d'):format(kind, targetId, source, loot))
  return { ok = true, loot = loot }
end)

-- ===========================================================================
-- DROGUE — planter
-- ===========================================================================
lib.callback.register('sl-crime:plantSeed', function(source, coords)
  local entry = Cache[source]
  if not entry then return { ok = false, reason = 'not_loaded' } end

  -- Verifie item weed_seed
  local hasItem = false
  pcall(function()
    hasItem = exports['sl-inventory']:HasItem(source, 'weed_seed', 1)
  end)
  if not hasItem then
    return { ok = false, reason = 'no_seed' }
  end

  -- Limite max plants par joueur
  local count = 0
  for _, p in pairs(Plants) do
    if p.ownedBy == source then count = count + 1 end
  end
  if count >= (Crime.Drugs.MaxPlantsPerPlayer or 6) then
    return { ok = false, reason = 'max_plants' }
  end

  -- Retire la graine
  pcall(function()
    exports['sl-inventory']:RemoveItem(source, 'weed_seed', 1, nil, 'plant')
  end)

  -- Enregistre le plant
  local pid = nextPlantId
  nextPlantId = nextPlantId + 1
  Plants[pid] = {
    id          = pid,
    characterId = entry.characterId,
    ownedBy     = source,
    coords      = coords,
    grownAt     = nowTs() + (Crime.Drugs.GrowTimeSec or 600),
    harvested   = false,
  }

  print(('[sl-crime] plant#%d src=%d coords=%.1f/%.1f/%.1f grownAt=%d')
    :format(pid, source, coords.x, coords.y, coords.z, Plants[pid].grownAt))

  return { ok = true, plantId = pid, grownAt = Plants[pid].grownAt }
end)

-- ===========================================================================
-- DROGUE — recolter
-- ===========================================================================
lib.callback.register('sl-crime:harvestPlant', function(source, plantId)
  local entry = Cache[source]
  if not entry then return { ok = false, reason = 'not_loaded' } end

  local plant = Plants[plantId]
  if not plant then return { ok = false, reason = 'no_plant' } end
  if plant.harvested then return { ok = false, reason = 'already_harvested' } end
  if plant.ownedBy ~= source then
    -- On permet la recolte par n'importe qui (vol possible)
  end

  if nowTs() < plant.grownAt then
    local rem = plant.grownAt - nowTs()
    return { ok = false, reason = 'not_ready', remaining = rem }
  end

  -- Recolte
  plant.harvested = true
  local amount = math.random(Crime.Drugs.HarvestMin or 2, Crime.Drugs.HarvestMax or 5)
  pcall(function()
    exports['sl-inventory']:AddItem(source, 'weed_bud', amount, nil, 'harvest')
  end)

  -- Retire le plant de la memoire
  Plants[plantId] = nil

  print(('[sl-crime] harvest plant#%d src=%d amount=%d'):format(plantId, source, amount))
  return { ok = true, amount = amount }
end)

-- Sync des plants au client qui se reconnecte
lib.callback.register('sl-crime:getPlants', function(source)
  local list = {}
  for pid, p in pairs(Plants) do
    list[#list + 1] = {
      id      = pid,
      coords  = { x = p.coords.x, y = p.coords.y, z = p.coords.z },
      grownAt = p.grownAt,
      mine    = (p.ownedBy == source),
    }
  end
  return list
end)

-- ===========================================================================
-- DROGUE — packaging (transformation bud -> packaged)
-- ===========================================================================
lib.callback.register('sl-crime:doPackaging', function(source, packId)
  local entry = Cache[source]
  if not entry then return { ok = false, reason = 'not_loaded' } end

  local cfg = nil
  for _, v in ipairs(Crime.Packaging) do
    if v.id == packId then cfg = v; break end
  end
  if not cfg then return { ok = false, reason = 'unknown_pack' } end

  -- Verifie les inputs
  local hasInput = false
  pcall(function()
    hasInput = exports['sl-inventory']:HasItem(source, cfg.inputItem, cfg.inputCount)
  end)
  if not hasInput then
    return { ok = false, reason = 'not_enough', item = cfg.inputItem, need = cfg.inputCount }
  end

  -- Retire inputs
  pcall(function()
    exports['sl-inventory']:RemoveItem(source, cfg.inputItem, cfg.inputCount, nil, 'packaging')
  end)
  -- Ajoute output
  pcall(function()
    exports['sl-inventory']:AddItem(source, cfg.outputItem, cfg.outputCount, nil, 'packaging')
  end)

  print(('[sl-crime] packaging src=%d %dx%s -> %dx%s')
    :format(source, cfg.inputCount, cfg.inputItem, cfg.outputCount, cfg.outputItem))
  return { ok = true, output = cfg.outputItem, count = cfg.outputCount }
end)

-- ===========================================================================
-- DROGUE — deal (vente a un PNJ)
-- ===========================================================================
lib.callback.register('sl-crime:deal', function(source, zoneId, drugItem)
  local entry = Cache[source]
  if not entry then return { ok = false, reason = 'not_loaded' } end

  -- Trouve la zone
  local zone = nil
  for _, v in ipairs(Crime.DealZones) do
    if v.id == zoneId then zone = v; break end
  end
  if not zone then return { ok = false, reason = 'unknown_zone' } end

  -- Cooldown personnel dans cette zone
  local cdKey = 'deal_' .. tostring(entry.characterId)
  if isOnCooldown('deal', cdKey) then
    local rem = getRemainingSeconds('deal', cdKey)
    return { ok = false, reason = 'cooldown', remaining = rem }
  end

  -- Verifie item
  local hasItem = false
  pcall(function()
    hasItem = exports['sl-inventory']:HasItem(source, drugItem, 1)
  end)
  if not hasItem then
    return { ok = false, reason = 'no_drug' }
  end

  -- Chance achat
  local roll = math.random(1, 100)
  local bought = roll <= (zone.buyChance or 65)

  if bought then
    -- Retire l'item
    pcall(function()
      exports['sl-inventory']:RemoveItem(source, drugItem, 1, nil, 'deal')
    end)
    -- Ajoute l'argent
    local price = (zone.prices and zone.prices[drugItem]) or 100
    pcall(function()
      exports['sl-economy']:AddMoney(source, 'cash', price, 'deal_drug')
    end)
    -- XP
    pcall(function()
      exports['sl-skills']:AddXP(source, 'dealing', Crime.XP.deal or 15)
    end)
    -- Cooldown
    setCooldown('deal', cdKey, zone.cooldownMin or 5)
    -- Bus event
    TriggerEvent('sl:crime:dealCompleted', { source = source, drug = drugItem, amount = 1 })
    -- Risque alerte police
    local alertRoll = math.random(1, 100)
    local alertPolice = alertRoll <= (zone.alertChanceOnBuy or 12)
    if alertPolice then
      TriggerEvent('sl:crime:dealAlert', { source = source, coords = zone.coords })
    end
    print(('[sl-crime] deal OK src=%d drug=%s price=%d alert=%s'):format(source, drugItem, price, tostring(alertPolice)))
    return { ok = true, bought = true, price = price, alertPolice = alertPolice }
  else
    -- Refus : petite chance d'alerte quand meme
    local alertRoll = math.random(1, 100)
    local alertPolice = alertRoll <= (zone.alertChanceOnRefuse or 5)
    if alertPolice then
      TriggerEvent('sl:crime:dealAlert', { source = source, coords = zone.coords })
    end
    return { ok = true, bought = false, alertPolice = alertPolice }
  end
end)

-- Notification police quand deal alerte
AddEventHandler('sl:crime:dealAlert', function(payload)
  -- sl-police peut ecouter cet event pour spawner des unites
  -- On emet aussi vers les clients police si sl-police est present
  local ok = pcall(function()
    local officers = exports['sl-jobs']:GetOnDutyPlayers('police')
    if officers then
      for _, officerSrc in ipairs(officers) do
        TriggerClientEvent('sl:bus:dispatch', officerSrc, 'sl:crime:dealAlert', payload)
      end
    end
  end)
end)

-- ===========================================================================
-- onResourceStop — nettoyage memoire
-- ===========================================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  Plants = {}
  Cache  = {}
end)
