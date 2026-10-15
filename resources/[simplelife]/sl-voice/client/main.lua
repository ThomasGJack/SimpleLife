print('[sl-voice/client] main.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- État courant
-- ===========================================================================
local currentIndex = Voice.DefaultModeIndex or 2
local isTalking    = false
local nuiReady     = false

-- ===========================================================================
-- Application du mode via Mumble (FiveM voice backend)
--   - MumbleSetTalkerProximity : portée d'émission (jusqu'où on est entendu).
--   - MumbleSetAudioOutputDistance : portée d'écoute (jusqu'où on entend).
--     On la fixe au max pour qu'on entende tous les autres modes ; ce sont
--     les autres joueurs qui contrôlent leur propre portée d'émission.
--   - NetworkSetTalkerProximity : fallback compat anciens serveurs.
-- ===========================================================================
local function applyMumble(distance)
  -- Natives Mumble (FiveM moderne)
  if MumbleSetTalkerProximity then
    MumbleSetTalkerProximity(distance + 0.0)
  end
  if Voice.HearMaxRange and MumbleSetAudioOutputDistance then
    MumbleSetAudioOutputDistance(Voice.MaxDistance() + 0.0)
  elseif MumbleSetAudioOutputDistance then
    MumbleSetAudioOutputDistance(distance + 0.0)
  end
  -- Fallback legacy (encore utilisé sur certains serveurs)
  if NetworkSetTalkerProximity then
    NetworkSetTalkerProximity(distance + 0.0)
  end
end

local function pushHud()
  if not nuiReady then return end
  local mode = Voice.GetMode(currentIndex)
  if not mode then return end
  SendNUIMessage({
    action   = 'state',
    key      = mode.key,
    label    = mode.label,
    icon     = mode.icon,
    color    = mode.color,
    distance = mode.distance,
    talking  = isTalking,
  })
end

local function setMode(index, silent)
  local mode = Voice.GetMode(index)
  if not mode then return end
  currentIndex = index
  applyMumble(mode.distance)
  pushHud()
  if not silent then
    lib.notify({
      title       = 'Voix',
      description = ('%s %s · %dm'):format(mode.icon, mode.label, math.floor(mode.distance)),
      type        = 'inform',
      duration    = 1500,
    })
  end
end

local function cycleMode()
  setMode(Voice.NextIndex(currentIndex), false)
end

-- ===========================================================================
-- Détection "parle ?"
-- ===========================================================================
CreateThread(function()
  while true do
    Wait(Voice.TalkPollMs or 120)
    local pid = PlayerId()
    local talking = NetworkIsPlayerTalking(pid) == true
    if talking ~= isTalking then
      isTalking = talking
      pushHud()
    end
  end
end)

-- ===========================================================================
-- NUI ready (le NUI envoie un message dès qu'il est prêt)
-- ===========================================================================
RegisterNUICallback('ready', function(_, cb)
  nuiReady = true
  pushHud()
  cb({ ok = true })
end)

-- ===========================================================================
-- Boot : applique le mode par défaut dès qu'on est en session
-- ===========================================================================
CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  Wait(800)
  setMode(Voice.DefaultModeIndex or 2, true)
  -- 2 retries au cas où Mumble met du temps à se brancher
  Wait(2000); setMode(currentIndex, true)
  Wait(3000); setMode(currentIndex, true)
end)

-- Réapplique après un respawn / changement de personnage
AddEventHandler('sl:core:characterSelected', function()
  CreateThread(function()
    Wait(1500)
    setMode(currentIndex, true)
  end)
end)

-- ===========================================================================
-- Commande + keybind
-- ===========================================================================
RegisterCommand('voicemode', cycleMode, false)
RegisterCommand('voice_whisper', function() setMode(1, false) end, false)
RegisterCommand('voice_normal',  function() setMode(2, false) end, false)
RegisterCommand('voice_shout',   function() setMode(3, false) end, false)

-- Keymap centralisé dans sl-keybinds (catégorie "SimpleLife" dans Settings, touche N)

-- ===========================================================================
-- Registration avec sl-core (informatif, pas critique)
-- ===========================================================================
CreateThread(function()
  Wait(2000)
  local apiOk, api = pcall(function() return SL:CoreApi() end)
  pcall(function()
    SL:RegisterModule({
      name = GetCurrentResourceName(),
      version = '0.1.0',
      coreApi = apiOk and api or 1,
      deps = { 'sl-core@^0.1' },
    })
  end)
end)

-- ===========================================================================
-- API exports : pour qu'un autre module (sl-radio, sl-phone) puisse forcer
-- temporairement la portée (ex : crier dans la radio = portée fixe).
-- ===========================================================================
exports('GetMode', function()
  local m = Voice.GetMode(currentIndex)
  return m and m.key or 'normal', m and m.distance or 8.0
end)
exports('SetMode', function(key)
  for i, m in ipairs(Voice.Modes) do
    if m.key == key then setMode(i, false); return true end
  end
  return false
end)
exports('CycleMode', cycleMode)
exports('IsTalking', function() return isTalking end)
