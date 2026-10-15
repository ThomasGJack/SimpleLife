print('[sl-gangs/client] main.lua loaded')

-- ===========================================================================
-- Etat local
-- ===========================================================================
local myGang      = nil   -- { gangName, gangColor, grade } ou nil
local territories = {}    -- liste des zones avec proprietaire
local blips       = {}    -- zone -> blipHandle

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function getBlipColor(colorName)
  if not colorName then return Gangs.DefaultBlipColor end
  local c = string.lower(colorName)
  -- Supporte aussi les codes hex simples : si inconnu -> defaut
  return Gangs.ColorToBlip[c] or Gangs.DefaultBlipColor
end

local function getZoneConfig(zoneName)
  for _, t in ipairs(Gangs.Territories) do
    if t.zone == zoneName then return t end
  end
  return nil
end

-- ===========================================================================
-- Blips territoires
-- ===========================================================================
local function removeAllBlips()
  for _, bh in pairs(blips) do
    if DoesBlipExist(bh) then RemoveBlip(bh) end
  end
  blips = {}
end

local function buildBlips()
  removeAllBlips()
  for _, t in ipairs(territories) do
    local cfg = getZoneConfig(t.zone)
    if cfg then
      local bh = AddBlipForRadius(cfg.coords.x, cfg.coords.y, cfg.coords.z,
                                  cfg.radius)
      SetBlipSprite(bh, Gangs.TerritoryBlipSprite or 9)
      SetBlipScale(bh, Gangs.TerritoryBlipScale or 1.0)
      SetBlipAlpha(bh, 80)
      local color = getBlipColor(t.gang_color)
      SetBlipColour(bh, color)
      BeginTextCommandSetBlipName('STRING')
      local label = cfg.label
      if t.gang_name then
        label = label .. ' [' .. t.gang_name .. ']'
      else
        label = label .. ' [libre]'
      end
      AddTextComponentString(label)
      EndTextCommandSetBlipName(bh)
      blips[t.zone] = bh
    end
  end
end

-- ===========================================================================
-- Bus listener
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if not event then return end

  -- Hydration du gang local
  if event == 'sl:gangs:hydrate' then
    if payload and payload.gangName then
      myGang = {
        gangName  = payload.gangName,
        gangColor = payload.gangColor,
        grade     = payload.grade,
      }
    else
      myGang = nil
    end
    return
  end

  -- Mise a jour des territoires
  if event == 'sl:gangs:territories' then
    if type(payload) == 'table' then
      territories = payload
      buildBlips()
    end
    return
  end

  -- Capture d une zone
  if event == 'sl:gangs:territory' then
    if payload and payload.zone then
      -- Mise a jour locale
      for _, t in ipairs(territories) do
        if t.zone == payload.zone then
          t.gang_name  = payload.gang
          t.gang_color = nil  -- sera raffraichi au prochain territories push
          break
        end
      end
      buildBlips()
    end
    return
  end

  -- Changement de membre (pour les autres UI si branche)
  if event == 'sl:gangs:memberChanged' then
    -- Si c est moi, la hydration aura deja ete envoyee par le serveur
    return
  end
end)

-- ===========================================================================
-- characterSelected : fetch initial
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  CreateThread(function()
    Wait(1000)
    -- Territoires
    local tList = lib.callback.await('sl-gangs:getTerritories', false)
    if tList then
      territories = tList
      buildBlips()
    end
  end)
end)

-- ===========================================================================
-- Commande client /ganginfo (affichage ox_lib context menu)
-- ===========================================================================
RegisterCommand('ganginfo', function()
  if not myGang then
    lib.notify({ description = 'Vous n appartenez a aucun gang.', type = 'error' })
    return
  end

  -- Fetch les donnees completes depuis le serveur
  local data = lib.callback.await('sl-gangs:getMyGang', false)
  if not data then
    lib.notify({ description = 'Erreur lors de la recuperation des donnees.', type = 'error' })
    return
  end

  local gradeLabel = (Gangs.Grades[data.grade or 0] or {}).label or tostring(data.grade)

  -- Construit le menu ox_lib
  local options = {
    {
      title    = ('Gang : %s'):format(data.name),
      disabled = true,
    },
    {
      title    = ('Grade : %s (%d)'):format(gradeLabel, data.grade or 0),
      disabled = true,
    },
    {
      title    = ('Membres : %d'):format(#(data.members or {})),
      disabled = true,
    },
  }

  -- Liste des membres
  for _, m in ipairs(data.members or {}) do
    local mGrade = (Gangs.Grades[tonumber(m.grade) or 0] or {}).label or tostring(m.grade)
    options[#options + 1] = {
      title    = ('%s %s'):format(m.firstname or '', m.lastname or ''),
      description = ('Grade : %s'):format(mGrade),
      disabled = true,
    }
  end

  lib.registerContext({
    id      = 'sl_gangs_info',
    title   = 'Mon Gang',
    options = options,
  })
  lib.showContext('sl_gangs_info')
end, false)

-- ===========================================================================
-- Commande client /territories  — affiche la carte des territoires
-- ===========================================================================
RegisterCommand('territories', function()
  if #territories == 0 then
    lib.notify({ description = 'Aucun territoire charge.', type = 'error' })
    return
  end

  local options = {}
  for _, t in ipairs(territories) do
    local cfg = getZoneConfig(t.zone)
    local label = cfg and cfg.label or t.zone
    local owner = t.gang_name or 'Libre'
    options[#options + 1] = {
      title       = label,
      description = ('Proprietaire : %s | Influence : %d'):format(owner, t.influence or 0),
      disabled    = true,
    }
  end

  lib.registerContext({
    id      = 'sl_gangs_territories',
    title   = 'Territoires',
    options = options,
  })
  lib.showContext('sl_gangs_territories')
end, false)

-- ===========================================================================
-- Exports client (consommables par d autres modules)
-- ===========================================================================

-- HasItem equivalent pour gangs
exports('GetMyGang', function()
  return myGang
end)

exports('IsInGang', function(gangName)
  return myGang ~= nil and myGang.gangName == gangName
end)

exports('GetTerritories', function()
  return territories
end)
