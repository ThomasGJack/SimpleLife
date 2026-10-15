print('[sl-hunger/client] main.lua loaded')

-- ===========================================================================
-- État local
-- ===========================================================================
local stats = {
  hunger  = 100,
  thirst  = 100,
  stamina = 100,
  max     = 100,
}
local nuiReady   = false
local prevAlertHunger = nil   -- pour ne notifier qu'une fois par passage de seuil
local prevAlertThirst = nil

-- ===========================================================================
-- Helpers
-- ===========================================================================
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

local function pushHud()
  if not nuiReady then return end
  SendNUIMessage({
    action  = 'state',
    hunger  = math.floor(stats.hunger),
    thirst  = math.floor(stats.thirst),
    stamina = math.floor(stats.stamina),
    max     = stats.max,
    colors  = Hunger.HUDColors,
  })
end

local function maybeAlert(value, statName, prev)
  -- alerte sur passage descendant d'un seuil de Hunger.AlertThresholds
  for _, t in ipairs(Hunger.AlertThresholds or {}) do
    if prev and prev > t and value <= t then
      local label = (statName == 'hunger') and 'Faim' or 'Soif'
      local emoji = (statName == 'hunger') and '🍖' or '💧'
      if t == 0 then
        lib.notify({
          title = emoji .. ' ' .. label,
          description = 'CRITIQUE — vous prenez des dégâts.',
          type = 'error', duration = 6000,
        })
      else
        lib.notify({
          title = emoji .. ' ' .. label,
          description = ('Faible (%d%%)'):format(t),
          type = 'warning', duration = 5000,
        })
      end
      return
    end
  end
end

-- ===========================================================================
-- Sync depuis serveur (faim/soif)
-- ===========================================================================
RegisterNetEvent('sl-hunger:sync', function(payload)
  if not payload then return end
  local oldH = stats.hunger
  local oldT = stats.thirst
  stats.hunger = tonumber(payload.hunger) or stats.hunger
  stats.thirst = tonumber(payload.thirst) or stats.thirst
  stats.max    = tonumber(payload.max)    or stats.max
  -- Alertes seulement après le 1er sync (pour pas spam au boot)
  if prevAlertHunger ~= nil then maybeAlert(stats.hunger, 'hunger', oldH) end
  if prevAlertThirst ~= nil then maybeAlert(stats.thirst, 'thirst', oldT) end
  prevAlertHunger = stats.hunger
  prevAlertThirst = stats.thirst
  pushHud()
end)

-- Dégâts envoyés par le serveur quand faim ou soif à 0
RegisterNetEvent('sl-hunger:damage', function(payload)
  local ped = PlayerPedId()
  if not ped or ped == 0 or not DoesEntityExist(ped) then return end
  if IsEntityDead(ped) then return end
  local dmg = (payload and payload.dmg) or 1
  local hp = GetEntityHealth(ped)
  SetEntityHealth(ped, math.max(0, hp - dmg))
end)

-- ===========================================================================
-- Stamina (client-only) + Sprint lock
--   - drain en sprint, regen au repos
--   - drain x1.5 si faim<30 ou soif<30
--   - sprint complètement désactivé si stamina<=0 OR faim<10 OR soif<10
-- ===========================================================================

local function isSprinting(ped)
  return IsPedSprinting(ped) == true
end

local sprintLockReason = nil   -- "stamina" | "hunger" | "thirst" | nil

local function shouldLockSprint()
  if stats.hunger < (Hunger.SprintLockThreshold or 10) then return 'hunger' end
  if stats.thirst < (Hunger.SprintLockThreshold or 10) then return 'thirst' end
  if stats.stamina <= 0 then return 'stamina' end
  return nil
end

CreateThread(function()
  local lastTickMs = GetGameTimer()
  local lastLockMsg = 0
  while true do
    Wait(0)
    local now = GetGameTimer()
    local dt  = (now - lastTickMs) / 1000.0
    lastTickMs = now

    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then

      -- Stamina drain / regen
      local sprinting = isSprinting(ped)
      local drainMult = 1.0
      if stats.hunger < 30 or stats.thirst < 30 then drainMult = Hunger.StaminaDrainBoost or 1.5 end

      if sprinting then
        stats.stamina = stats.stamina - (Hunger.StaminaDrainPerSec * drainMult * dt)
      else
        stats.stamina = stats.stamina + (Hunger.StaminaRegenPerSec * dt)
      end
      stats.stamina = clamp(stats.stamina, 0, Hunger.StaminaMax or 100)

      -- Sprint lock
      local lockReason = shouldLockSprint()
      sprintLockReason = lockReason
      if lockReason then
        -- 21 = INPUT_SPRINT, 22 = INPUT_JUMP (on garde le saut), on coupe juste sprint
        DisableControlAction(0, 21, true)  -- shift gauche = sprint
        -- notif espaceé pour pas spam
        if now - lastLockMsg > 6000 and sprinting then
          local emoji = lockReason == 'stamina' and '😮‍💨' or (lockReason == 'hunger' and '🍖' or '💧')
          local label = lockReason == 'stamina' and 'essoufflé' or (lockReason == 'hunger' and 'trop faim' or 'trop soif')
          lib.notify({ description = ('%s Vous êtes %s — impossible de sprinter.'):format(emoji, label),
                       type = 'error', duration = 2500 })
          lastLockMsg = now
        end
      end
    end

    -- Push HUD seulement si la stamina a sensiblement changé
    -- (on push aussi à chaque sync server pour hunger/thirst → pas besoin de spammer ici)
    if math.floor(stats.stamina) ~= (stats._lastDisplayedStamina or -1) then
      stats._lastDisplayedStamina = math.floor(stats.stamina)
      pushHud()
    end
  end
end)

-- ===========================================================================
-- NUI ready
-- ===========================================================================
RegisterNUICallback('ready', function(_, cb)
  nuiReady = true
  pushHud()
  cb({ ok = true })
end)

-- ===========================================================================
-- Initial fetch au caractère selected (sl-core déclenche server-side
-- characterSelected → server push sl-hunger:sync, donc rien à faire ici
-- en plus, mais on prévoit le fallback)
-- ===========================================================================
AddEventHandler('sl:core:characterSelected', function()
  CreateThread(function()
    Wait(800)
    local res = lib.callback.await('sl-hunger:getState', false)
    if res then
      stats.hunger = res.hunger
      stats.thirst = res.thirst
      stats.max    = res.max or 100
      prevAlertHunger = stats.hunger
      prevAlertThirst = stats.thirst
      pushHud()
    end
  end)
end)
