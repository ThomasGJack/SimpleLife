Shops = Shops or {}

-- ===========================================================================
-- Définition des shops.
--
-- Schema :
--   key           : identifiant unique (utilisé partout)
--   label         : libellé affiché
--   theme         : palette UI ('green' | 'blue' | 'orange' | 'red')
--   blip          : { sprite, color, scale, label }
--   pedModel      : modèle PNJ derrière le comptoir
--   spawns        : { { coords = vec4(x, y, z, h), heading = ... }, ... }
--   inventory     : liste d'items à vendre avec prix unitaires
--   requirements  : optionnel (item requis pour acheter, ex: permis_port_arme)
--
-- Le catalogue d'items et leurs propriétés sont définis dans sl-inventory.
-- Ici on donne juste le prix par shop.
-- ===========================================================================

Shops.List = {

  -- =====================================================================
  -- SUPÉRETTE 24-7
  -- =====================================================================
  supermarket = {
    label    = '24-7 Supérette',
    theme    = 'green',
    pedModel = 'mp_m_shopkeep_01',
    blip     = { sprite = 52, color = 2, scale = 0.7, label = '24-7 Supérette' },
    spawns = {
      { x =  -47.45, y = -1758.83, z =  28.42, h =  47.0 },  -- Davis (Strawberry sud)
      { x = -707.98, y =  -914.43, z =  18.22, h =  88.0 },  -- Mission Row
      { x = 1962.42, y =  3739.13, z =  31.34, h = 116.0 },  -- Sandy Shores
      { x = 1729.21, y =  6414.13, z =  34.04, h = 246.0 },  -- Paleto Bay
      { x =  372.55, y =   326.85, z = 102.57, h = 250.0 },  -- Vinewood
    },
    inventory = {
      { item = 'pain',      price =   3 },
      { item = 'sandwich',  price =   8 },
      { item = 'burger',    price =  12 },
      { item = 'pomme',     price =   2 },
      { item = 'eau',       price =   2 },
      { item = 'cafe',      price =   4 },
      { item = 'biere',     price =   6 },
      { item = 'cigarette', price =  10 },
      { item = 'briquet',   price =   5 },
    },
  },

  -- =====================================================================
  -- SHOP TÉLÉPHONE
  -- =====================================================================
  phoneshop = {
    label    = 'Apple Store',
    theme    = 'blue',
    pedModel = 'a_m_y_business_03',   -- jeune homme d'affaires, modèle GTA V standard
    blip     = { sprite = 268, color = 38, scale = 0.7, label = 'Apple Store' },
    spawns = {
      -- Centre commercial Pillbox Hill (LS Downtown). Position de trottoir
      -- vérifiée, accessible facilement.
      { x =  -41.16, y = -1106.96, z =  26.42, h = 343.0 },
    },
    inventory = {
      { item = 'telephone',     price = 800 },
    },
    -- Limite v1 : 1 téléphone par joueur (vérif côté server)
    maxOwnedPerItem = {
      telephone = 1,
    },
  },

  -- =====================================================================
  -- QUINCAILLERIE
  -- =====================================================================
  hardware = {
    label    = 'Quincaillerie LSC',
    theme    = 'orange',
    pedModel = 's_m_y_construct_01',
    blip     = { sprite = 402, color = 17, scale = 0.7, label = 'Quincaillerie' },
    spawns = {
      { x = 2747.30, y = 3473.69, z = 54.67, h = 252.0 },  -- Sandy Shores Hardware
      { x =   25.50, y =-1339.81, z = 28.50, h = 263.0 },  -- La Mesa Hardware (centre)
    },
    inventory = {
      { item = 'cric',          price = 350 },
      { item = 'cle_a_molette', price = 120 },
      { item = 'bidon_essence', price =  80 },
      { item = 'gants',         price =  35 },
      { item = 'seau',          price =  25 },
      { item = 'graines_ble',   price =  15 },
      { item = 'sac_dos',       price = 250 },
      { item = 'menottes',      price =  90 },   -- pour les sécus / privés
    },
  },
}

-- ===========================================================================
-- Réglages globaux
-- ===========================================================================
Shops.PaymentOrder = { 'cash', 'bank' }   -- essaie cash d'abord, puis bank
Shops.OpenDistance = 2.5                  -- distance d'ouverture du menu (target)
Shops.MaxQtyPerPurchase = 50              -- garde-fou anti-bug

-- Helpers
function Shops.Get(key) return Shops.List[key] end

function Shops.FindItemInShop(shopKey, itemName)
  local shop = Shops.List[shopKey]
  if not shop then return nil end
  for _, line in ipairs(shop.inventory) do
    if line.item == itemName then return line end
  end
  return nil
end
