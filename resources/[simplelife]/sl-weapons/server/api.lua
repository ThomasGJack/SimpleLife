print('[sl-weapons/server] api.lua loaded')

-- ===========================================================================
-- API publique sl-weapons (signatures figees dans INTEGRATION.md)
--   GiveWeapon(src, name, ammo)   -> bool, msg
--   RemoveWeapon(src, name)       -> bool, msg
--   GetEquipped(src)              -> { weaponHash, ammo } | nil
--   GiveAmmo(src, ammoType, n)    -> bool, msg
-- ===========================================================================

-- ============= GiveWeapon =============
-- Donne l arme (item `name`) dans le slot holster (202) avec `ammo` munitions.
-- Si un autre item est deja en holster, remplace-le (le retire d abord).
local function GiveWeapon(source, name, ammo)
  if not name then return false, 'name manquant' end
  ammo = tonumber(ammo) or Weapons.DefaultAmmo

  local def = Items and Items.Get and Items.Get(name)
  if not def or not def.weaponHash then
    return false, ('item %s inconnu ou pas une arme'):format(tostring(name))
  end

  -- Retire l eventuel ancien item en holster
  local existing = GetHolsterSlotData(source)
  if existing and existing.item then
    exports['sl-inventory']:RemoveItem(source, existing.item, 1, nil, 'holster:replaced')
  end

  -- Remet au holster avec metadata ammo
  local ok, err = exports['sl-inventory']:AddItem(source, name, 1, { ammo = ammo }, 'weapons:give')
  if not ok then return false, tostring(err) end

  -- Force le slot paperdoll : on doit bouger l item vers le slot 202
  -- AddItem place l item dans un slot libre de l inventaire principal.
  -- On utilise MoveItem pour le mettre dans le holster (202).
  -- On cherche le slot ou AddItem vient de poser l item.
  local items = exports['sl-inventory']:GetItems(source)
  local fromSlot = nil
  for _, s in ipairs(items or {}) do
    if s.item == name and s.slot ~= Weapons.HolsterSlot then
      fromSlot = s.slot
      break
    end
  end
  if fromSlot then
    exports['sl-inventory']:MoveItem(source, fromSlot, Weapons.HolsterSlot, 1)
  end

  local entry = GetWeaponCache(source)
  if entry then entry.storedAmmo = ammo end

  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Arme donnee : %s (%d mun)'):format(def.label or name, ammo),
    type = 'success',
  })
  return true
end

-- ============= RemoveWeapon =============
-- Retire l arme `name` du joueur (holster + main si equipee).
local function RemoveWeapon(source, name)
  if not name then return false, 'name manquant' end

  local entry = GetWeaponCache(source)

  -- Si l arme est en main, on la desarm d abord
  if entry and entry.equipped then
    local def = Items and Items.Get and Items.Get(name)
    local hash = def and def.weaponHash
    if hash and entry.equipped.weaponHash == hash then
      DoUnequipWeapon(source, 0)
    end
  end

  -- Retire du holster / inventaire
  local count = exports['sl-inventory']:GetItem(source, name)
  if not count or count <= 0 then
    return false, ('arme %s non trouvee dans inventaire'):format(name)
  end
  local ok, err = exports['sl-inventory']:RemoveItem(source, name, 1, nil, 'weapons:remove')
  if not ok then return false, tostring(err) end

  TriggerClientEvent('ox_lib:notify', source, {
    description = ('Arme retiree : %s'):format(name),
    type = 'inform',
  })
  return true
end

-- ============= GetEquipped =============
local function GetEquipped(source)
  local entry = GetWeaponCache(source)
  if not entry or not entry.equipped then return nil end
  return { weaponHash = entry.equipped.weaponHash, ammo = entry.equipped.ammo or 0 }
end

-- ============= GiveAmmo =============
-- Ajoute `n` munitions de type `ammoType` a l arme equipee ou stockee en holster.
local function GiveAmmo(source, ammoType, n)
  if not ammoType then return false, 'ammoType manquant' end
  n = tonumber(n) or 0
  if n <= 0 then return false, 'n doit etre > 0' end

  local entry = GetWeaponCache(source)
  if not entry then return false, 'joueur non charge' end

  local equipped = entry.equipped
  if equipped and equipped.weaponHash then
    local expectedAmmo = Weapons.WeaponAmmoMap[equipped.weaponHash]
    if expectedAmmo == ammoType then
      equipped.ammo = (equipped.ammo or 0) + n
      TriggerClientEvent('sl:bus:dispatch', source, 'sl:weapons:addAmmo', {
        weaponHash = equipped.weaponHash,
        ammoType   = ammoType,
        amount     = n,
      })
      return true
    end
  end

  -- Stocke dans le holster
  local slot = GetHolsterSlotData(source)
  if slot and slot.item then
    local wDef = Items and Items.Get and Items.Get(slot.item)
    if wDef and wDef.weaponHash then
      local expectedAmmo = Weapons.WeaponAmmoMap[wDef.weaponHash]
      if expectedAmmo == ammoType then
        local stored = (slot.metadata and tonumber(slot.metadata.ammo)) or (entry.storedAmmo or 0)
        local newAmmo = stored + n
        entry.storedAmmo = newAmmo
        local ok = pcall(function()
          exports['sl-inventory']:UpdateSlotMeta(source, Weapons.HolsterSlot, { ammo = newAmmo })
        end)
        return true
      end
    end
  end

  return false, 'aucune arme compatible avec ' .. tostring(ammoType)
end

-- ============= Exports publics =============
exports('GiveWeapon',   GiveWeapon)
exports('RemoveWeapon', RemoveWeapon)
exports('GetEquipped',  GetEquipped)
exports('GiveAmmo',     GiveAmmo)

-- ============= Toggle holster (client -> serveur) =============
-- Le flux reel passe par RegisterNetEvent('sl:weapons:toggleHolster') dans
-- server/main.lua, declenche par le client via TriggerServerEvent (commande
-- 'holster_weapon'). Pas de lib.callback ici : on ne peut pas re-emettre un
-- net event avec un faux source cote serveur (TriggerEventWithSource n existe
-- pas en FiveM), donc toute la logique vit dans main.lua avec le bon `source`.

-- ============= Commande admin =============
RegisterCommand('weapons_give', function(src, args)
  local isCon = (src == 0)
  if not isCon and not IsPlayerAceAllowed(src, 'sl.admin') then
    if src ~= 0 then
      TriggerClientEvent('ox_lib:notify', src, { description = 'Permission refusee.', type = 'error' })
    end
    return
  end
  local target = tonumber(args[1])
  local item   = args[2]
  local ammo   = tonumber(args[3]) or 0
  if not target or not item then
    print('[sl-weapons] usage: /weapons_give <src> <item> [ammo]')
    return
  end
  local ok, err = GiveWeapon(target, item, ammo)
  print(('[sl-weapons] weapons_give -> ok=%s err=%s'):format(tostring(ok), tostring(err)))
end, false)

RegisterCommand('weapons_remove', function(src, args)
  local isCon = (src == 0)
  if not isCon and not IsPlayerAceAllowed(src, 'sl.admin') then
    if src ~= 0 then
      TriggerClientEvent('ox_lib:notify', src, { description = 'Permission refusee.', type = 'error' })
    end
    return
  end
  local target = tonumber(args[1])
  local item   = args[2]
  if not target or not item then
    print('[sl-weapons] usage: /weapons_remove <src> <item>')
    return
  end
  local ok, err = RemoveWeapon(target, item)
  print(('[sl-weapons] weapons_remove -> ok=%s err=%s'):format(tostring(ok), tostring(err)))
end, false)
