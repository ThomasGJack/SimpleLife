-- sl-weapons : configuration partagee
Weapons = Weapons or {}

-- Slot holster dans sl-inventory (paper-doll)
Weapons.HolsterSlot = 202

-- Commande de degainage cote sl-weapons.
-- NB : la touche H -> 'holster' est mappee dans sl-keybinds (hub clavier central),
-- et sl-inventory possede deja sa propre commande 'holster'. Pour ne pas entrer en
-- conflit, sl-weapons expose sa logique riche sous 'holster_weapon' (cf client/main.lua).
-- Ces deux valeurs sont conservees pour reference / re-cablage eventuel.
Weapons.HolsterCommand = 'holster_weapon'
Weapons.HolsterKey     = 'H'

-- Duree de l animation de degainage en ms (Draw / Reholster)
Weapons.DrawAnimTime    = 800
Weapons.HolsterAnimTime = 700

-- Anims FiveM
Weapons.DrawAnim = {
  dict   = 'anim@mp_panama',
  name   = 'grab_weapon',
  flag   = 50,
}
Weapons.HolsterAnim = {
  dict   = 'reaction@intimidation@1h',
  name   = 'intro',
  flag   = 50,
}

-- Map ammoType (catalog useEffect.ammoType) -> hash FiveM (GetHashKey)
-- Les types que AddAmmoToPed accepte
Weapons.AmmoTypes = {
  AMMO_PISTOL  = 'AMMO_PISTOL',
  AMMO_SMG     = 'AMMO_SMG',
  AMMO_RIFLE   = 'AMMO_RIFLE',
  AMMO_SHOTGUN = 'AMMO_SHOTGUN',
}

-- Map weaponHash -> ammoType par defaut (recharge automatique a partir de l inventaire)
Weapons.WeaponAmmoMap = {
  WEAPON_PISTOL      = 'AMMO_PISTOL',
  WEAPON_COMBATPISTOL= 'AMMO_PISTOL',
  WEAPON_STUNGUN     = 'AMMO_PISTOL',
  WEAPON_SMG         = 'AMMO_SMG',
  WEAPON_NIGHTSTICK  = nil,   -- arme de melee, pas de munitions
  WEAPON_ASSAULTRIFLE  = 'AMMO_RIFLE',
  WEAPON_CARBINERIFLE  = 'AMMO_RIFLE',
  WEAPON_PUMPSHOTGUN   = 'AMMO_SHOTGUN',
  WEAPON_SAWNOFFSHOTGUN= 'AMMO_SHOTGUN',
}

-- Item ammo -> ammoType
Weapons.AmmoItems = {
  ammo_pistol  = 'AMMO_PISTOL',
  ammo_smg     = 'AMMO_SMG',
  ammo_rifle   = 'AMMO_RIFLE',
  ammo_shotgun = 'AMMO_SHOTGUN',
}

-- Quantite de munitions ajoutees par unite d item consommee
Weapons.AmmoPerItem = 30

-- Munitions par defaut accordees a la distribution d une arme (si ammo non precise)
Weapons.DefaultAmmo = 0
