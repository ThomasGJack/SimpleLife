print('[sl-inventory/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache global (clé = source FiveM)
--   Cache[source] = {
--     characterId = <id>,
--     slots       = { [slotIndex] = { id=<rowId?>, item=<name>, count=<n>, metadata=<table> } },
--     dirty       = false,
--   }
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
    name = GetCurrentResourceName(),
    version = '0.1.0',
    coreApi = apiOk and api or 1,
    deps = { 'sl-core@^0.1' },
  })
  print('[sl-inventory] registered against sl-core')
end

-- ===========================================================================
-- Sync catalogue Lua -> table sl_items
-- ===========================================================================
local function syncCatalogToDb()
  local ok, err = pcall(function()
    local db = SL:DB()
    for name, def in pairs(Items.Catalog) do
      db.query([[
        INSERT INTO sl_items (name, label, weight, max_stack, category, is_usable, is_unique, icon, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          label = VALUES(label),
          weight = VALUES(weight),
          max_stack = VALUES(max_stack),
          category = VALUES(category),
          is_usable = VALUES(is_usable),
          is_unique = VALUES(is_unique),
          icon = VALUES(icon),
          description = VALUES(description)
      ]], {
        name,
        def.label or name,
        def.weight or 0,
        def.stack or 1,
        def.category or 'misc',
        def.usable and 1 or 0,
        def.unique and 1 or 0,
        def.icon,
        def.description,
      })
    end
  end)
  if not ok then
    print('[sl-inventory] catalog sync error: ' .. tostring(err))
  else
    local n = 0
    for _ in pairs(Items.Catalog) do n = n + 1 end
    print(('[sl-inventory] catalog synced (%d items)'):format(n))
  end
end

local catalogSynced = false
local function ensureCatalogSynced()
  if catalogSynced then return end
  catalogSynced = true
  CreateThread(function()
    Wait(300)
    syncCatalogToDb()
  end)
end

AddEventHandler('sl:core:ready', function()
  registerSelf()
  ensureCatalogSynced()
end)

CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
  ensureCatalogSynced()
end)

-- ===========================================================================
-- Helpers internes
-- ===========================================================================
local function decodeMetadata(raw)
  if raw == nil then return nil end
  if type(raw) == 'table' then return raw end
  if type(raw) ~= 'string' then return nil end
  if raw == '' or raw == 'null' then return nil end
  local ok, decoded = pcall(json.decode, raw)
  if ok and type(decoded) == 'table' then return decoded end
  return nil
end

local function encodeMetadata(meta)
  if meta == nil then return nil end
  if type(meta) ~= 'table' then return nil end
  if next(meta) == nil then return nil end
  return json.encode(meta)
end

-- Charge tous les slots d'un perso depuis la DB.
local function loadInventory(characterId)
  local rows = SL:DB().query(
    'SELECT id, slot, item, count, metadata FROM sl_inventory_items WHERE character_id = ? ORDER BY slot ASC',
    { characterId }
  ) or {}
  local slots = {}
  for _, r in ipairs(rows) do
    slots[tonumber(r.slot)] = {
      id = r.id,
      item = r.item,
      count = tonumber(r.count) or 0,
      metadata = decodeMetadata(r.metadata),
    }
  end
  return slots
end

local function inventoryIsEmpty(slots)
  for _ in pairs(slots) do return false end
  return true
end

-- Donne les items de démarrage à un perso vide.
local function giveStartingItems(source, characterId, slots)
  if not Inventory.StartingItems or #Inventory.StartingItems == 0 then return end
  for _, entry in ipairs(Inventory.StartingItems) do
    if Items.Exists(entry.item) then
      InventoryAddItem(source, entry.item, entry.count or 1, nil, 'starting-kit')
    end
  end
end

-- Sync vers la NUI client (état complet : grille + équipement).
-- Déléguée à api.lua::BuildInventoryPayload qui structure le payload
-- (et qui n'existe que si api.lua est chargé — fallback minimal sinon).
function PushInventoryToClient(source)
  local c = Cache[source]
  if not c then return end
  local payload
  if type(BuildInventoryPayload) == 'function' then
    payload = BuildInventoryPayload(source)
  end
  if not payload then
    payload = {
      slots = c.slots or {},
      slotCount = Inventory.SlotCount,
      maxWeight = Inventory.MaxWeight,
      catalog = Items.List(),
    }
  end
  TriggerClientEvent('sl-inventory:sync', source, payload)
end

-- ===========================================================================
-- Cycle de vie joueur
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source = payload.source
  local characterId = payload.characterId
  local slots = loadInventory(characterId)

  Cache[source] = {
    characterId = characterId,
    slots = slots,
    dirty = false,
  }

  if inventoryIsEmpty(slots) then
    giveStartingItems(source, characterId, slots)
  end

  print(('[sl-inventory] hydrated src=%d cid=%d slots=%d')
    :format(source, characterId, (function() local n=0; for _ in pairs(Cache[source].slots) do n=n+1 end; return n end)()))

  TriggerClientEvent('sl:bus:dispatch', source, 'sl:inventory:hydrated', { slotCount = Inventory.SlotCount })
  PushInventoryToClient(source)
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if payload and payload.source then
    -- Pas besoin d'écrire ici : tout passe par persistSlot/persistDelete au moment des mutations.
    Cache[payload.source] = nil
  end
end)

-- ===========================================================================
-- Persistance (chaque mutation slot écrit immédiatement)
-- ===========================================================================
function PersistSlot(characterId, slotIndex, entry)
  if not characterId or not slotIndex or not entry then return end
  SL:DB().query([[
    INSERT INTO sl_inventory_items (character_id, slot, item, count, metadata)
    VALUES (?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      item = VALUES(item),
      count = VALUES(count),
      metadata = VALUES(metadata)
  ]], {
    characterId, slotIndex, entry.item, entry.count, encodeMetadata(entry.metadata),
  })
end

function PersistDelete(characterId, slotIndex)
  if not characterId or not slotIndex then return end
  SL:DB().query(
    'DELETE FROM sl_inventory_items WHERE character_id = ? AND slot = ?',
    { characterId, slotIndex }
  )
end

function GetCache(source) return Cache[source] end

-- Stub : InventoryAddItem est défini dans api.lua (chargé après main.lua) ; on
-- déclare ici un fallback pour la phase de starting kit afin d'éviter un nil.
-- api.lua remplace cette table de fonction par la vraie implémentation.
InventoryAddItem = InventoryAddItem or function() return false, 'api not loaded' end
