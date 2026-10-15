print('[sl-inventory/server] api.lua loaded')

-- ===========================================================================
-- API publique : AddItem, RemoveItem, GetItem, HasItem, GetItems, MoveItem,
-- UseItem, GetWeight, GetMaxWeight, CanCarry, FindFirstSlot, GiveJobKit,
-- + callbacks ox_lib pour l'UI.
--
-- Plages de slots :
--   1   .. 30  : inventaire principal (grille 6×5)
--   201 .. 205 : paper-doll équipement (sac, holster, phone, radio, docs)
-- ===========================================================================

-- ============= utilitaires bas niveau =============

local function getEntry(source)
  local c = Cache[source]
  if not c then return nil, 'inventory not loaded' end
  return c, nil
end

local function copyMetadata(meta)
  if type(meta) ~= 'table' then return nil end
  local out = {}
  for k, v in pairs(meta) do out[k] = v end
  return out
end

-- 2 stacks sont "identiques" si même item ET même metadata.
local function metadataEqual(a, b)
  if a == nil and b == nil then return true end
  if a == nil or b == nil then
    if a and next(a) == nil and b == nil then return true end
    if b and next(b) == nil and a == nil then return true end
    return false
  end
  if type(a) ~= 'table' or type(b) ~= 'table' then return false end
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k, v in pairs(b) do if a[k] ~= v then return false end end
  return true
end

local function computeWeight(slots)
  local w = 0
  for _, s in pairs(slots) do
    if s and s.item then
      w = w + (Items.Weight(s.item) * (s.count or 0))
    end
  end
  return w
end

-- ============= validation slots =============

-- Slot valide = grille (1..30) OU paper-doll (201..205).
local function isValidSlot(slot)
  slot = tonumber(slot); if not slot then return false end
  if slot >= 1 and slot <= Inventory.SlotCount then return true end
  for _, s in pairs(Inventory.EquipmentSlots) do if s == slot then return true end end
  return false
end

-- Vérifie qu'un item peut entrer dans `slot` (paper-doll uniquement contraint).
-- Renvoie true, nil si OK ; false, msg sinon.
local function slotAccepts(slot, itemName)
  local rule = Inventory.EquipmentRules and Inventory.EquipmentRules[slot]
  if not rule then return true end
  local def = Items.Get(itemName)
  if not def then return false, 'item inconnu' end

  if rule.items then
    for _, n in pairs(rule.items) do
      if tostring(n) == tostring(itemName) then return true end
    end
  end
  if rule.categories then
    for _, c in pairs(rule.categories) do
      if tostring(c) == tostring(def.category) then return true end
    end
  end

  local label = rule.label or ('slot ' .. tostring(slot))
  return false, ("le slot « %s » n'accepte pas cet item"):format(label)
end

-- ============= capacité (poids max) — dynamique selon équipement =============

function InventoryGetMaxWeight(source)
  local base = Inventory.MaxWeight or 40000
  local entry = Cache[source]; if not entry then return base end
  local bp = entry.slots[Inventory.EquipmentSlots.backpack]
  if bp and bp.item == 'sac_dos' then
    return base + (Inventory.BackpackBonus or 0)
  end
  return base
end

-- ============= recherche slots libres / empilage (inventaire principal) =============

local function nextFreeSlot(slots)
  for i = 1, Inventory.SlotCount do
    if slots[i] == nil then return i end
  end
  return nil
end

local function findStackableSlot(slots, item, metadata)
  if Items.IsUnique(item) then return nil end
  local maxStack = Items.MaxStack(item)
  if maxStack <= 1 then return nil end
  for i = 1, Inventory.SlotCount do
    local s = slots[i]
    if s and s.item == item
       and (s.count or 0) < maxStack
       and metadataEqual(s.metadata, metadata)
    then
      return i, maxStack - (s.count or 0)
    end
  end
  return nil
end

-- ============= AddItem =============

function InventoryAddItem(source, item, count, metadata, reason)
  if not Items.Exists(item) then return false, 'unknown item: ' .. tostring(item) end
  count = math.floor(tonumber(count) or 0)
  if count <= 0 then return false, 'count must be > 0' end

  local entry, err = getEntry(source)
  if not entry then return false, err end
  local slots = entry.slots

  local addWeight = Items.Weight(item) * count
  if computeWeight(slots) + addWeight > InventoryGetMaxWeight(source) then
    return false, 'too heavy'
  end

  local maxStack = Items.MaxStack(item)
  local isUnique = Items.IsUnique(item)
  local remaining = count

  if not isUnique and maxStack > 1 then
    while remaining > 0 do
      local slotIdx, space = findStackableSlot(slots, item, metadata)
      if not slotIdx then break end
      local toAdd = math.min(space, remaining)
      slots[slotIdx].count = (slots[slotIdx].count or 0) + toAdd
      PersistSlot(entry.characterId, slotIdx, slots[slotIdx])
      remaining = remaining - toAdd
    end
  end

  while remaining > 0 do
    local slotIdx = nextFreeSlot(slots)
    if not slotIdx then return false, 'no free slot' end
    local toAdd = isUnique and 1 or math.min(maxStack, remaining)
    slots[slotIdx] = {
      item = item,
      count = toAdd,
      metadata = copyMetadata(metadata),
    }
    PersistSlot(entry.characterId, slotIdx, slots[slotIdx])
    remaining = remaining - toAdd
  end

  TriggerEvent('sl:inventory:itemAdded', {
    source = source, characterId = entry.characterId,
    item = item, count = count, metadata = metadata, reason = reason,
  })
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:inventory:itemAdded', {
    item = item, count = count, reason = reason,
  })
  PushInventoryToClient(source)
  return true
end

-- ============= RemoveItem =============

function InventoryRemoveItem(source, item, count, metadata, reason)
  if not Items.Exists(item) then return false, 'unknown item' end
  count = math.floor(tonumber(count) or 0)
  if count <= 0 then return false, 'count must be > 0' end

  local entry, err = getEntry(source)
  if not entry then return false, err end
  local slots = entry.slots

  local owned = 0
  for _, s in pairs(slots) do
    if s and s.item == item then
      if metadata == nil or metadataEqual(s.metadata, metadata) then
        owned = owned + (s.count or 0)
      end
    end
  end
  if owned < count then return false, 'insufficient items' end

  local remaining = count
  -- on retire d'abord depuis l'inventaire principal, puis équipement.
  local order = {}
  for i = 1, Inventory.SlotCount do order[#order+1] = i end
  for _, i in pairs(Inventory.EquipmentSlots) do order[#order+1] = i end

  for _, i in ipairs(order) do
    if remaining <= 0 then break end
    local s = slots[i]
    if s and s.item == item then
      if metadata == nil or metadataEqual(s.metadata, metadata) then
        local take = math.min(remaining, s.count or 0)
        s.count = (s.count or 0) - take
        remaining = remaining - take
        if s.count <= 0 then
          slots[i] = nil
          PersistDelete(entry.characterId, i)
        else
          PersistSlot(entry.characterId, i, s)
        end
      end
    end
  end

  TriggerEvent('sl:inventory:itemRemoved', {
    source = source, characterId = entry.characterId,
    item = item, count = count, metadata = metadata, reason = reason,
  })
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:inventory:itemRemoved', {
    item = item, count = count, reason = reason,
  })
  PushInventoryToClient(source)
  return true
end

-- ============= Queries =============

function InventoryGetItem(source, item)
  local entry = Cache[source]; if not entry then return 0 end
  local total = 0
  for _, s in pairs(entry.slots) do
    if s and s.item == item then total = total + (s.count or 0) end
  end
  return total
end

function InventoryHasItem(source, item, count)
  count = math.floor(tonumber(count) or 1)
  return InventoryGetItem(source, item) >= count
end

function InventoryGetItems(source)
  local entry = Cache[source]; if not entry then return {} end
  local out = {}
  for slotIdx, s in pairs(entry.slots) do
    out[#out+1] = {
      slot = slotIdx, item = s.item, count = s.count,
      metadata = copyMetadata(s.metadata),
    }
  end
  table.sort(out, function(a,b) return (a.slot or 0) < (b.slot or 0) end)
  return out
end

function InventoryGetWeight(source)
  local entry = Cache[source]; if not entry then return 0 end
  return computeWeight(entry.slots)
end

function InventoryCanCarry(source, item, count)
  if not Items.Exists(item) then return false end
  count = math.floor(tonumber(count) or 1)
  local entry = Cache[source]; if not entry then return false end
  local addW = Items.Weight(item) * count
  return computeWeight(entry.slots) + addW <= InventoryGetMaxWeight(source)
end

function InventoryGetEquipmentSlot(source, kind)
  local idx = Inventory.EquipmentSlots and Inventory.EquipmentSlots[kind]
  if not idx then return nil end
  local entry = Cache[source]; if not entry then return nil end
  return entry.slots[idx]
end

-- ============= MoveItem (swap / merge / equip) =============

function InventoryMoveItem(source, fromSlot, toSlot, count)
  local entry, err = getEntry(source); if not entry then return false, err end
  fromSlot = tonumber(fromSlot); toSlot = tonumber(toSlot)
  if not fromSlot or not toSlot then return false, 'invalid slots' end
  if fromSlot == toSlot then return false, 'same slot' end
  if not isValidSlot(fromSlot) then return false, 'fromSlot out of bounds' end
  if not isValidSlot(toSlot) then return false, 'toSlot out of bounds' end

  local from = entry.slots[fromSlot]
  if not from then return false, 'source empty' end

  -- Contrainte d'équipement sur la destination
  local ok, msg = slotAccepts(toSlot, from.item)
  if not ok then return false, msg end

  local to = entry.slots[toSlot]
  count = math.floor(tonumber(count) or from.count or 1)
  if count <= 0 then return false, 'count must be > 0' end
  if count > (from.count or 0) then count = from.count end

  if not to then
    if count == (from.count or 0) then
      entry.slots[toSlot] = from
      entry.slots[fromSlot] = nil
      PersistSlot(entry.characterId, toSlot, entry.slots[toSlot])
      PersistDelete(entry.characterId, fromSlot)
    else
      entry.slots[toSlot] = {
        item = from.item, count = count,
        metadata = copyMetadata(from.metadata),
      }
      from.count = from.count - count
      PersistSlot(entry.characterId, toSlot, entry.slots[toSlot])
      PersistSlot(entry.characterId, fromSlot, from)
    end
  else
    -- swap : l'item DE destination doit aussi être accepté à fromSlot
    local okBack, msgBack = slotAccepts(fromSlot, to.item)
    if to.item == from.item
       and not Items.IsUnique(from.item)
       and metadataEqual(to.metadata, from.metadata)
    then
      local maxStack = Items.MaxStack(from.item)
      local space = maxStack - (to.count or 0)
      local merge = math.min(space, count)
      if merge <= 0 then
        if not okBack then return false, msgBack end
        entry.slots[toSlot], entry.slots[fromSlot] = from, to
        PersistSlot(entry.characterId, toSlot, entry.slots[toSlot])
        PersistSlot(entry.characterId, fromSlot, entry.slots[fromSlot])
      else
        to.count = to.count + merge
        from.count = from.count - merge
        PersistSlot(entry.characterId, toSlot, to)
        if from.count <= 0 then
          entry.slots[fromSlot] = nil
          PersistDelete(entry.characterId, fromSlot)
        else
          PersistSlot(entry.characterId, fromSlot, from)
        end
      end
    else
      if count ~= (from.count or 0) then return false, 'cannot split onto occupied slot' end
      if not okBack then return false, msgBack end
      entry.slots[toSlot], entry.slots[fromSlot] = from, to
      PersistSlot(entry.characterId, toSlot, entry.slots[toSlot])
      PersistSlot(entry.characterId, fromSlot, entry.slots[fromSlot])
    end
  end

  PushInventoryToClient(source)
  return true
end

-- ============= UseItem =============

function InventoryUseItem(source, slot)
  local entry, err = getEntry(source); if not entry then return false, err end
  slot = tonumber(slot)
  local s = slot and entry.slots[slot]
  if not s then return false, 'empty slot' end
  if not Items.IsUsable(s.item) then return false, 'not usable' end

  local def = Items.Get(s.item)
  local effect = def.useEffect or { type = 'noop' }
  local consume = false

  if effect.type == 'food' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'food', value = effect.value })
    consume = true
  elseif effect.type == 'drink' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'drink', value = effect.value })
    consume = true
  elseif effect.type == 'alcohol' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'alcohol', value = effect.value })
    consume = true
  elseif effect.type == 'heal' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'heal', value = effect.value })
    if effect.consume ~= false then consume = true end
  elseif effect.type == 'show_id' or effect.type == 'show_license' or effect.type == 'show_badge' then
    TriggerClientEvent('sl-inventory:effect', source, {
      type = effect.type, text = effect.text, kind = effect.kind, metadata = s.metadata,
    })
  elseif effect.type == 'open_phone' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'open_phone', metadata = s.metadata })
  elseif effect.type == 'vehicle_key' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'vehicle_key', metadata = s.metadata })
  elseif effect.type == 'house_key' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'house_key', metadata = s.metadata })
  elseif effect.type == 'tool' then
    TriggerClientEvent('sl-inventory:effect', source, { type = 'tool', tool = effect.tool, metadata = s.metadata })
  end

  if consume then
    s.count = (s.count or 1) - 1
    if s.count <= 0 then
      entry.slots[slot] = nil
      PersistDelete(entry.characterId, slot)
    else
      PersistSlot(entry.characterId, slot, s)
    end
    PushInventoryToClient(source)
  end

  TriggerEvent('sl:inventory:itemUsed', {
    source = source, characterId = entry.characterId,
    item = s.item, slot = slot, metadata = s.metadata, consumed = consume,
  })
  return true
end

-- ============= Drop slot =============

function InventoryDropSlot(source, slot, count)
  local entry, err = getEntry(source); if not entry then return false, err end
  slot = tonumber(slot)
  local s = slot and entry.slots[slot]; if not s then return false, 'empty' end
  count = math.floor(tonumber(count) or s.count or 1)
  if count <= 0 or count > (s.count or 0) then count = s.count end

  s.count = s.count - count
  if s.count <= 0 then
    entry.slots[slot] = nil
    PersistDelete(entry.characterId, slot)
  else
    PersistSlot(entry.characterId, slot, s)
  end

  TriggerEvent('sl:inventory:itemDropped', {
    source = source, characterId = entry.characterId,
    item = s.item, count = count, slot = slot,
  })
  PushInventoryToClient(source)
  return true
end

-- ============= Kit métier =============

function InventoryGiveJobKit(source, jobName)
  local kit = Inventory.DutyKits[jobName]
  if not kit then return false, 'no kit for ' .. tostring(jobName) end
  for _, k in ipairs(kit) do
    if InventoryGetItem(source, k.item) <= 0 then
      InventoryAddItem(source, k.item, k.count or 1, k.metadata, 'duty:'..jobName)
    end
  end
  return true
end

function InventoryRemoveJobKit(source, jobName)
  local kit = Inventory.DutyKits[jobName]
  if not kit then return false end
  for _, k in ipairs(kit) do
    local owned = InventoryGetItem(source, k.item)
    if owned > 0 then
      InventoryRemoveItem(source, k.item, math.min(owned, k.count or 1), k.metadata, 'duty:off')
    end
  end
  return true
end

-- ============= Payload builder (utilisé par PushInventoryToClient) =============

function BuildInventoryPayload(source)
  local entry = Cache[source]
  if not entry then return nil end

  -- Un seul map `slots` regroupant tout (1..30, 201..205).
  -- IMPORTANT : clés stringifiées pour forcer cjson à produire un OBJET JSON
  -- (pas un array). Sans ça, des slots denses 1,2,3 deviennent un array JS
  -- indexé à partir de 0 → décalage côté client → mauvais slot référencé.
  local allSlots = {}
  for idx, s in pairs(entry.slots) do
    allSlots[tostring(idx)] = s
  end

  local equipment = {}
  for kind, idx in pairs(Inventory.EquipmentSlots) do
    equipment[kind] = { slot = idx, content = entry.slots[idx] }
  end

  -- Tableau « rules » sérialisable pour la NUI : map slot -> {items, categories, label}
  local rules = {}
  if Inventory.EquipmentRules then
    for slot, rule in pairs(Inventory.EquipmentRules) do
      rules[tostring(slot)] = {
        items = rule.items, categories = rule.categories, label = rule.label,
      }
    end
  end

  return {
    slots          = allSlots,
    equipment      = equipment,
    slotCount      = Inventory.SlotCount,
    equipmentSlots = Inventory.EquipmentSlots,
    rules          = rules,
    weight         = computeWeight(entry.slots),
    maxWeight      = InventoryGetMaxWeight(source),
    catalog        = Items.List(),
    nearby         = nil,   -- prêt pour v2 (drops/coffre véhicule)
  }
end

-- ============= Exports publics =============

exports('AddItem',           InventoryAddItem)
exports('RemoveItem',        InventoryRemoveItem)
exports('GetItem',           InventoryGetItem)
exports('HasItem',           InventoryHasItem)
exports('GetItems',          InventoryGetItems)
exports('GetWeight',         InventoryGetWeight)
exports('GetMaxWeight',      InventoryGetMaxWeight)
exports('CanCarry',          InventoryCanCarry)
exports('MoveItem',          InventoryMoveItem)
exports('UseItem',           InventoryUseItem)
exports('DropSlot',          InventoryDropSlot)
exports('GiveJobKit',        InventoryGiveJobKit)
exports('RemoveJobKit',      InventoryRemoveJobKit)
exports('GetCatalog',        function() return Items.List() end)
exports('GetEquipmentSlot',  InventoryGetEquipmentSlot)
exports('IsValidSlot',       isValidSlot)

-- ============= Callbacks ox_lib (client → server) =============

lib.callback.register('sl-inventory:getState', function(source)
  return BuildInventoryPayload(source)
end)

lib.callback.register('sl-inventory:move', function(source, fromSlot, toSlot, count)
  local ok, err = InventoryMoveItem(source, fromSlot, toSlot, count)
  return ok, err
end)

lib.callback.register('sl-inventory:use', function(source, slot)
  local ok, err = InventoryUseItem(source, slot)
  return ok, err
end)

lib.callback.register('sl-inventory:drop', function(source, slot, count)
  local ok, err = InventoryDropSlot(source, slot, count)
  return ok, err
end)

-- ============= Hook sl-jobs : donne/retire le kit en fonction du duty =============

AddEventHandler('sl:jobs:dutyChanged', function(payload)
  if not payload or not payload.source or not payload.name then return end
  local source = payload.source
  local jobName = payload.name
  if not Inventory.DutyKits[jobName] then return end

  if payload.onDuty then
    local ok = InventoryGiveJobKit(source, jobName)
    if ok then
      TriggerClientEvent('ox_lib:notify', source, {
        description = ('Kit %s remis'):format(jobName),
        type = 'success',
      })
    end
  else
    InventoryRemoveJobKit(source, jobName)
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Kit %s rendu'):format(jobName),
      type = 'inform',
    })
  end
end)

AddEventHandler('sl:jobs:jobChanged', function(payload)
  -- ce handler reçoit le NOUVEAU job ; on n'a pas le précédent.
  -- sl-jobs setJob force déjà onDuty=false, ce qui retire l'ancien kit.
end)
