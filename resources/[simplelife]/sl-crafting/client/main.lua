print('[sl-crafting/client] main.lua loaded')

-- ===========================================================================
-- Etat local
-- ===========================================================================
local isOpen       = false
local activeBench  = nil   -- { key, label, recipes = [...] }
local interactIds  = {}    -- cles des zones sl-interact pour cleanup

-- ===========================================================================
-- NUI helpers
-- ===========================================================================
local function openUI(bench, playerItems)
  if isOpen then return end
  isOpen = true
  activeBench = bench

  -- Construire la liste de recettes avec leurs infos completes
  local recipeList = {}
  for _, rk in ipairs(bench.recipes) do
    local r = Recipes[rk]
    if r then
      recipeList[#recipeList + 1] = r
    end
  end

  SetNuiFocus(true, true)
  SendNUIMessage({
    action      = 'open',
    bench       = { key = bench.key, label = bench.label },
    recipes     = recipeList,
    playerItems = playerItems,
  })
end

local function closeUI()
  if not isOpen then return end
  isOpen = false
  activeBench = nil
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

-- ===========================================================================
-- Interaction avec un etabli
-- ===========================================================================
local function onBenchInteract(bench)
  if isOpen then return end

  -- Recuperer l inventaire du joueur depuis le serveur
  local items = lib.callback.await('sl-crafting:getPlayerItems', false)
  if not items then items = {} end

  openUI(bench, items)
end

-- ===========================================================================
-- Enregistrement des zones sl-interact apres characterSelected
-- ===========================================================================
local function registerBenches()
  -- Nettoyer les anciennes zones si re-appel
  for _, id in ipairs(interactIds) do
    pcall(function() exports['sl-interact']:Remove(id) end)
  end
  interactIds = {}

  for _, bench in ipairs(Crafting.Benches) do
    local b = bench  -- closure
    local id = exports['sl-interact']:AddZone({
      coords   = b.coords,
      radius   = b.radius or 2.5,
      label    = 'Etabli — ' .. b.label,
      key      = 'E',
      onSelect = function()
        onBenchInteract(b)
      end,
    })
    if id then
      interactIds[#interactIds + 1] = id
    end
  end
end

AddEventHandler('sl:core:characterSelected', function()
  Wait(500)
  registerBenches()
end)

-- ===========================================================================
-- NUI Callbacks
-- ===========================================================================

-- Fermeture via bouton ou Echap
RegisterNUICallback('close', function(_, cb)
  closeUI()
  cb({ ok = true })
end)

-- Rafraichir l inventaire du joueur (avant d ouvrir une fabrication)
RegisterNUICallback('getPlayerItems', function(_, cb)
  local items = lib.callback.await('sl-crafting:getPlayerItems', false)
  cb(items or {})
end)

-- Lancer la fabrication
-- data : { benchKey, recipeKey }
RegisterNUICallback('craft', function(data, cb)
  if not data or not data.recipeKey or not data.benchKey then
    cb({ ok = false, error = 'Donnees manquantes.' })
    return
  end

  -- Verifier que le joueur est toujours pres de l etabli (securite client)
  local bench = nil
  for _, b in ipairs(Crafting.Benches) do
    if b.key == data.benchKey then bench = b; break end
  end
  if not bench then
    cb({ ok = false, error = 'Etabli introuvable.' })
    return
  end
  local ped    = PlayerPedId()
  local pos    = GetEntityCoords(ped)
  local dist   = #(pos - bench.coords)
  if dist > (bench.radius or 2.5) + 5.0 then
    cb({ ok = false, error = 'Vous etes trop loin de l\'etabli.' })
    closeUI()
    return
  end

  -- Recuperer la duree de la recette pour la barre de progression
  local recipe = Recipes[data.recipeKey]
  if not recipe then
    cb({ ok = false, error = 'Recette inconnue.' })
    return
  end

  -- Barre de progression ox_lib
  local progressOk = lib.progressBar({
    duration = recipe.time or 5000,
    label    = 'Fabrication : ' .. recipe.label,
    useWhileDead   = false,
    canCancel      = true,
    disable = {
      car  = true,
      move = true,
      combat = true,
    },
    anim = {
      dict   = 'mini@repair',
      clip   = 'fixing_a_ped',
      flag   = 1,
    },
  })

  if not progressOk then
    cb({ ok = false, error = 'Fabrication annulee.' })
    return
  end

  -- Appel serveur
  local result = lib.callback.await('sl-crafting:craft', false, {
    benchKey  = data.benchKey,
    recipeKey = data.recipeKey,
  })

  cb(result or { ok = false, error = 'Pas de reponse serveur.' })
end)

-- ===========================================================================
-- Bus : reception confirmation fabrication (pour toast NUI si fenetree ouverte)
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event ~= 'sl:crafting:crafted' then return end
  if isOpen then
    -- Le toast est gere cote JS via le resultat du callback craft.
    -- On met a jour l inventaire dans la NUI.
    local items = lib.callback.await('sl-crafting:getPlayerItems', false)
    if items then
      SendNUIMessage({ action = 'updateItems', playerItems = items })
    end
  end
end)

-- ===========================================================================
-- Fermer la NUI si Echap (gere aussi via NUI key handler, mais securite)
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(0)
    if isOpen then
      if IsControlJustReleased(0, 200) then -- INPUT_FRONTEND_CANCEL = Echap
        closeUI()
      end
    else
      Wait(200)
    end
  end
end)
