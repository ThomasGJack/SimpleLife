Inventory = Inventory or {}

-- Inventaire joueur
Inventory.SlotCount   = 30                -- nombre de slots dans l'inventaire perso
Inventory.MaxWeight   = 40000             -- poids max en grammes (40 kg)
Inventory.DefaultStack = 1                -- valeur par défaut si l'item ne précise pas
Inventory.AutosaveSec = 60                -- persist du cache toutes les Xs si dirty

-- UI
Inventory.OpenKey     = 'I'               -- touche d'ouverture
Inventory.UICommand   = 'inventory'       -- /inventory ou /i

-- Pas de hotbar (retirée v0.2.0 — UX trop chargée pour le style GTA V).
-- Les touches 1..5 restent libres pour les actions natives FiveM.
Inventory.HotbarSlots = {}

-- Paper-doll : équipement utilitaire (slots 201..205).
-- Distinct de sl-clothing : ici c'est de l'équipement transportable, pas du visuel.
Inventory.EquipmentSlots = {
  backpack = 201,
  holster  = 202,
  phone    = 203,
  radio    = 204,
  docs     = 205,
}

-- Règles d'acceptation par slot (validation server + client). Si non listé,
-- le slot accepte tout. Si listé, l'item DOIT matcher au moins une règle.
--   items      : liste blanche de nom exact d'item
--   categories : liste blanche de catégorie
Inventory.EquipmentRules = {
  [201] = { items = { 'sac_dos' },                                   label = 'Sac à dos' },
  [202] = { categories = { 'weapon' },                                label = 'Holster' },
  [203] = { items = { 'telephone' },                                  label = 'Téléphone' },
  [204] = { items = { 'radio' },                                      label = 'Radio' },
  [205] = { categories = { 'doc', 'license', 'badge' },               label = 'Documents' },
}

-- Effet du sac à dos équipé : bonus de capacité (grammes)
Inventory.BackpackBonus = 15000

-- Drops
Inventory.DropSlotCount   = 20            -- slots max par drop au sol
Inventory.DropMaxWeight   = 50000         -- poids max d'un drop au sol
Inventory.DropPickupDist  = 1.8           -- distance d'interaction
Inventory.DropTTLMinutes  = 30            -- nettoyage auto si pas touché

-- Persistence
Inventory.Tables = {
  catalog    = 'sl_items',
  inventory  = 'sl_inventory_items',
  drops      = 'sl_inventory_drops',
  dropItems  = 'sl_inventory_drop_items',
}

-- Hooks métiers (sl-jobs)
-- Items donnés automatiquement quand un joueur passe ON DUTY.
-- Map: jobName -> { itemName, count, metadata? }
Inventory.DutyKits = {
  police = {
    { item = 'badge_police',  count = 1 },
    { item = 'menottes',      count = 1 },
    { item = 'taser',         count = 1 },
    { item = 'radio',         count = 1 },
  },
  ambulance = {
    { item = 'badge_ems',     count = 1 },
    { item = 'medkit',        count = 3 },
    { item = 'defibrillateur',count = 1 },
    { item = 'radio',         count = 1 },
  },
  mechanic = {
    { item = 'badge_mecano',  count = 1 },
    { item = 'cric',          count = 1 },
    { item = 'cle_a_molette', count = 1 },
    { item = 'radio',         count = 1 },
  },
  taxi = {
    { item = 'badge_taxi',    count = 1 },
    { item = 'radio',         count = 1 },
  },
  farmer = {
    { item = 'gants',         count = 1 },
    { item = 'seau',          count = 1 },
  },
  trucker = {
    { item = 'manifest_livr', count = 1 },
    { item = 'radio',         count = 1 },
  },
}

-- Item de démarrage offert au premier spawn d'un personnage (slot vide).
Inventory.StartingItems = {
  { item = 'pain',  count = 2 },
  { item = 'eau',   count = 2 },
}
