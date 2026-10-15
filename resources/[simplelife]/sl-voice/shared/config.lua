Voice = Voice or {}

-- Modes de voix par ordre (cycle dans cet ordre avec la touche).
-- distance = portée d'émission en MÈTRES (FiveM Mumble proximity).
Voice.Modes = {
  { key = 'whisper', label = 'Chuchoter', distance = 2.0,  icon = '🤫', color = '#60a5fa' },
  { key = 'normal',  label = 'Normal',    distance = 8.0,  icon = '🗣️', color = '#4ade80' },
  { key = 'shout',   label = 'Crier',     distance = 18.0, icon = '📢', color = '#fb923c' },
}

-- Index de départ (= "Normal").
Voice.DefaultModeIndex = 2

-- Touche de cycle (utilisateur peut la changer dans les paramètres FiveM).
Voice.CycleKey = 'N'

-- Position du HUD à l'écran (CSS coords).
Voice.HudPosition = { bottom = 240, right = 24 }    -- au-dessus du HUD sl-hud

-- Tick de polling pour détecter qu'on parle (ms).
Voice.TalkPollMs = 120

-- Active la sortie audio à distance maximale (on entend toujours tous les modes).
-- Si false, on n'entend que dans son propre rayon → joueurs en mode whisper
-- n'entendent que les autres whisperers. Recommandé true.
Voice.HearMaxRange = true

-- Helpers

function Voice.GetMode(index)
  return Voice.Modes[index]
end

function Voice.NextIndex(index)
  index = index + 1
  if index > #Voice.Modes then index = 1 end
  return index
end

function Voice.MaxDistance()
  local max = 0
  for _, m in ipairs(Voice.Modes) do
    if m.distance > max then max = m.distance end
  end
  return max
end
