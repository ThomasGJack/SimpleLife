print('[sl-crime/client] main.lua loaded')

-- ===========================================================================
-- Variables partagees entre les fichiers client du module (main/robbery/drugs)
-- NOTE : globales volontairement (un top-level `local` n'est PAS visible dans
-- les autres chunks du meme resource ; robbery.lua et drugs.lua y accedent).
-- ===========================================================================
isCharacterLoaded = false
interactIds = interactIds or {}   -- stocke les ids sl-interact pour cleanup

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function notify(desc, ntype)
  lib.notify({ description = desc, type = ntype or 'inform', duration = 4500 })
end

local function fmtTime(sec)
  if sec <= 0 then return '0s' end
  local m = math.floor(sec / 60)
  local s = sec % 60
  if m > 0 then return ('%dm %ds'):format(m, s) end
  return ('%ds'):format(s)
end

-- ===========================================================================
-- Enregistrement des zones au characterSelected
-- (robbery.lua et drugs.lua s'initialisent via cet event aussi)
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  isCharacterLoaded = true
end)

-- Cleanup quand le perso est decharge (ex: logout)
-- sl-core ne declenche pas d'event cote client pour logout,
-- donc on nettoie au resourceStop
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  -- Nettoyage interactions
  for _, id in ipairs(interactIds) do
    pcall(function() exports['sl-interact']:Remove(id) end)
  end
  interactIds = {}
end)

-- ===========================================================================
-- Ecoute du bus dispatch (alertes police reues par le joueur police)
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:crime:dealAlert' then
    notify('Alerte : deal de drogue signale dans votre secteur.', 'error')
  end
end)
