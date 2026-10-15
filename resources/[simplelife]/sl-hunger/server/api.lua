print('[sl-hunger/server] api.lua loaded')

local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

local function getEntry(source)
  local c = Cache[source]
  if not c then return nil, 'hunger not loaded' end
  return c
end

-- ===========================================================================
-- API publique : Add / Remove / Set / Get
-- ===========================================================================

function HungerAdd(source, value)
  local entry, err = getEntry(source); if not entry then return false, err end
  entry.hunger = clamp((entry.hunger or 0) + math.floor(value or 0), 0, Hunger.MaxValue)
  entry.dirty = true
  SyncToClient(source)
  return true, entry.hunger
end

function ThirstAdd(source, value)
  local entry, err = getEntry(source); if not entry then return false, err end
  entry.thirst = clamp((entry.thirst or 0) + math.floor(value or 0), 0, Hunger.MaxValue)
  entry.dirty = true
  SyncToClient(source)
  return true, entry.thirst
end

function HungerSet(source, value)
  local entry, err = getEntry(source); if not entry then return false, err end
  entry.hunger = clamp(math.floor(value or 0), 0, Hunger.MaxValue)
  entry.dirty = true
  SyncToClient(source)
  return true, entry.hunger
end

function ThirstSet(source, value)
  local entry, err = getEntry(source); if not entry then return false, err end
  entry.thirst = clamp(math.floor(value or 0), 0, Hunger.MaxValue)
  entry.dirty = true
  SyncToClient(source)
  return true, entry.thirst
end

function GetStats(source)
  local entry = Cache[source]
  if not entry then return nil end
  return { hunger = entry.hunger, thirst = entry.thirst, max = Hunger.MaxValue }
end

function RefillAll(source)
  HungerSet(source, Hunger.MaxValue)
  ThirstSet(source, Hunger.MaxValue)
end

exports('AddHunger',  HungerAdd)
exports('AddThirst',  ThirstAdd)
exports('SetHunger',  HungerSet)
exports('SetThirst',  ThirstSet)
exports('GetStats',   GetStats)
exports('RefillAll',  RefillAll)

-- ===========================================================================
-- Hook : sl-inventory consomme un item food/drink → on applique l'effet
--
-- sl-inventory déclenche `sl:inventory:itemUsed` côté server quand un item
-- est utilisé. On lit l'item dans Items.Catalog pour récupérer son useEffect
-- (type + value) et on applique.
-- ===========================================================================
AddEventHandler('sl:inventory:itemUsed', function(payload)
  if not payload or not payload.source or not payload.item then return end
  if not payload.consumed then return end   -- on n'applique l'effet que si l'item est bien consommé

  local def = Items.Get(payload.item)
  if not def or not def.useEffect then return end

  local effect = def.useEffect
  if effect.type == 'food' then
    HungerAdd(payload.source, effect.value or 0)
  elseif effect.type == 'drink' then
    ThirstAdd(payload.source, effect.value or 0)
  elseif effect.type == 'alcohol' then
    -- L'alcool restaure un peu de soif mais ajoute du stress / ivresse (non implémenté en v1)
    ThirstAdd(payload.source, math.floor((effect.value or 0) / 2))
  end
end)

-- ===========================================================================
-- Callback : utilisé par le client au boot pour fetch l'état initial
-- ===========================================================================
lib.callback.register('sl-hunger:getState', function(source)
  return GetStats(source)
end)
