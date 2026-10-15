print('[sl-inventory/client] main.lua loaded')

-- ===========================================================================
-- 2 modes NUI :
--   - "off"  : tout caché (avant hydration ou si pas de personnage sélectionné)
--   - "full" : inventaire ouvert avec focus clavier/souris
-- ===========================================================================

local uiMode = 'off'
local hasFocus = false
local lastState = nil

local function setFocus(state)
  hasFocus = state
  SetNuiFocus(state, state)
  SetNuiFocusKeepInput(false)
end

local function nuiOpenFull()
  if uiMode == 'full' then
    SendNUIMessage({ action = 'sync', state = lastState })
    return
  end
  uiMode = 'full'
  setFocus(true)
  SendNUIMessage({ action = 'open', state = lastState })
end

local function nuiCloseFull()
  if uiMode ~= 'full' then return end
  uiMode = 'off'
  setFocus(false)
  SendNUIMessage({ action = 'close' })
end

local function fetchState()
  return lib.callback.await('sl-inventory:getState', false)
end

-- ===========================================================================
-- Exports CLIENT-side : les autres modules client (sl-phone, sl-vehicles, ...)
-- peuvent vérifier la présence d\'un item sans round-trip serveur, en lisant
-- notre cache local `lastState`. Les exports serveur du même nom (api.lua)
-- restent valides côté serveur — là c\'est juste pour le client.
-- ===========================================================================
local function clientGetItemCount(itemName)
  if not lastState or not lastState.slots then return 0 end
  local total = 0
  for _, slot in pairs(lastState.slots) do
    if slot and slot.item == itemName then
      total = total + (tonumber(slot.count) or 0)
    end
  end
  return total
end

exports('HasItem', function(itemName, minCount)
  minCount = tonumber(minCount) or 1
  return clientGetItemCount(itemName) >= minCount
end)

exports('GetItem', function(itemName)
  return clientGetItemCount(itemName)
end)

-- ===========================================================================
-- Notification wrapper :
--   - Si la fenêtre inventaire est ouverte → on rend un toast DANS notre NUI,
--     qui passe au-dessus de l'overlay (sinon ox_lib serait caché derrière).
--   - Sinon → ox_lib classique (visible normalement, pas d'overlay).
-- ===========================================================================
local function slNotify(text, kind, duration)
  if not text or text == '' then return end
  kind = kind or 'inform'
  duration = duration or 3500
  if uiMode == 'full' then
    SendNUIMessage({ action = 'toast', text = text, type = kind, duration = duration })
  else
    lib.notify({ description = text, type = kind, duration = duration })
  end
end

-- ===========================================================================
-- Sync depuis serveur
-- ===========================================================================
RegisterNetEvent('sl-inventory:sync', function(payload)
  lastState = payload
  if uiMode == 'full' then
    SendNUIMessage({ action = 'sync', state = payload })
  end
end)

RegisterNetEvent('sl-inventory:effect', function(effect)
  if not effect or not effect.type then return end
  if effect.type == 'food' then
    slNotify(('🍞 +%d faim'):format(effect.value or 0), 'inform')
  elseif effect.type == 'drink' then
    slNotify(('💧 +%d soif'):format(effect.value or 0), 'inform')
  elseif effect.type == 'alcohol' then
    slNotify('🍺 Santé !', 'inform')
  elseif effect.type == 'heal' then
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    local maxHp = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(maxHp, hp + (effect.value or 25)))
    slNotify(('+%d PV'):format(effect.value or 25), 'success')
  elseif effect.type == 'show_id' then
    slNotify('🪪 Carte d\'identité présentée.', 'inform')
  elseif effect.type == 'show_badge' then
    slNotify('🛡️ ' .. (effect.text or 'Badge présenté.'), 'inform')
  elseif effect.type == 'show_license' then
    slNotify(('🪪 Permis %s'):format(tostring(effect.kind or '?')), 'inform')
  elseif effect.type == 'open_phone' then
    -- sl-phone écoute aussi cet event ; rien à faire ici (pas de notif duplicate)
  elseif effect.type == 'vehicle_key' then
    slNotify('🔑 Verrouillage / déverrouillage (à venir : sl-vehicles).', 'inform')
  elseif effect.type == 'house_key' then
    slNotify('🗝️ Clé maison (à venir).', 'inform')
  elseif effect.type == 'tool' then
    slNotify(('🛠️ %s'):format(effect.tool or '?'), 'inform')
  end
end)

RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:inventory:itemAdded' and payload then
    local cat = Items.Get(payload.item)
    local label = cat and cat.label or payload.item
    local icon = cat and cat.icon or '📦'
    slNotify(('%s  +%d  %s'):format(icon, payload.count or 1, label), 'success', 3500)
  elseif event == 'sl:inventory:itemRemoved' and payload then
    local cat = Items.Get(payload.item)
    local label = cat and cat.label or payload.item
    local icon = cat and cat.icon or '📦'
    slNotify(('%s  -%d  %s'):format(icon, payload.count or 1, label), 'inform', 3500)
  end
end)

-- ===========================================================================
-- NUI callbacks
-- ===========================================================================
RegisterNUICallback('close', function(_, cb)
  nuiCloseFull()
  cb({ ok = true })
end)

RegisterNUICallback('move', function(data, cb)
  local ok, err = lib.callback.await('sl-inventory:move', false,
    tonumber(data.fromSlot), tonumber(data.toSlot), tonumber(data.count))
  if not ok and err then
    slNotify('❌ ' .. tostring(err), 'error', 3500)
  end
  cb({ ok = ok, error = err })
end)

RegisterNUICallback('use', function(data, cb)
  local ok, err = lib.callback.await('sl-inventory:use', false, tonumber(data.slot))
  cb({ ok = ok, error = err })
end)

RegisterNUICallback('drop', function(data, cb)
  local ok, err = lib.callback.await('sl-inventory:drop', false,
    tonumber(data.slot), tonumber(data.count))
  cb({ ok = ok, error = err })
end)

-- ===========================================================================
-- Commandes / keymap : ouverture inventaire
-- ===========================================================================
local function toggleInventory()
  if uiMode == 'full' then nuiCloseFull(); return end
  if not lastState then
    local s = fetchState()
    if not s then
      slNotify('Inventaire indisponible.', 'error')
      return
    end
    lastState = s
  end
  nuiOpenFull()
end

RegisterCommand('inventory', toggleInventory, false)
RegisterCommand('inv', toggleInventory, false)
-- Keymap centralisé dans sl-keybinds (catégorie "SimpleLife" dans Settings)

-- ===========================================================================
-- ESC pour fermer si la fenêtre est ouverte
-- ===========================================================================
CreateThread(function()
  while true do
    if uiMode == 'full' then
      if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 200) then
        nuiCloseFull()
      end
      Wait(0)
    else
      Wait(300)
    end
  end
end)

-- ===========================================================================
-- Pré-chargement de l'état au spawn (pas d'UI visible, juste le cache prêt
-- pour que l'ouverture soit instantanée).
-- ===========================================================================
RegisterNetEvent('sl:inventory:hydrated', function()
  CreateThread(function()
    Wait(200)
    lastState = fetchState() or lastState
  end)
end)

CreateThread(function()
  Wait(2000)
  if not lastState then
    lastState = fetchState()
  end
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() and hasFocus then
    setFocus(false)
  end
end)

-- ===========================================================================
-- Désactivation de la roulette des armes (TAB) + raccourcis natifs de switch
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(0)
    DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON (TAB) - roulette
    DisableControlAction(0, 12, true)  -- INPUT_WEAPON_WHEEL_UP_DOWN
    DisableControlAction(0, 13, true)  -- INPUT_WEAPON_WHEEL_LEFT_RIGHT
    DisableControlAction(0, 14, true)  -- INPUT_NEXT_WEAPON (mousewheel down)
    DisableControlAction(0, 15, true)  -- INPUT_PREV_WEAPON (mousewheel up)
    DisableControlAction(0, 80, true)  -- INPUT_VEH_CIN_CAM (wheel-related)
    DisableControlAction(0, 81, true)
  end
end)

-- ===========================================================================
-- Holster : draw / range l'arme du slot 202 via une touche configurable (H)
-- État tracké côté client. Le serveur ne sait pas si l'arme est en main ou
-- rangée — c'est purement visuel/gameplay. Resynchronisé à chaque sync au cas
-- où le slot holster change pendant que l'arme est sortie.
-- ===========================================================================

local weaponDrawn      = false
local currentWeaponDef = nil   -- nom de l'item équipé (taser, pistolet, etc.)
local currentWeaponHash= nil   -- hash numérique de l'arme

local function getHolsterContent()
  if not lastState or not lastState.equipment then return nil end
  local h = lastState.equipment.holster
  if not h then return nil end
  return h.content  -- peut être nil si slot vide
end

local function holsterWeapon(silent)
  local ped = PlayerPedId()
  SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
  if currentWeaponHash and HasPedGotWeapon(ped, currentWeaponHash, false) then
    RemoveWeaponFromPed(ped, currentWeaponHash)
  end
  local label = currentWeaponDef and (Items.Get(currentWeaponDef) and Items.Get(currentWeaponDef).label or currentWeaponDef) or 'arme'
  weaponDrawn = false
  currentWeaponDef = nil
  currentWeaponHash = nil
  if not silent then
    slNotify(('🔒 %s rangée'):format(label), 'inform', 2000)
  end
end

local function drawWeapon()
  local content = getHolsterContent()
  if not content or not content.item then
    slNotify('Holster vide.', 'error', 2000)
    return
  end
  local def = Items.Get(content.item)
  if not def then return end
  if not def.weaponHash then
    slNotify('Cet item ne se dégaine pas.', 'error', 2000)
    return
  end

  local ped = PlayerPedId()
  local hash = GetHashKey(def.weaponHash)
  GiveWeaponToPed(ped, hash, 250, false, true)
  SetCurrentPedWeapon(ped, hash, true)

  currentWeaponDef  = content.item
  currentWeaponHash = hash
  weaponDrawn       = true
  slNotify(('🗡️ %s en main'):format(def.label or content.item), 'success', 2000)
end

local function toggleHolster()
  if uiMode == 'full' then return end  -- pas pendant l'inventaire ouvert
  local ped = PlayerPedId()
  if IsEntityDead(ped) then return end
  if weaponDrawn then holsterWeapon(false) else drawWeapon() end
end

-- V1 : le draw/range est désormais géré par sl-weapons (système complet avec
-- munitions persistées + anims + autorité serveur). On délègue la commande
-- 'holster' (bindée sur H par sl-keybinds) au flux sl-weapons. L'ancien
-- toggleHolster local reste défini mais dormant (jamais appelé).
RegisterCommand('holster', function()
  if uiMode == 'full' then return end           -- pas pendant l'inventaire ouvert
  TriggerServerEvent('sl:weapons:toggleHolster')
end, false)
-- Keymap centralisé dans sl-keybinds (catégorie "SimpleLife" dans Settings)

-- Réinitialisation à chaque changement de personnage / hydration
local function resetHolsterState()
  if weaponDrawn then holsterWeapon(true) end
end
AddEventHandler('sl:core:characterSelected', resetHolsterState)
AddEventHandler('sl:inventory:hydrated', resetHolsterState)

-- Si le slot holster est modifié (drag, admin, etc.) alors qu'on a l'arme
-- en main, on ré-aligne : si plus la même arme → range.
local function reconcileHolster()
  if not weaponDrawn then return end
  local content = getHolsterContent()
  if not content or content.item ~= currentWeaponDef then
    holsterWeapon(true)
  end
end

-- On hook le sync NetEvent : reconciliation après chaque update de lastState
local _origSyncSetter = nil  -- pas besoin, on ajoute un handler en aval
RegisterNetEvent('sl-inventory:sync', function(payload)
  -- ce handler s'exécute en plus de celui plus haut (FiveM autorise plusieurs)
  reconcileHolster()
end)

-- Au respawn / mort du ped, le moteur GTA retire les armes → on réaligne notre état.
AddEventHandler('baseevents:onPlayerDied', function() weaponDrawn = false; currentWeaponDef = nil; currentWeaponHash = nil end)
AddEventHandler('baseevents:onPlayerKilled', function() weaponDrawn = false; currentWeaponDef = nil; currentWeaponHash = nil end)
