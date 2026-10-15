-- Catalogue d'items SimpleLife
-- Chaque entrée :
--   name        : identifiant unique (clé de la table)
--   label       : libellé affiché
--   weight      : poids unitaire en grammes
--   stack       : taille max d'un stack (1 = non stackable)
--   category    : famille (food, drink, tool, weapon, key, license, badge, doc, valuable, misc)
--   usable      : true si /use ou clic-droit Utiliser fonctionne
--   unique      : true si l'item est unique par instance (clé voiture, téléphone, licences)
--                  → un slot par instance, jamais empilé même si stack>1
--   icon        : emoji pour le rendu NUI v1 (avant assets)
--   description : texte court d'aide
--   useEffect   : optionnel, table décrivant l'effet à l'utilisation (resté volontairement
--                  simple en v1 — l'implémentation est dans sl-inventory/server/api.lua)
--   weaponHash  : optionnel (catégorie 'weapon'), nom du modèle d'arme FiveM (sera
--                  passé à GetHashKey côté client). Permet le draw/holster via la
--                  touche H quand l'item est dans le slot holster (202).

Items = Items or {}

Items.Catalog = {

  -- =============== NOURRITURE / BOISSON ===============
  pain = {
    label = 'Pain', weight = 200, stack = 10, category = 'food',
    usable = true, icon = '🥖',
    description = 'Restaure un peu de faim.',
    useEffect = { type = 'food', value = 25 },
  },
  sandwich = {
    label = 'Sandwich', weight = 350, stack = 10, category = 'food',
    usable = true, icon = '🥪',
    description = 'Restaure de la faim.',
    useEffect = { type = 'food', value = 45 },
  },
  burger = {
    label = 'Burger', weight = 500, stack = 5, category = 'food',
    usable = true, icon = '🍔',
    description = 'Sature mais pas très diététique.',
    useEffect = { type = 'food', value = 60 },
  },
  pomme = {
    label = 'Pomme', weight = 150, stack = 20, category = 'food',
    usable = true, icon = '🍎',
    description = 'Une pomme par jour…',
    useEffect = { type = 'food', value = 15 },
  },
  eau = {
    label = 'Bouteille d\'eau', weight = 500, stack = 12, category = 'drink',
    usable = true, icon = '💧',
    description = 'Restaure la soif.',
    useEffect = { type = 'drink', value = 30 },
  },
  cafe = {
    label = 'Café', weight = 250, stack = 10, category = 'drink',
    usable = true, icon = '☕',
    description = 'Un coup de fouet.',
    useEffect = { type = 'drink', value = 20 },
  },
  biere = {
    label = 'Bière', weight = 500, stack = 10, category = 'drink',
    usable = true, icon = '🍺',
    description = 'À consommer avec modération.',
    useEffect = { type = 'alcohol', value = 25 },
  },

  -- =============== POLICE ===============
  badge_police = {
    label = 'Badge de Police', weight = 50, stack = 1, category = 'badge',
    usable = true, icon = '🛡️', unique = true,
    description = 'Prouve votre identité d\'agent.',
    useEffect = { type = 'show_badge', text = 'Police de Los Santos' },
  },
  menottes = {
    label = 'Menottes', weight = 400, stack = 1, category = 'tool',
    usable = true, icon = '🔗',
    description = 'Pour interpeller un suspect.',
    useEffect = { type = 'tool', tool = 'handcuffs' },
  },
  taser = {
    label = 'Taser', weight = 700, stack = 1, category = 'weapon',
    usable = false, icon = '⚡',
    description = 'Arme non létale d\'intervention.',
    weaponHash = 'WEAPON_STUNGUN',
  },
  pistolet = {
    label = 'Pistolet', weight = 1200, stack = 1, category = 'weapon',
    usable = false, icon = '🔫', unique = true,
    description = 'Arme de poing 9mm.',
    weaponHash = 'WEAPON_PISTOL',
  },
  combat_pistol = {
    label = 'Combat Pistol', weight = 1400, stack = 1, category = 'weapon',
    usable = false, icon = '🔫', unique = true,
    description = 'Pistolet de combat (.45 ACP).',
    weaponHash = 'WEAPON_COMBATPISTOL',
  },
  smg = {
    label = 'SMG', weight = 3000, stack = 1, category = 'weapon',
    usable = false, icon = '🔫', unique = true,
    description = 'Pistolet-mitrailleur compact.',
    weaponHash = 'WEAPON_SMG',
  },
  matraque = {
    label = 'Matraque', weight = 800, stack = 1, category = 'weapon',
    usable = false, icon = '🥢',
    description = 'Matraque de service.',
    weaponHash = 'WEAPON_NIGHTSTICK',
  },
  radio = {
    label = 'Radio', weight = 300, stack = 1, category = 'tool',
    usable = true, icon = '📻',
    description = 'Communiquer avec ses collègues.',
    useEffect = { type = 'tool', tool = 'radio' },
  },

  -- =============== AMBULANCE ===============
  badge_ems = {
    label = 'Badge EMS', weight = 50, stack = 1, category = 'badge',
    usable = true, icon = '🚑', unique = true,
    description = 'Prouve votre identité de secouriste.',
    useEffect = { type = 'show_badge', text = 'EMS Los Santos' },
  },
  medkit = {
    label = 'Trousse de soin', weight = 1500, stack = 5, category = 'tool',
    usable = true, icon = '🧰',
    description = 'Soigne 50 PV. Usage unique.',
    useEffect = { type = 'heal', value = 50, consume = true },
  },
  bandage = {
    label = 'Bandage', weight = 100, stack = 20, category = 'tool',
    usable = true, icon = '🩹',
    description = 'Soigne 20 PV. Usage unique.',
    useEffect = { type = 'heal', value = 20, consume = true },
  },
  defibrillateur = {
    label = 'Défibrillateur', weight = 5000, stack = 1, category = 'tool',
    usable = true, icon = '⛑️',
    description = 'Réanime un joueur tombé au sol.',
    useEffect = { type = 'tool', tool = 'defib' },
  },

  -- =============== MECANO ===============
  badge_mecano = {
    label = 'Badge Mécano', weight = 50, stack = 1, category = 'badge',
    usable = true, icon = '🔧', unique = true,
    description = 'Prouve votre identité de mécano.',
    useEffect = { type = 'show_badge', text = 'Mécanicien certifié' },
  },
  cric = {
    label = 'Cric hydraulique', weight = 6000, stack = 1, category = 'tool',
    usable = true, icon = '🛠️',
    description = 'Pour soulever un véhicule.',
    useEffect = { type = 'tool', tool = 'jack' },
  },
  cle_a_molette = {
    label = 'Clé à molette', weight = 900, stack = 1, category = 'tool',
    usable = true, icon = '🔧',
    description = 'Outil polyvalent de mécano.',
    useEffect = { type = 'tool', tool = 'wrench' },
  },
  bidon_essence = {
    label = 'Bidon d\'essence', weight = 8000, stack = 2, category = 'tool',
    usable = true, icon = '⛽',
    description = '20L d\'essence pour dépanner.',
    useEffect = { type = 'tool', tool = 'fuel_can' },
  },
  pneu = {
    label = 'Pneu', weight = 9000, stack = 4, category = 'misc',
    usable = false, icon = '🛞',
    description = 'Pneu neuf à monter.',
  },

  -- =============== TAXI / TRANSPORT ===============
  badge_taxi = {
    label = 'Licence Taxi', weight = 50, stack = 1, category = 'license',
    usable = true, icon = '🚕', unique = true,
    description = 'Vous êtes autorisé à conduire un taxi.',
    useEffect = { type = 'show_badge', text = 'Licence Taxi' },
  },
  manifest_livr = {
    label = 'Manifeste de livraison', weight = 100, stack = 1, category = 'doc',
    usable = true, icon = '📋', unique = true,
    description = 'Ordres de livraison du jour.',
    useEffect = { type = 'show_badge', text = 'Manifeste de livraison' },
  },

  -- =============== AGRICULTURE ===============
  gants = {
    label = 'Gants de travail', weight = 200, stack = 1, category = 'tool',
    usable = false, icon = '🧤',
    description = 'Pour ne pas se salir les mains.',
  },
  seau = {
    label = 'Seau', weight = 1500, stack = 1, category = 'tool',
    usable = false, icon = '🪣',
    description = 'Pour récolter des choses.',
  },
  graines_ble = {
    label = 'Graines de blé', weight = 50, stack = 50, category = 'misc',
    usable = false, icon = '🌾',
    description = 'À planter dans un champ.',
  },
  ble = {
    label = 'Blé récolté', weight = 200, stack = 50, category = 'misc',
    usable = false, icon = '🌾',
    description = 'Récolte à vendre au moulin.',
  },

  -- =============== DOCUMENTS / LICENCES (uniques) ===============
  carte_identite = {
    label = 'Carte d\'identité', weight = 10, stack = 1, category = 'doc',
    usable = true, icon = '🪪', unique = true,
    description = 'Document officiel d\'identité.',
    useEffect = { type = 'show_id' },
  },
  permis_b = {
    label = 'Permis voiture', weight = 10, stack = 1, category = 'license',
    usable = true, icon = '🪪', unique = true,
    description = 'Permis de conduire B.',
    useEffect = { type = 'show_license', kind = 'B' },
  },
  permis_a = {
    label = 'Permis moto', weight = 10, stack = 1, category = 'license',
    usable = true, icon = '🏍️', unique = true,
    description = 'Permis de conduire A.',
    useEffect = { type = 'show_license', kind = 'A' },
  },
  permis_port_arme = {
    label = 'Port d\'arme', weight = 10, stack = 1, category = 'license',
    usable = true, icon = '🪪', unique = true,
    description = 'Autorisation de port d\'arme.',
    useEffect = { type = 'show_license', kind = 'gun' },
  },

  -- =============== OBJETS PERSO (uniques avec métadata) ===============
  telephone = {
    label = 'Téléphone', weight = 250, stack = 1, category = 'tool',
    usable = true, icon = '📱', unique = true,
    description = 'Smartphone perso.',
    useEffect = { type = 'open_phone' },
  },
  cle_voiture = {
    label = 'Clé de véhicule', weight = 80, stack = 1, category = 'key',
    usable = true, icon = '🔑', unique = true,
    description = 'Clé d\'un véhicule. Cliquer pour ouvrir / fermer.',
    useEffect = { type = 'vehicle_key' },
  },
  cle_maison = {
    label = 'Clé de maison', weight = 80, stack = 1, category = 'key',
    usable = true, icon = '🗝️', unique = true,
    description = 'Donne accès à une propriété.',
    useEffect = { type = 'house_key' },
  },

  -- =============== VALEURS ===============
  argent_marque = {
    label = 'Liasse marquée', weight = 400, stack = 5, category = 'valuable',
    usable = false, icon = '💵',
    description = 'Liasse traçable, à blanchir.',
  },
  bijou = {
    label = 'Bijou', weight = 150, stack = 10, category = 'valuable',
    usable = false, icon = '💎',
    description = 'À revendre au receleur.',
  },
  lingot_or = {
    label = 'Lingot d\'or', weight = 12000, stack = 5, category = 'valuable',
    usable = false, icon = '🏆',
    description = 'Lourd mais ça paie bien.',
  },

  -- =============== DIVERS ===============
  briquet = {
    label = 'Briquet', weight = 30, stack = 1, category = 'misc',
    usable = true, icon = '🔥',
    description = 'Fait du feu.',
    useEffect = { type = 'tool', tool = 'lighter' },
  },
  cigarette = {
    label = 'Cigarette', weight = 10, stack = 20, category = 'misc',
    usable = true, icon = '🚬',
    description = 'Fumer tue.',
    useEffect = { type = 'tool', tool = 'cig' },
  },
  sac_dos = {
    label = 'Sac à dos', weight = 1500, stack = 1, category = 'tool',
    usable = false, icon = '🎒',
    description = 'Augmente la capacité d\'inventaire (à venir).',
  },

  -- =============== MUNITIONS (sl-weapons) ===============
  ammo_pistol = {
    label = 'Munitions 9mm', weight = 10, stack = 250, category = 'ammo',
    usable = true, icon = '🔸',
    description = 'Recharge les pistolets.',
    useEffect = { type = 'ammo', ammoType = 'AMMO_PISTOL' },
  },
  ammo_smg = {
    label = 'Munitions SMG', weight = 12, stack = 250, category = 'ammo',
    usable = true, icon = '🔸',
    description = 'Recharge les pistolets-mitrailleurs.',
    useEffect = { type = 'ammo', ammoType = 'AMMO_SMG' },
  },
  ammo_rifle = {
    label = 'Munitions fusil', weight = 15, stack = 250, category = 'ammo',
    usable = true, icon = '🔸',
    description = 'Recharge les fusils d\'assaut.',
    useEffect = { type = 'ammo', ammoType = 'AMMO_RIFLE' },
  },
  ammo_shotgun = {
    label = 'Cartouches', weight = 20, stack = 250, category = 'ammo',
    usable = true, icon = '🔸',
    description = 'Recharge les fusils à pompe.',
    useEffect = { type = 'ammo', ammoType = 'AMMO_SHOTGUN' },
  },

  -- =============== DROGUE (sl-crime) ===============
  weed_seed = {
    label = 'Graine de cannabis', weight = 5, stack = 50, category = 'drug',
    usable = false, icon = '🌱',
    description = 'À planter pour cultiver.',
  },
  weed_bud = {
    label = 'Beuh brute', weight = 20, stack = 50, category = 'drug',
    usable = false, icon = '🍃',
    description = 'Récolte de cannabis non conditionnée.',
  },
  weed_packaged = {
    label = 'Sachet de beuh', weight = 25, stack = 50, category = 'drug',
    usable = false, icon = '🌿',
    description = 'Prêt à vendre dans la rue.',
  },
  coke_raw = {
    label = 'Coca brute', weight = 30, stack = 50, category = 'drug',
    usable = false, icon = '❄️',
    description = 'Poudre non raffinée.',
  },
  coke_packaged = {
    label = 'Sachet de coke', weight = 25, stack = 50, category = 'drug',
    usable = false, icon = '💎',
    description = 'Conditionnée, prête à vendre.',
  },
  meth_raw = {
    label = 'Meth brute', weight = 30, stack = 50, category = 'drug',
    usable = false, icon = '🧪',
    description = 'Cristaux non conditionnés.',
  },
  meth_packaged = {
    label = 'Sachet de meth', weight = 25, stack = 50, category = 'drug',
    usable = false, icon = '💠',
    description = 'Conditionnée, prête à vendre.',
  },

  -- =============== OUTILS CRIME (sl-crime / sl-vehicles) ===============
  lockpick = {
    label = 'Crochet', weight = 100, stack = 10, category = 'tool',
    usable = true, icon = '🪝',
    description = 'Pour crocheter serrures et véhicules.',
    useEffect = { type = 'tool', tool = 'lockpick' },
  },
  advanced_lockpick = {
    label = 'Crochet avancé', weight = 150, stack = 5, category = 'tool',
    usable = true, icon = '🗝️',
    description = 'Crochetage rapide et fiable.',
    useEffect = { type = 'tool', tool = 'advanced_lockpick' },
  },
  drill = {
    label = 'Perceuse', weight = 3000, stack = 1, category = 'tool',
    usable = true, icon = '🛠️',
    description = 'Perce les coffres-forts.',
    useEffect = { type = 'tool', tool = 'drill' },
  },
  thermite = {
    label = 'Thermite', weight = 800, stack = 5, category = 'tool',
    usable = true, icon = '🧨',
    description = 'Charge incendiaire pour portes blindées.',
    useEffect = { type = 'tool', tool = 'thermite' },
  },

  -- =============== MATÉRIAUX CRAFT (sl-crafting) ===============
  metal_scrap = {
    label = 'Ferraille', weight = 200, stack = 100, category = 'material',
    usable = false, icon = '🔩',
    description = 'Métal de récupération.',
  },
  plastic = {
    label = 'Plastique', weight = 100, stack = 100, category = 'material',
    usable = false, icon = '🧴',
    description = 'Plastique recyclé.',
  },
  electronics = {
    label = 'Composants électroniques', weight = 150, stack = 100, category = 'material',
    usable = false, icon = '🔌',
    description = 'Circuits et puces.',
  },
  fabric = {
    label = 'Tissu', weight = 80, stack = 100, category = 'material',
    usable = false, icon = '🧵',
    description = 'Textile brut.',
  },
  rubber = {
    label = 'Caoutchouc', weight = 120, stack = 100, category = 'material',
    usable = false, icon = '⚫',
    description = 'Caoutchouc industriel.',
  },
  glass = {
    label = 'Verre', weight = 180, stack = 100, category = 'material',
    usable = false, icon = '🪟',
    description = 'Verre recyclé.',
  },
  aluminum = {
    label = 'Aluminium', weight = 160, stack = 100, category = 'material',
    usable = false, icon = '🥫',
    description = 'Métal léger.',
  },

  -- =============== EMS+ (sl-ems) ===============
  painkillers = {
    label = 'Antidouleurs', weight = 50, stack = 20, category = 'tool',
    usable = true, icon = '💊',
    description = 'Soulage la douleur, soin léger.',
    useEffect = { type = 'heal', value = 15, consume = true },
  },
  suture_kit = {
    label = 'Kit de suture', weight = 300, stack = 10, category = 'tool',
    usable = true, icon = '🩹',
    description = 'Stoppe les hémorragies.',
    useEffect = { type = 'tool', tool = 'suture' },
  },
  oxygen_mask = {
    label = 'Masque à oxygène', weight = 800, stack = 5, category = 'tool',
    usable = true, icon = '😷',
    description = 'Stabilise un blessé grave.',
    useEffect = { type = 'tool', tool = 'oxygen' },
  },

  -- =============== MÉCANO (sl-jobmissions / sl-vehicles) ===============
  repair_kit = {
    label = 'Kit de réparation', weight = 5000, stack = 5, category = 'tool',
    usable = true, icon = '🔧',
    description = 'Répare un véhicule endommagé.',
    useEffect = { type = 'tool', tool = 'repair_kit' },
  },
  body_kit = {
    label = 'Kit carrosserie', weight = 6000, stack = 5, category = 'tool',
    usable = true, icon = '🚙',
    description = 'Restaure la carrosserie d\'un véhicule.',
    useEffect = { type = 'tool', tool = 'body_kit' },
  },
  tire_repair = {
    label = 'Kit anti-crevaison', weight = 1500, stack = 10, category = 'tool',
    usable = true, icon = '🛞',
    description = 'Répare un pneu crevé.',
    useEffect = { type = 'tool', tool = 'tire_repair' },
  },
}

-- Aides

function Items.Get(name)
  return Items.Catalog[name]
end

function Items.Exists(name)
  return Items.Catalog[name] ~= nil
end

function Items.IsStackable(name)
  local def = Items.Catalog[name]
  if not def then return false end
  if def.unique then return false end
  return (def.stack or 1) > 1
end

function Items.MaxStack(name)
  local def = Items.Catalog[name]
  if not def then return 1 end
  if def.unique then return 1 end
  return def.stack or 1
end

function Items.Weight(name)
  local def = Items.Catalog[name]
  return def and (def.weight or 0) or 0
end

function Items.IsUsable(name)
  local def = Items.Catalog[name]
  return def and def.usable == true
end

function Items.IsUnique(name)
  local def = Items.Catalog[name]
  return def and def.unique == true
end

function Items.Category(name)
  local def = Items.Catalog[name]
  return def and def.category or 'misc'
end

function Items.List()
  local list = {}
  for k, v in pairs(Items.Catalog) do
    list[#list+1] = {
      name = k, label = v.label, weight = v.weight, stack = v.stack,
      category = v.category, usable = v.usable == true, unique = v.unique == true,
      icon = v.icon, description = v.description,
    }
  end
  table.sort(list, function(a,b) return (a.label or '') < (b.label or '') end)
  return list
end
