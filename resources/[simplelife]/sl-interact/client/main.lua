print('[sl-interact/client] main.lua loaded')

-- ===========================================================================
-- sl-interact : système d'interaction "visée libre + touche E"
--
-- 2 types de points d'interaction :
--   • ENTITY  : attaché à une entité (ped, vehicle, object). Le prompt s'affiche
--                quand on REGARDE l'entité (caméra + distance).
--   • ZONE    : attaché à des coords + rayon. Le prompt s'affiche quand on est
--                DANS le rayon (pas besoin de regarder).
--
-- L'utilisateur appuie sur la touche définie (par défaut E) → la callback fire.
--
-- Exports publics :
--   exports['sl-interact']:AddEntity(entity, options) → id (auto)
--   exports['sl-interact']:AddZone({ coords, radius, ...options })  → id
--   exports['sl-interact']:Remove(id)
--   exports['sl-interact']:RemoveEntity(entity)
--   exports['sl-interact']:Clear()  -- tout virer (debug)
--
-- options =
--   {
--     label    = '🛒 Acheter',
--     key      = 'E',         -- nom de touche (E par défaut)
--     distance = 3.0,         -- distance max
--     onSelect = function() ... end,
--   }
-- ===========================================================================

local interactions = {}    -- id -> { kind, entity?, coords?, radius?, options, key }
local activeId     = nil   -- id de l'interaction actuellement focusée (sous le viseur)
local nuiReady     = false
local _nextId      = 0

local function newId()
  _nextId = _nextId + 1
  return 'i' .. tostring(_nextId)
end

-- ===========================================================================
-- Détection : qui est sous mon viseur ?
--
-- Pour chaque entité enregistrée :
--   - calcule la distance ped→entity
--   - si dist ≤ options.distance, calcule l'angle entre la caméra forward
--     et la direction ped→entity
--   - si l'angle est petit (cosine > 0.85 ≈ 30°), c'est "visé"
--   - score = dist * (1 - cosine) → lower = mieux. On garde le plus petit.
--
-- Pour les zones : pas d'angle, juste distance.
-- ===========================================================================

local function getCameraForward()
  local rot = GetGameplayCamRot(2)
  local rx = math.rad(rot.x)
  local rz = math.rad(rot.z)
  local cx = math.cos(rx)
  return vector3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx))
end

local function pickBest()
  local ped = PlayerPedId()
  if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

  local pedCoords = GetEntityCoords(ped)
  local fwd = getCameraForward()

  local bestId, bestScore = nil, math.huge

  for id, it in pairs(interactions) do
    if it.kind == 'entity' then
      local handle = it.entity
      if handle and DoesEntityExist(handle) then
        local ePos = GetEntityCoords(handle)
        local toEntity = ePos - pedCoords
        local dist = #toEntity
        local maxDist = it.options.distance or 3.0
        if dist <= maxDist and dist > 0.01 then
          local dir = toEntity / dist
          local cosA = dir.x * fwd.x + dir.y * fwd.y + dir.z * fwd.z
          -- cosA > 0.85 ≈ ±30° autour du viseur. On peut relaxer un peu pour la souplesse.
          if cosA > 0.80 then
            local score = dist * (1.0 - cosA + 0.05)   -- favorise proche ET centré
            if score < bestScore then
              bestScore = score
              bestId = id
            end
          end
        end
      end
    elseif it.kind == 'zone' then
      local c = it.coords
      local toZone = c - pedCoords
      local dist = #toZone
      local maxDist = it.options.radius or 2.0
      if dist <= maxDist then
        -- Les zones sont plus permissives : pas de check angle, on les considère
        -- comme un fallback si rien d'autre n'est visé.
        local score = dist * 0.5 + 1.0   -- offset pour qu'une entité visée prime
        if score < bestScore then
          bestScore = score
          bestId = id
        end
      end
    end
  end

  return bestId
end

-- ===========================================================================
-- NUI : affichage du prompt
-- ===========================================================================

local function pushShow(id)
  local it = interactions[id]
  if not it or not nuiReady then return end
  SendNUIMessage({
    action = 'show',
    label  = it.options.label or 'Interagir',
    key    = it.options.key   or 'E',
    icon   = it.options.icon  or nil,
  })
end

local function pushHide()
  if not nuiReady then return end
  SendNUIMessage({ action = 'hide' })
end

RegisterNUICallback('ready', function(_, cb)
  nuiReady = true
  cb({ ok = true })
end)

-- ===========================================================================
-- Boucle principale : update activeId à 100ms (perf-friendly)
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(100)
    if not IsPauseMenuActive() and IsScreenFadedIn() then
      local found = pickBest()
      if found ~= activeId then
        activeId = found
        if found then pushShow(found) else pushHide() end
      end
    elseif activeId then
      activeId = nil
      pushHide()
    end
  end
end)

-- ===========================================================================
-- Boucle de touche : check si on appuie sur E (ou la touche définie)
-- ===========================================================================
-- Mappage clavier basique. Étendre si besoin.
local KEY_CODES = {
  E = 38, F = 23, G = 47, H = 74, X = 73, Y = 246, V = 0, B = 29, R = 45,
  ['1'] = 157, ['2'] = 158, ['3'] = 160, ['4'] = 164, ['5'] = 165,
}

CreateThread(function()
  while true do
    if activeId then
      Wait(0)
      local it = interactions[activeId]
      if it then
        local key = (it.options.key or 'E'):upper()
        local code = KEY_CODES[key] or 38
        if IsControlJustPressed(0, code) then
          local cb = it.options.onSelect
          if cb then
            local ok, err = pcall(cb)
            if not ok then
              print(('[sl-interact] callback error : %s'):format(tostring(err)))
            end
          end
        end
      end
    else
      Wait(150)
    end
  end
end)

-- ===========================================================================
-- API publique (exports)
-- ===========================================================================

local function addEntity(entity, options)
  if not entity or not DoesEntityExist(entity) then return nil end
  options = options or {}
  local id = newId()
  interactions[id] = { id = id, kind = 'entity', entity = entity, options = options }
  return id
end

local function addZone(opts)
  if type(opts) ~= 'table' or not opts.coords then return nil end
  local id = newId()
  interactions[id] = {
    id = id, kind = 'zone',
    coords = opts.coords,
    options = opts,
  }
  return id
end

local function removeById(id)
  if not id then return end
  if activeId == id then
    activeId = nil
    pushHide()
  end
  interactions[id] = nil
end

local function removeByEntity(entity)
  for id, it in pairs(interactions) do
    if it.kind == 'entity' and it.entity == entity then
      removeById(id)
    end
  end
end

local function clearAll()
  interactions = {}
  activeId = nil
  pushHide()
end

exports('AddEntity',     addEntity)
exports('AddZone',       addZone)
exports('Remove',        removeById)
exports('RemoveEntity',  removeByEntity)
exports('Clear',         clearAll)
exports('CurrentTarget', function() return activeId end)

-- Cleanup au resource stop / restart
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then clearAll() end
end)
