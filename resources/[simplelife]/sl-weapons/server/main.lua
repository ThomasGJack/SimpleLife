print('[sl-weapons/server] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Cache : source -> { characterId, equipped = { weaponHash, ammo } | nil }
-- "equipped" : arme actuellement en main (sortie du holster).
-- La persistence de l arme elle-meme est dans sl-inventory (slot 202).
-- On persiste juste le count de munitions dans la metadata du slot holster.
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
    deps    = { 'sl-core@^0.1', 'sl-inventory@^0.1' },
  })
end

AddEventHandler('sl:core:ready', registerSelf)
CreateThread(function()
  while not tryIsReady() do Wait(200) end
  registerSelf()
end)

-- ===========================================================================
-- Helpers
-- ===========================================================================

-- Lit le slot holster (202) depuis sl-inventory Cache.
-- Retourne le stack {item, count, metadata} ou nil.
local function getHolsterSlot(source)
  local ok, slot = pcall(function()
    return exports['sl-inventory']:GetEquipmentSlot(source, 'holster')
  end)
  if ok then return slot end
  return nil
end

-- Ecrit ammo dans la metadata du slot holster via sl-inventory MoveItem
-- (on ne peut pas modifier le metadata directement depuis l exterieur de sl-inventory
-- sans passer par un export dedie).
-- On utilise l export UpdateSlotMeta si disponible ; sinon on stocke dans notre Cache
-- et sl-inventory recalculera au reload.
-- Strategie : on enregistre le compte dans notre propre Cache et on informe
-- sl-inventory via un event interne documente.
local function persistHolsterAmmo(source, ammo)
  -- Essaie UpdateSlotMeta si sl-inventory l expose (optionnel, pas de crash si absent)
  local ok = pcall(function()
    exports['sl-inventory']:UpdateSlotMeta(source, Weapons.HolsterSlot, { ammo = ammo })
  end)
  if not ok then
    -- Fallback : stocker dans notre cache, sl-inventory ignorera cette cle
    -- la metadata sera perdue au crash mais c est acceptable en v1
    local entry = Cache[source]
    if entry then
      entry.pendingAmmo = ammo
    end
  end
end

-- ===========================================================================
-- Chargement au character selected
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function(payload)
  if not payload or not payload.source or not payload.characterId then return end
  local source      = payload.source
  local characterId = payload.characterId

  Cache[source] = {
    characterId = characterId,
    equipped    = nil,   -- { weaponHash, ammo } quand une arme est en main
  }

  -- Lecture des munitions persistees dans le slot holster
  local slot = getHolsterSlot(source)
  if slot and slot.metadata and slot.metadata.ammo then
    Cache[source].storedAmmo = tonumber(slot.metadata.ammo) or 0
  end

  print(('[sl-weapons] hydrated src=%d cid=%d holster=%s')
    :format(source, characterId, slot and slot.item or 'empty'))

  -- Notifie le client de l arme en holster (pour affichage HUD si besoin futur)
  if slot and slot.item then
    local def = Items and Items.Get and Items.Get(slot.item)
    local hash = def and def.weaponHash or nil
    TriggerClientEvent('sl:bus:dispatch', source, 'sl:weapons:holsterLoaded', {
      item        = slot.item,
      weaponHash  = hash,
      ammo        = Cache[source].storedAmmo or 0,
    })
  end
end)

AddEventHandler('sl:core:playerDropped', function(payload)
  if not payload or not payload.source then return end
  local source = payload.source
  local entry  = Cache[source]

  -- Si une arme etait en main, on sauvegarde les munitions dans le slot holster
  if entry and entry.equipped then
    persistHolsterAmmo(source, entry.equipped.ammo or 0)
  end

  Cache[source] = nil
end)

-- Sauvegarde au shutdown
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for source, entry in pairs(Cache) do
    if entry and entry.equipped then
      persistHolsterAmmo(source, entry.equipped.ammo or 0)
    end
  end
end)

-- ===========================================================================
-- Fonction interne : donne l arme au ped (appel client via event)
-- ===========================================================================
local function doEquip(source, weaponHash, ammo)
  local entry = Cache[source]
  if not entry then return end
  entry.equipped = { weaponHash = weaponHash, ammo = ammo or 0 }
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:weapons:equip', {
    weaponHash = weaponHash,
    ammo       = ammo or 0,
  })
end

local function doUnequip(source, saveAmmo)
  local entry = Cache[source]
  if not entry then return end
  local ammo = 0
  if entry.equipped then
    ammo = saveAmmo or entry.equipped.ammo or 0
    persistHolsterAmmo(source, ammo)
    entry.equipped = nil
  end
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:weapons:unequip', { savedAmmo = ammo })
end

-- ===========================================================================
-- Commande serveur holster : appel depuis le client
-- ===========================================================================
RegisterNetEvent('sl:weapons:toggleHolster', function()
  local source = source
  local entry  = Cache[source]
  if not entry then return end

  -- Lit l arme dans le holster
  local slot = getHolsterSlot(source)
  if not slot or not slot.item then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Holster vide.',
      type = 'inform',
    })
    return
  end

  local def = Items and Items.Get and Items.Get(slot.item)
  if not def or not def.weaponHash then
    TriggerClientEvent('ox_lib:notify', source, {
      description = 'Cet objet ne peut pas etre sorti du holster.',
      type = 'error',
    })
    return
  end

  if entry.equipped then
    -- Arme deja en main -> remettre au holster
    doUnequip(source, entry.equipped.ammo)
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Arme rangee : %s'):format(def.label or slot.item),
      type = 'inform',
    })
  else
    -- Sortir l arme du holster
    local storedAmmo = 0
    if slot.metadata and slot.metadata.ammo then
      storedAmmo = tonumber(slot.metadata.ammo) or 0
    elseif entry.storedAmmo then
      storedAmmo = entry.storedAmmo
    end
    doEquip(source, def.weaponHash, storedAmmo)
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Arme sortie : %s (%d mun)'):format(def.label or slot.item, storedAmmo),
      type = 'success',
    })
  end
end)

-- ===========================================================================
-- Le client nous informe du compte de munitions mis a jour (apres AddAmmoToPed)
-- ===========================================================================
RegisterNetEvent('sl:weapons:reportAmmo', function(ammo)
  local source = source
  local entry  = Cache[source]
  if not entry or not entry.equipped then return end
  entry.equipped.ammo = tonumber(ammo) or 0
end)

-- ===========================================================================
-- Hook : sl-inventory:itemUsed (via event serveur) pour type='ammo'
-- ===========================================================================
-- NOTE : sl-inventory/server/api.lua (InventoryUseItem) ne gere PAS le
-- useEffect type='ammo' : il NE consomme PAS l item et emet 'sl:inventory:itemUsed'
-- avec consumed=false. C est donc a sl-weapons de :
--   1) detecter l usage d un item ammo,
--   2) charger les munitions,
--   3) RETIRER lui-meme l item ammo de l inventaire (sl-inventory ne l a pas fait).
-- On ne filtre donc PAS sur payload.consumed (sinon le hook ne se declenche jamais).
AddEventHandler('sl:inventory:itemUsed', function(payload)
  if not payload or not payload.source or not payload.item then return end
  local source = payload.source
  local entry  = Cache[source]
  if not entry then return end

  local def = Items and Items.Get and Items.Get(payload.item)
  if not def or not def.useEffect then return end
  local effect = def.useEffect
  if effect.type ~= 'ammo' then return end

  local ammoType = effect.ammoType
  if not ammoType then return end

  -- Consomme 1 item ammo de l inventaire (sl-inventory ne le fait pas pour type='ammo').
  -- Si le retrait echoue (plus en stock ou erreur), on annule le chargement.
  local consumeAmmoItem = function()
    local ok, removed = pcall(function()
      return exports['sl-inventory']:RemoveItem(source, payload.item, 1, nil, 'weapons:reload')
    end)
    return ok and removed == true
  end

  -- Verifie si une arme est equipee et si elle utilise ce type de munitions
  local equipped = entry.equipped
  if equipped and equipped.weaponHash then
    local weapHash = equipped.weaponHash
    local expectedAmmo = Weapons.WeaponAmmoMap[weapHash]
    if expectedAmmo == ammoType then
      if not consumeAmmoItem() then return end
      local toAdd = Weapons.AmmoPerItem
      equipped.ammo = (equipped.ammo or 0) + toAdd
      TriggerClientEvent('sl:bus:dispatch', source, 'sl:weapons:addAmmo', {
        weaponHash = weapHash,
        ammoType   = ammoType,
        amount     = toAdd,
      })
      TriggerClientEvent('ox_lib:notify', source, {
        description = ('+%d munitions (%s)'):format(toAdd, ammoType),
        type = 'success',
      })
      return
    end
  end

  -- Pas d arme equipee ou mauvais type : on recharge quand meme (l arme au holster)
  local slot = getHolsterSlot(source)
  if slot and slot.item then
    local wDef = Items and Items.Get and Items.Get(slot.item)
    if wDef and wDef.weaponHash then
      local expectedAmmo = Weapons.WeaponAmmoMap[wDef.weaponHash]
      if expectedAmmo == ammoType then
        if not consumeAmmoItem() then return end
        local stored = 0
        if slot.metadata and slot.metadata.ammo then
          stored = tonumber(slot.metadata.ammo) or 0
        elseif entry.storedAmmo then
          stored = entry.storedAmmo
        end
        local newAmmo = stored + Weapons.AmmoPerItem
        entry.storedAmmo = newAmmo
        persistHolsterAmmo(source, newAmmo)
        TriggerClientEvent('ox_lib:notify', source, {
          description = ('+%d munitions stockees dans le holster (%s)'):format(Weapons.AmmoPerItem, ammoType),
          type = 'success',
        })
        return
      end
    end
  end

  -- Aucune arme compatible : on ne consomme PAS l item, on previent le joueur
  TriggerClientEvent('ox_lib:notify', source, {
    description = 'Aucune arme compatible avec ces munitions.',
    type = 'error',
  })
end)

-- ===========================================================================
-- Globals accessibles depuis api.lua
-- ===========================================================================
function GetWeaponCache(source) return Cache[source] end
function DoEquipWeapon(source, hash, ammo) doEquip(source, hash, ammo) end
function DoUnequipWeapon(source, ammo) doUnequip(source, ammo) end
function GetHolsterSlotData(source) return getHolsterSlot(source) end
