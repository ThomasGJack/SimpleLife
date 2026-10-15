print('[sl-shops/server] api.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Purchase : vérification → débit → ajout inventaire → log
-- ===========================================================================

local function logTransaction(characterId, shopKey, item, qty, priceUnit, total, payment)
  pcall(function()
    SL:DB().insert([[
      INSERT INTO sl_shop_transactions
        (character_id, shop_key, item, qty, price_unit, total, payment)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { characterId, shopKey, item, qty, priceUnit, total, payment })
  end)
end

-- Renvoie ok, err, payment, totalDebited
local function tryDebit(source, total)
  local economy = exports['sl-economy']
  local balances = economy:GetBalances(source) or { cash = 0, bank = 0 }

  for _, account in ipairs(Shops.PaymentOrder or {'cash', 'bank'}) do
    if (balances[account] or 0) >= total then
      local ok, err = economy:RemoveMoney(source, account, total, 'shop-purchase')
      if ok then return true, nil, account, total end
      return false, err or 'débit échoué', nil, 0
    end
  end

  return false, 'fonds insuffisants', nil, 0
end

local function countOwned(source, itemName)
  local n = exports['sl-inventory']:GetItem(source, itemName)
  return tonumber(n) or 0
end

-- Vérifie les requirements du shop (ex: armurerie → permis_port_arme)
local function checkRequirements(source, shop)
  if not shop.requirements then return true, nil end
  for _, req in ipairs(shop.requirements) do
    if req.type == 'item' then
      if countOwned(source, req.item) <= 0 then
        return false, req.errorMessage or ('Requis : ' .. req.item)
      end
    end
  end
  return true, nil
end

-- Achat principal
local function purchase(source, shopKey, itemName, qty)
  qty = math.floor(tonumber(qty) or 1)
  if qty < 1 then return false, 'quantité invalide' end
  if qty > (Shops.MaxQtyPerPurchase or 50) then return false, 'quantité trop élevée' end

  local shop = Shops.Get(shopKey)
  if not shop then return false, 'shop inconnu' end

  local line = Shops.FindItemInShop(shopKey, itemName)
  if not line then return false, 'item non vendu ici' end

  -- Vérif limite "1 par joueur" pour items uniques (téléphone, etc.)
  if shop.maxOwnedPerItem and shop.maxOwnedPerItem[itemName] then
    local max = shop.maxOwnedPerItem[itemName]
    local owned = countOwned(source, itemName)
    if owned >= max then
      return false, ('Vous en possédez déjà %d (max %d)'):format(owned, max)
    end
    if owned + qty > max then
      qty = max - owned
      if qty <= 0 then return false, 'limite atteinte' end
    end
  end

  -- Requirements (permis, etc.)
  local okReq, errReq = checkRequirements(source, shop)
  if not okReq then return false, errReq end

  -- Capacité inventaire
  if not exports['sl-inventory']:CanCarry(source, itemName, qty) then
    return false, 'inventaire plein ou trop lourd'
  end

  local total = line.price * qty

  -- Débit
  local okPay, errPay, account, debited = tryDebit(source, total)
  if not okPay then return false, errPay end

  -- Ajout inventaire
  local okAdd, errAdd = exports['sl-inventory']:AddItem(source, itemName, qty, nil, 'shop:'..shopKey)
  if not okAdd then
    -- Refund si l'ajout échoue (rare mais defensive)
    pcall(function() exports['sl-economy']:AddMoney(source, account, debited, 'shop-refund') end)
    return false, errAdd or 'inventaire échec'
  end

  -- Log
  local player = SL:GetPlayer(source)
  local characterId = player and player.characterId
  if characterId then
    logTransaction(characterId, shopKey, itemName, qty, line.price, total, account)
  end

  return true, {
    qty = qty,
    item = itemName,
    total = total,
    payment = account,
  }
end

-- ===========================================================================
-- Callbacks ox_lib
-- ===========================================================================

lib.callback.register('sl-shops:getCatalog', function(source, shopKey)
  local shop = Shops.Get(shopKey)
  if not shop then return nil end
  local cat = exports['sl-inventory']:GetCatalog() or {}
  local byName = {}
  for _, it in ipairs(cat) do byName[it.name] = it end

  local items = {}
  for _, line in ipairs(shop.inventory) do
    local def = byName[line.item] or {}
    items[#items+1] = {
      item = line.item,
      price = line.price,
      label = def.label or line.item,
      icon  = def.icon  or '📦',
      description = def.description or '',
      weight = def.weight or 0,
      stack = def.stack or 1,
      unique = def.unique == true,
      category = def.category or 'misc',
    }
  end

  -- Solde courant pour affichage
  local balances = exports['sl-economy']:GetBalances(source) or {}

  return {
    key       = shopKey,
    label     = shop.label,
    theme     = shop.theme or 'green',
    items     = items,
    balances  = { cash = balances.cash or 0, bank = balances.bank or 0 },
    maxQty    = Shops.MaxQtyPerPurchase or 50,
  }
end)

lib.callback.register('sl-shops:purchase', function(source, shopKey, itemName, qty)
  local ok, result = purchase(source, shopKey, itemName, qty)
  if not ok then return { ok = false, error = result } end
  -- Renvoie aussi le nouveau solde pour mise à jour UI
  local balances = exports['sl-economy']:GetBalances(source) or {}
  return {
    ok = true,
    qty = result.qty,
    item = result.item,
    total = result.total,
    payment = result.payment,
    balances = balances,
  }
end)

-- Exports (au cas où d'autres modules veulent acheter programmatiquement)
exports('Purchase', purchase)
