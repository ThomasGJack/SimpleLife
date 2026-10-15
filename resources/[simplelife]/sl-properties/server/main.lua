print('[sl-properties/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, propId (si dans une propriete) }
-- PropOwners : propId -> characterId (cache en memoire)
-- ===========================================================================
Cache      = Cache      or {}   -- joueurs connectes
PropOwners = PropOwners or {}   -- propId -> characterId owner (nil si libre)

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
  seedPropertiesIfEmpty()
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Seed : insere les proprietes de config si la table est vide
-- ===========================================================================
function seedPropertiesIfEmpty()
  local n = SL:DB().scalar('SELECT COUNT(*) FROM sl_properties')
  if (tonumber(n) or 0) > 0 then
    -- Rafraichit le cache owners depuis la DB
    local rows = SL:DB().query('SELECT id, owner_character_id FROM sl_properties', {})
    if rows then
      for _, row in ipairs(rows) do
        PropOwners[tonumber(row.id)] = row.owner_character_id and tonumber(row.owner_character_id) or nil
      end
    end
    print('[sl-properties] table non vide, seed ignore')
    return
  end

  print('[sl-properties] seed initial des proprietes...')
  for _, prop in ipairs(Properties.Catalog) do
    local enterJson    = json.encode({ x = prop.enter_pos.x,    y = prop.enter_pos.y,    z = prop.enter_pos.z })
    local interiorJson = json.encode({
      x = prop.interior_pos.x, y = prop.interior_pos.y,
      z = prop.interior_pos.z, heading = prop.interior_pos.heading or 0.0
    })
    SL:DB().insert(
      'INSERT INTO sl_properties (label, type, price, owner_character_id, enter_pos, ipl, interior_pos) VALUES (?, ?, ?, NULL, ?, ?, ?)',
      { prop.label, prop.type, prop.price, enterJson, prop.ipl, interiorJson }
    )
    PropOwners[prop.id] = nil
  end
  print('[sl-properties] ' .. #Properties.Catalog .. ' proprietes seedees.')
end

-- ===========================================================================
-- Hydration du joueur au characterSelected
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source      = payload.source
  local characterId = payload.characterId
  Cache[source] = {
    characterId = characterId,
    propId      = nil,   -- non dans une propriete au login
  }
  print(('[sl-properties] hydrated src=%d cid=%d'):format(source, characterId))
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    Cache[payload.source] = nil
  end
end)

-- ===========================================================================
-- Helpers
-- ===========================================================================
function GetCharId(source)
  local c = Cache[source]
  return c and c.characterId or nil
end

-- Charge la propriete depuis la DB (par id), retourne nil si inexistante
function LoadProperty(propId)
  local row = SL:DB().single('SELECT * FROM sl_properties WHERE id = ?', { propId })
  if not row then return nil end
  local enter = type(row.enter_pos) == 'string' and json.decode(row.enter_pos) or row.enter_pos
  local inter = type(row.interior_pos) == 'string' and json.decode(row.interior_pos) or row.interior_pos
  return {
    id          = tonumber(row.id),
    label       = row.label,
    type        = row.type,
    price       = tonumber(row.price),
    owner       = row.owner_character_id and tonumber(row.owner_character_id) or nil,
    enter_pos   = enter,
    ipl         = row.ipl,
    interior_pos= inter,
  }
end

-- Retourne toutes les proprietes disponibles (owner NULL)
function GetAvailableProperties()
  local rows = SL:DB().query('SELECT * FROM sl_properties WHERE owner_character_id IS NULL', {})
  local list = {}
  if not rows then return list end
  for _, row in ipairs(rows) do
    local enter = type(row.enter_pos) == 'string' and json.decode(row.enter_pos) or row.enter_pos
    local inter = type(row.interior_pos) == 'string' and json.decode(row.interior_pos) or row.interior_pos
    list[#list + 1] = {
      id         = tonumber(row.id),
      label      = row.label,
      type       = row.type,
      price      = tonumber(row.price),
      enter_pos  = enter,
      ipl        = row.ipl,
      interior_pos = inter,
    }
  end
  return list
end

-- Recupere le catalogue d'items de sl-inventory (pour les poids/icones NUI).
-- Protege par pcall au cas ou sl-inventory ne serait pas demarre.
function GetItemCatalog()
  local ok, cat = pcall(function() return exports['sl-inventory']:GetCatalog() end)
  if ok and type(cat) == 'table' then return cat end
  return {}
end

-- Rafraichit PropOwners[propId]
function RefreshPropOwner(propId)
  local row = SL:DB().single('SELECT owner_character_id FROM sl_properties WHERE id = ?', { propId })
  if row then
    PropOwners[propId] = row.owner_character_id and tonumber(row.owner_character_id) or nil
  end
end

-- ===========================================================================
-- Achat d'une propriete
-- ===========================================================================
RegisterNetEvent('sl:properties:buy', function(propId)
  local source = source
  local cid    = GetCharId(source)
  if not cid then return end

  propId = tonumber(propId)
  local prop = LoadProperty(propId)
  if not prop then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Propriete introuvable.', type = 'error' })
    return
  end
  if prop.owner then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Cette propriete est deja vendue.', type = 'error' })
    return
  end

  local balance = exports['sl-economy']:GetMoney(source, 'bank')
  if not balance or balance < prop.price then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Fonds insuffisants.', type = 'error' })
    return
  end

  local ok = exports['sl-economy']:RemoveMoney(source, 'bank', prop.price, 'achat_propriete_' .. propId)
  if not ok then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Erreur paiement.', type = 'error' })
    return
  end

  SL:DB().update('UPDATE sl_properties SET owner_character_id = ? WHERE id = ?', { cid, propId })
  PropOwners[propId] = cid

  -- Donne la cle_maison
  exports['sl-inventory']:AddItem(source, 'cle_maison', 1, { propId = propId }, 'achat_appartement')

  TriggerClientEvent('ox_lib:notify', source, {
    description = 'Felicitations ! Vous etes proprietaire de : ' .. prop.label,
    type = 'success',
  })
  -- Notifie le client pour rafraichir les zones
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:properties:owned', { propId = propId })
  print(('[sl-properties] achat propId=%d par cid=%d src=%d'):format(propId, cid, source))
end)

-- ===========================================================================
-- Entree / Sortie d'une propriete
-- ===========================================================================
RegisterNetEvent('sl:properties:enter', function(propId)
  local source = source
  local cid    = GetCharId(source)
  if not cid then return end

  propId = tonumber(propId)
  if not HasAccessInternal(source, propId) then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Vous n\'avez pas acces a cette propriete.', type = 'error' })
    return
  end

  local prop = LoadProperty(propId)
  if not prop then return end

  -- Si IPL, on signale au client de le charger
  if Cache[source] then Cache[source].propId = propId end

  TriggerClientEvent('sl:bus:dispatch', source, 'sl:properties:doEnter', {
    propId       = propId,
    label        = prop.label,
    interior_pos = prop.interior_pos,
    ipl          = prop.ipl,
  })
end)

RegisterNetEvent('sl:properties:exit', function(propId)
  local source = source
  propId = tonumber(propId)

  local prop = LoadProperty(propId)
  if not prop then return end

  if Cache[source] then Cache[source].propId = nil end

  TriggerClientEvent('sl:bus:dispatch', source, 'sl:properties:doExit', {
    propId    = propId,
    enter_pos = prop.enter_pos,
  })
end)

-- ===========================================================================
-- Ouverture du coffre
-- ===========================================================================
RegisterNetEvent('sl:properties:openStash', function(propId)
  local source = source
  local cid    = GetCharId(source)
  if not cid then return end

  propId = tonumber(propId)
  if not HasAccessInternal(source, propId) then
    TriggerClientEvent('ox_lib:notify', source, { description = 'Acces refuse.', type = 'error' })
    return
  end

  local prop = LoadProperty(propId)
  if not prop then return end

  local rows = SL:DB().query(
    'SELECT slot, item, count, metadata FROM sl_property_stash WHERE property_id = ?',
    { propId }
  )

  -- Construit une map slot -> contenu (cles string pour JSON dense)
  local slots = {}
  if rows then
    for _, row in ipairs(rows) do
      local s = tostring(tonumber(row.slot))
      slots[s] = {
        item     = row.item,
        count    = tonumber(row.count),
        metadata = row.metadata and (type(row.metadata) == 'string' and json.decode(row.metadata) or row.metadata) or {},
      }
    end
  end

  TriggerClientEvent('sl:bus:dispatch', source, 'sl:properties:stashOpen', {
    propId    = propId,
    label     = prop.label,
    slots     = slots,
    slotCount = Properties.StashSlots,
    maxWeight = Properties.StashMaxWeight,
    catalog   = GetItemCatalog(),
  })
end)

-- ===========================================================================
-- Depot dans le coffre
-- ===========================================================================
lib.callback.register('sl:properties:stashDeposit', function(source, propId, slot, item, count)
  local cid = GetCharId(source)
  if not cid then return false, 'not_loaded' end

  propId = tonumber(propId)
  slot   = tonumber(slot)
  count  = tonumber(count)

  if not HasAccessInternal(source, propId) then return false, 'no_access' end
  if not item or count <= 0 then return false, 'invalid' end

  -- Verifie que le joueur possede l'item
  local hasCount = exports['sl-inventory']:GetItem(source, item)
  if not hasCount or hasCount < count then return false, 'not_enough' end

  -- Verifie le slot cible dans le coffre
  local existing = SL:DB().single(
    'SELECT id, count FROM sl_property_stash WHERE property_id = ? AND slot = ?',
    { propId, slot }
  )
  if existing and existing.item and existing.item ~= item then
    return false, 'slot_occupied'
  end

  -- Retire de l'inventaire joueur
  local ok = exports['sl-inventory']:RemoveItem(source, item, count, nil, 'stash_deposit_prop_' .. propId)
  if not ok then return false, 'remove_failed' end

  -- Insere ou incremente dans le coffre
  if existing then
    SL:DB().update(
      'UPDATE sl_property_stash SET count = count + ? WHERE property_id = ? AND slot = ?',
      { count, propId, slot }
    )
  else
    SL:DB().insert(
      'INSERT INTO sl_property_stash (property_id, slot, item, count, metadata) VALUES (?, ?, ?, ?, NULL)',
      { propId, slot, item, count }
    )
  end

  return true, 'ok'
end)

-- ===========================================================================
-- Retrait depuis le coffre
-- ===========================================================================
lib.callback.register('sl:properties:stashWithdraw', function(source, propId, slot, count)
  local cid = GetCharId(source)
  if not cid then return false, 'not_loaded' end

  propId = tonumber(propId)
  slot   = tonumber(slot)
  count  = tonumber(count)

  if not HasAccessInternal(source, propId) then return false, 'no_access' end

  local row = SL:DB().single(
    'SELECT id, item, count, metadata FROM sl_property_stash WHERE property_id = ? AND slot = ?',
    { propId, slot }
  )
  if not row then return false, 'empty' end

  local available = tonumber(row.count)
  if count > available then count = available end

  -- Verifie poids inventaire
  local canCarry = exports['sl-inventory']:CanCarry(source, row.item, count)
  if not canCarry then return false, 'too_heavy' end

  -- Ajoute a l'inventaire
  local meta = row.metadata and (type(row.metadata) == 'string' and json.decode(row.metadata) or row.metadata) or nil
  local ok = exports['sl-inventory']:AddItem(source, row.item, count, meta, 'stash_withdraw_prop_' .. propId)
  if not ok then return false, 'add_failed' end

  -- Mise a jour du coffre
  if count >= available then
    SL:DB().update('DELETE FROM sl_property_stash WHERE property_id = ? AND slot = ?', { propId, slot })
  else
    SL:DB().update(
      'UPDATE sl_property_stash SET count = count - ? WHERE property_id = ? AND slot = ?',
      { count, propId, slot }
    )
  end

  return true, row.item, count
end)

-- ===========================================================================
-- Callback : liste des proprietes disponibles (NUI agence)
-- ===========================================================================
lib.callback.register('sl:properties:getAvailable', function(source)
  return GetAvailableProperties()
end)

-- Callback : proprietes possedees par le joueur
lib.callback.register('sl:properties:getOwned', function(source)
  local cid = GetCharId(source)
  if not cid then return {} end
  local rows = SL:DB().query(
    'SELECT * FROM sl_properties WHERE owner_character_id = ?', { cid }
  )
  local list = {}
  if rows then
    for _, row in ipairs(rows) do
      local enter = type(row.enter_pos) == 'string' and json.decode(row.enter_pos) or row.enter_pos
      local inter = type(row.interior_pos) == 'string' and json.decode(row.interior_pos) or row.interior_pos
      list[#list + 1] = {
        id           = tonumber(row.id),
        label        = row.label,
        type         = row.type,
        price        = tonumber(row.price),
        enter_pos    = enter,
        interior_pos = inter,
        ipl          = row.ipl,
      }
    end
  end
  return list
end)

-- ===========================================================================
-- Sauvegarde au shutdown
-- ===========================================================================
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  -- Pas d'etat volatile a persister (tout est ecrit en temps reel)
  print('[sl-properties] resource stopped, pas de flush necessaire.')
end)
