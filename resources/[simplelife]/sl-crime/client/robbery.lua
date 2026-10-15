print('[sl-crime/client] robbery.lua loaded')

-- ===========================================================================
-- BRAQUAGE MAGASINS ET COFFRES-FORTS
-- ===========================================================================

local robberyInProgress = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function notify(desc, ntype)
  lib.notify({ description = desc, type = ntype or 'inform', duration = 4500 })
end

local function hasItem(itemName)
  local ok, has = pcall(function()
    return exports['sl-inventory']:HasItem(itemName, 1)
  end)
  return ok and has == true
end

-- ---------------------------------------------------------------------------
-- Tente un braquage (shop ou safe)
-- ---------------------------------------------------------------------------
local function attemptRobbery(kind, cfg)
  if robberyInProgress then
    notify('Un braquage est deja en cours.', 'error')
    return
  end

  -- Verifie item requis
  if not hasItem(cfg.requiredItem) then
    local labels = {
      lockpick          = 'un lockpick',
      advanced_lockpick = 'un lockpick avance',
      drill             = 'une perceuse',
      thermite          = 'de la thermite',
    }
    notify('Il vous faut ' .. (labels[cfg.requiredItem] or cfg.requiredItem) .. ' pour ca.', 'error')
    return
  end

  -- Verifie cooldown via serveur
  local checkRes = lib.callback.await('sl-crime:checkRobbery', false, kind, cfg.id)
  if not checkRes then
    notify('Erreur de communication.', 'error')
    return
  end
  if not checkRes.ok then
    if checkRes.reason == 'cooldown' then
      local rem = checkRes.remaining or 0
      local m = math.floor(rem / 60)
      local s = rem % 60
      notify(('La caisse a deja ete braquee. Retour dans %dm %ds.'):format(m, s), 'error')
    else
      notify('Impossible de braquer cet endroit.', 'error')
    end
    return
  end

  robberyInProgress = true

  -- Barre de progression avec skill checks
  local skillChecks = nil
  if kind == 'safe' then
    skillChecks = {
      { name = 'circle',    difficulty = 'hard',   ms = 6000 },
      { name = 'circle',    difficulty = 'medium', ms = 6000 },
    }
  else
    skillChecks = {
      { name = 'circle',    difficulty = 'medium', ms = 5000 },
    }
  end

  -- Label selon l'outil
  local actionLabel = 'Crocheter la serrure'
  if cfg.requiredItem == 'drill' then
    actionLabel = 'Percer le coffre'
  elseif cfg.requiredItem == 'thermite' then
    actionLabel = 'Poser la thermite'
  end

  -- lib.progressBar + skillcheck
  local success = lib.progressBar({
    duration = cfg.progressMs,
    label    = actionLabel,
    useWhileDead = false,
    canCancel    = true,
    disable = { car = true, combat = true },
    anim    = {
      dict   = 'anim@heists@fleeca@hands_up',
      clip   = 'idle',
      flag   = 49,
    },
  })

  if not success then
    robberyInProgress = false
    notify('Braquage annule.', 'error')
    return
  end

  -- Envoie la finalisation au serveur
  local res = lib.callback.await('sl-crime:finishRobbery', false, kind, cfg.id)
  robberyInProgress = false

  if not res or not res.ok then
    if res and res.reason == 'cooldown' then
      notify('Quelqu\'un a deja braque cette caisse.', 'error')
    elseif res and res.reason == 'economy_error' then
      notify('Erreur interne (economie).', 'error')
    else
      notify('Le braquage a echoue.', 'error')
    end
    return
  end

  -- Succes
  local loot = res.loot or 0
  notify(('Braquage reussi ! Vous avez recupere $%s.'):format(
    tostring(loot):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s', '')
  ), 'success')

  -- Alerte visuelle : flash ecran rouge discret
  StartScreenEffect('DeathFailNeutralIn', 300, false)
  Wait(300)
  StopScreenEffect('DeathFailNeutralIn')
end

-- ---------------------------------------------------------------------------
-- Enregistrement des zones au characterSelected
-- ---------------------------------------------------------------------------
AddEventHandler('sl:core:characterSelected', function()
  -- Shops
  for _, cfg in ipairs(Crime.Shops) do
    local zoneCfg = cfg   -- capture locale
    local id = exports['sl-interact']:AddZone({
      coords   = cfg.coords,
      radius   = cfg.radius or 1.5,
      label    = cfg.label .. ' [Braquer]',
      key      = 'E',
      onSelect = function()
        attemptRobbery('shop', zoneCfg)
      end,
    })
    interactIds[#interactIds + 1] = id
  end

  -- Safes
  for _, cfg in ipairs(Crime.Safes) do
    local zoneCfg = cfg
    local id = exports['sl-interact']:AddZone({
      coords   = cfg.coords,
      radius   = cfg.radius or 1.5,
      label    = cfg.label .. ' [Forcer]',
      key      = 'E',
      onSelect = function()
        attemptRobbery('safe', zoneCfg)
      end,
    })
    interactIds[#interactIds + 1] = id
  end
end)
