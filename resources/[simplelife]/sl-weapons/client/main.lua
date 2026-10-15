print('[sl-weapons/client] main.lua loaded')

-- ===========================================================================
-- Etat local
-- ===========================================================================
local equippedHash  = nil   -- hash de l arme actuellement en main (ou nil)
local isDrawn       = false -- true si l arme est physiquement donnee au ped
local busyAnim      = false -- verrou pour eviter les doubles appels pendant l anim

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

-- Charge et joue une animation ; retourne apres son ecoulement (bloquant dans un thread).
local function playAnim(dict, name, flag, durationMs)
  if not HasAnimDictLoaded(dict) then
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
      Wait(0)
      if GetGameTimer() - t > 3000 then break end
    end
  end
  local ped = PlayerPedId()
  TaskPlayAnim(ped, dict, name, 4.0, -1.0, durationMs, flag, 0.0, false, false, false)
  Wait(durationMs)
  ClearPedTasks(ped)
end

-- Retourne le nombre de munitions actuelles pour une arme (hash)
local function getAmmoForWeapon(hash)
  local ped = PlayerPedId()
  if not ped or ped == 0 then return 0 end
  if not HasPedGotWeapon(ped, hash, false) then return 0 end
  return GetAmmoInPedWeapon(ped, hash)
end

-- Rapporte le compte de munitions au serveur
local function reportAmmo(ammo)
  TriggerServerEvent('sl:weapons:reportAmmo', ammo)
end

-- ===========================================================================
-- Draw : donne l arme physiquement au ped + anim
-- ===========================================================================
local function drawWeapon(weaponHash, ammo)
  if busyAnim then return end
  busyAnim = true
  CreateThread(function()
    local ped = PlayerPedId()

    -- Anim de degainage
    playAnim(
      Weapons.DrawAnim.dict,
      Weapons.DrawAnim.name,
      Weapons.DrawAnim.flag,
      Weapons.DrawAnimTime
    )

    -- Donne l arme
    local hash = GetHashKey(weaponHash)
    GiveWeaponToPed(ped, hash, ammo or 0, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    SetPedAmmo(ped, hash, ammo or 0)

    equippedHash = hash
    isDrawn      = true
    busyAnim     = false

    lib.notify({
      description = 'Arme degainee.',
      type = 'inform',
      duration = 2000,
    })
  end)
end

-- ===========================================================================
-- Holster : retire physiquement l arme du ped + anim + sauvegarde munitions
-- ===========================================================================
local function holsterWeapon()
  if busyAnim then return end
  if not isDrawn or not equippedHash then return end
  busyAnim = true
  CreateThread(function()
    local ped  = PlayerPedId()
    local ammo = getAmmoForWeapon(equippedHash)

    -- Anim de rangement
    playAnim(
      Weapons.HolsterAnim.dict,
      Weapons.HolsterAnim.name,
      Weapons.HolsterAnim.flag,
      Weapons.HolsterAnimTime
    )

    -- Retire l arme
    RemoveWeaponFromPed(ped, equippedHash)

    -- Rapport des munitions restantes au serveur pour persistence
    reportAmmo(ammo)

    isDrawn      = false
    equippedHash = nil
    busyAnim     = false

    lib.notify({
      description = 'Arme rangee.',
      type = 'inform',
      duration = 2000,
    })
  end)
end

-- ===========================================================================
-- Commande holster (client-side, transmet la decision au serveur)
--
-- IMPORTANT (integration) : la touche physique (H) est mappee UNE SEULE FOIS
-- dans sl-keybinds (RegisterKeyMapping('holster', ..., 'H')). On ne refait PAS
-- de RegisterKeyMapping ici (sinon double-binding / conflit de hub clavier).
--
-- ATTENTION : sl-inventory enregistre DEJA RegisterCommand('holster') avec sa
-- propre logique de degainage purement client. Pour eviter un double handler
-- non-deterministe sur le meme nom de commande, sl-weapons expose sa logique
-- riche (persistence munitions + round-trip serveur) sous un nom DEDIE et ne
-- capture pas 'holster'. L'integrateur peut re-pointer la touche H vers
-- 'holster_weapon' dans sl-keybinds s'il veut le systeme sl-weapons a la place.
-- ===========================================================================
RegisterCommand(Weapons.HolsterCommand or 'holster_weapon', function()
  if busyAnim then return end
  TriggerServerEvent('sl:weapons:toggleHolster')
end, false)

-- ===========================================================================
-- Bus dispatcher : receptions des ordres serveur
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:weapons:equip' then
    -- Le serveur ordonne de sortir l arme
    if payload and payload.weaponHash then
      drawWeapon(payload.weaponHash, payload.ammo or 0)
    end

  elseif event == 'sl:weapons:unequip' then
    -- Le serveur ordonne de ranger l arme
    holsterWeapon()

  elseif event == 'sl:weapons:addAmmo' then
    -- Le serveur ajoute des munitions a l arme equipee
    if payload and payload.weaponHash and isDrawn and equippedHash then
      local ped  = PlayerPedId()
      local hash = GetHashKey(payload.weaponHash)
      if equippedHash == hash then
        AddAmmoToPed(ped, hash, payload.amount or 0)
        local newAmmo = getAmmoForWeapon(hash)
        reportAmmo(newAmmo)
        lib.notify({
          description = ('+%d munitions chargees.'):format(payload.amount or 0),
          type = 'success',
          duration = 2500,
        })
      end
    end

  elseif event == 'sl:weapons:holsterLoaded' then
    -- Sync initial apres character selected (info seulement, pas d action physique)
    -- On pourrait afficher une icone HUD ici en v2
    if payload and payload.weaponHash then
      print(('[sl-weapons/client] holster charge : %s (%d mun)')
        :format(payload.item or '?', payload.ammo or 0))
    end
  end
end)

-- ===========================================================================
-- sl-inventory:effect
-- IMPORTANT : sl-inventory (InventoryUseItem) n emet AUCUN effect type='ammo'.
-- Le chargement des munitions est entierement gere cote serveur (hook
-- sl:inventory:itemUsed) qui declenche 'sl:weapons:addAmmo' -> handle dans le
-- bus dispatcher plus haut (seule source qui appelle AddAmmoToPed pour l ammo).
-- On NE rajoute donc PAS AddAmmoToPed ici, sinon double-comptage des munitions.
-- On ne garde que le cas type='weapon' (equip futur depuis la NUI inventaire).
-- ===========================================================================
RegisterNetEvent('sl-inventory:effect', function(effect)
  if not effect then return end

  if effect.type == 'weapon' then
    -- Une arme est equipee depuis l inventaire NUI (cas futur ou arme usable)
    if effect.weaponHash then
      drawWeapon(effect.weaponHash, effect.ammo or 0)
    end
  end
end)

-- ===========================================================================
-- Nettoyage au character dropped / respawn
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  -- Nettoie l etat local si un ancien perso etait charge
  if isDrawn and equippedHash then
    local ped = PlayerPedId()
    RemoveWeaponFromPed(ped, equippedHash)
  end
  equippedHash = nil
  isDrawn      = false
  busyAnim     = false
end)

-- ===========================================================================
-- Tick : desarm si le joueur est mort
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(2000)
    if isDrawn and equippedHash then
      local ped = PlayerPedId()
      if ped and ped ~= 0 and IsEntityDead(ped) then
        -- Ne pas sauvegarder les munitions a la mort (ou garder 0 selon design)
        RemoveWeaponFromPed(ped, equippedHash)
        reportAmmo(0)
        isDrawn      = false
        equippedHash = nil
      end
    end
  end
end)
