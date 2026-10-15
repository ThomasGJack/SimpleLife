print('[sl-crafting/server] api.lua loaded')

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function notify(src, msg, ntype)
  TriggerClientEvent('ox_lib:notify', src, { description = msg, type = ntype or 'inform' })
end

local function getRecipe(key)
  return Recipes and Recipes[key] or nil
end

-- ===========================================================================
-- Callback principal : demande de fabrication depuis la NUI
--
-- payload : { benchKey, recipeKey }
-- Retourne : { ok=bool, error=string|nil }
-- ===========================================================================
lib.callback.register('sl-crafting:craft', function(source, payload)
  if not payload or not payload.recipeKey or not payload.benchKey then
    return { ok = false, error = 'Payload invalide.' }
  end

  local entry = Cache[source]
  if not entry then
    return { ok = false, error = 'Personnage non charge.' }
  end

  -- Verifier que la recette existe
  local recipe = getRecipe(payload.recipeKey)
  if not recipe then
    return { ok = false, error = 'Recette inconnue.' }
  end

  -- Verifier que la recette appartient bien a cet etabli
  local bench = nil
  for _, b in ipairs(Crafting.Benches) do
    if b.key == payload.benchKey then
      bench = b
      break
    end
  end
  if not bench then
    return { ok = false, error = 'Etabli inconnu.' }
  end
  local allowed = false
  for _, rk in ipairs(bench.recipes) do
    if rk == payload.recipeKey then allowed = true; break end
  end
  if not allowed then
    return { ok = false, error = 'Recette non disponible sur cet etabli.' }
  end

  -- Verifier le niveau de skill si requis (via pcall : sl-skills optionnel)
  if recipe.skill and recipe.reqLevel then
    local ok, level = pcall(function()
      return exports['sl-skills']:GetLevel(source, recipe.skill)
    end)
    if ok and type(level) == 'number' and level < recipe.reqLevel then
      return {
        ok    = false,
        error = ('Niveau %s %d requis (vous etes %d).'):format(recipe.skill, recipe.reqLevel, level),
      }
    end
  end

  -- Verifier et retirer les inputs
  local inv = exports['sl-inventory']
  for _, inp in ipairs(recipe.inputs) do
    local okHas, has = pcall(function() return inv:HasItem(source, inp.item, inp.count) end)
    if not okHas or not has then
      return { ok = false, error = ('Ingredient manquant : %s x%d'):format(inp.item, inp.count) }
    end
  end

  -- Verifier que le joueur peut porter l output AVANT de retirer quoi que ce soit
  -- (evite de consommer les inputs si l inventaire est plein ou si l item est inconnu).
  local okCarry, canCarry = pcall(function()
    return inv:CanCarry(source, recipe.output.item, recipe.output.count)
  end)
  if not okCarry or canCarry == false then
    return { ok = false, error = 'Inventaire plein ou item invalide.' }
  end

  -- Retirer les inputs. On garde la trace de ce qui a ete retire pour rollback si besoin.
  local removed = {}
  for _, inp in ipairs(recipe.inputs) do
    -- InventoryRemoveItem renvoie (ok, err) : on doit verifier le booleen, pas seulement pcall.
    local ok, removeOk = pcall(function()
      return inv:RemoveItem(source, inp.item, inp.count, nil, 'crafting:' .. payload.recipeKey)
    end)
    if not ok or removeOk == false then
      -- Rollback : on remet ce qui a deja ete retire.
      for _, done in ipairs(removed) do
        pcall(function()
          inv:AddItem(source, done.item, done.count, nil, 'crafting:rollback')
        end)
      end
      print(('[sl-crafting] ECHEC retrait %s x%d pour src=%d (rollback effectue)')
        :format(inp.item, inp.count, source))
      return { ok = false, error = 'Erreur lors du retrait des ingredients.' }
    end
    removed[#removed + 1] = { item = inp.item, count = inp.count }
  end

  -- Ajouter l output. On verifie le booleen de retour.
  local addOk, addResult = pcall(function()
    return inv:AddItem(source, recipe.output.item, recipe.output.count, nil, 'crafting:' .. payload.recipeKey)
  end)
  if not addOk or addResult == false then
    -- Rollback complet des inputs : l output n a pas pu etre cree.
    for _, done in ipairs(removed) do
      pcall(function()
        inv:AddItem(source, done.item, done.count, nil, 'crafting:rollback')
      end)
    end
    print(('[sl-crafting] ECHEC ajout output %s x%d pour src=%d (rollback effectue)')
      :format(recipe.output.item, recipe.output.count, source))
    return { ok = false, error = 'Erreur lors de l\'ajout de l\'output.' }
  end

  -- XP crafting (sl-skills optionnel, pcall)
  local xpGain = math.floor(Crafting.BaseXP * (recipe.xpMult or 1.0))
  pcall(function()
    exports['sl-skills']:AddXP(source, Crafting.Skill, xpGain)
  end)

  -- Notification serveur -> client (bus)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:crafting:crafted', {
    source    = source,
    recipeKey = payload.recipeKey,
    label     = recipe.label,
    xp        = xpGain,
  })

  print(('[sl-crafting] crafted src=%d recipe=%s output=%s x%d xp=%d')
    :format(source, payload.recipeKey, recipe.output.item, recipe.output.count, xpGain))

  return { ok = true, xp = xpGain, label = recipe.label, outputCount = recipe.output.count }
end)

-- ===========================================================================
-- Callback : recup l inventaire du joueur pour les recettes (filtred)
-- Retourne : map { [itemName] = count }
-- ===========================================================================
lib.callback.register('sl-crafting:getPlayerItems', function(source)
  local items = exports['sl-inventory']:GetItems(source)
  -- GetItems retourne un tableau de { item, count, ... }
  -- On le convertit en map nom->count pour la NUI
  local map = {}
  if type(items) == 'table' then
    for _, entry in ipairs(items) do
      if entry and entry.item then
        map[entry.item] = (map[entry.item] or 0) + (entry.count or 1)
      end
    end
  end
  return map
end)

-- ===========================================================================
-- Export public : liste des etablis (pour autres modules)
-- ===========================================================================
exports('GetBenches', function()
  return Crafting.Benches
end)

exports('GetRecipes', function()
  return Recipes
end)
