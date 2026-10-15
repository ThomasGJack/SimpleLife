print('[sl-phone/client] main.lua loaded')

-- ===========================================================================
-- État
-- ===========================================================================
local uiOpen   = false
local hasFocus = false
local lastState = nil
local myNumber  = nil

-- État d'un appel UI courant (v1 : pas de routing audio).
-- Forme : { peer = '5551234567', peerSource = src, status = 'outgoing'|'incoming'|'inCall', startedAt = os.time(), timeoutThread = handle }
local currentCall = nil

-- ===========================================================================
-- NUI helpers
-- ===========================================================================

local function setFocus(state)
  hasFocus = state
  SetNuiFocus(state, state)
  SetNuiFocusKeepInput(false)
end

local function nuiSend(msg)
  SendNUIMessage(msg)
end

local function fetchState()
  return lib.callback.await('sl-phone:getState', false)
end

local function hasPhoneItem()
  -- sl-inventory expose un export CLIENT 'HasItem' qui lit son cache local.
  -- Fallback : si l'export n'est pas dispo (resource pas encore loaded), on
  -- regarde lastState côté sl-phone qui contient l'état si l'inv est ouvert.
  local ok, has = pcall(function() return exports['sl-inventory']:HasItem('telephone', 1) end)
  if ok and type(has) == 'boolean' then return has end
  return false
end

local function openPhone()
  if uiOpen then return end
  if not lastState then lastState = fetchState() end
  if not lastState then
    lib.notify({ description = 'Téléphone indisponible.', type = 'error' })
    return
  end
  uiOpen = true
  setFocus(true)
  nuiSend({ action = 'open', state = lastState })
end

local function closePhone()
  if not uiOpen then return end
  uiOpen = false
  setFocus(false)
  nuiSend({ action = 'close' })
end

local function togglePhone()
  if uiOpen then closePhone(); return end
  if not hasPhoneItem() then
    lib.notify({ description = '📱 Vous n\'avez pas de téléphone.', type = 'error' })
    return
  end
  openPhone()
end

local function refreshFromServer()
  lastState = fetchState()
  if uiOpen and lastState then
    nuiSend({ action = 'sync', state = lastState })
  end
end

-- ===========================================================================
-- NUI callbacks
-- ===========================================================================

RegisterNUICallback('close', function(_, cb)
  closePhone(); cb({ ok = true })
end)

RegisterNUICallback('sendSMS', function(data, cb)
  local res = lib.callback.await('sl-phone:sendSMS', false, data.to, data.body)
  if res and res.ok then refreshFromServer() end
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('getMessages', function(data, cb)
  local msgs = lib.callback.await('sl-phone:getMessages', false, data.peer)
  cb({ messages = msgs or {} })
end)

RegisterNUICallback('addContact', function(data, cb)
  local res = lib.callback.await('sl-phone:addContact', false, data.name, data.number)
  if res and res.ok then refreshFromServer() end
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('updateContact', function(data, cb)
  local res = lib.callback.await('sl-phone:updateContact', false,
    data.id, data.name, data.number, data.favorite == true)
  if res and res.ok then refreshFromServer() end
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('deleteContact', function(data, cb)
  local res = lib.callback.await('sl-phone:deleteContact', false, data.id)
  if res and res.ok then refreshFromServer() end
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('refresh', function(_, cb)
  refreshFromServer()
  cb({ state = lastState })
end)

-- ===========================================================================
-- NUI callbacks — BANQUE MOBILE
-- ===========================================================================

RegisterNUICallback('bankBalances', function(_, cb)
  local res = lib.callback.await('sl-phone:bankBalances', false)
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('bankTransfer', function(data, cb)
  local res = lib.callback.await('sl-phone:bankTransfer', false,
    data.toNumber, data.account, data.amount, data.reason)
  cb(res or { ok = false, error = 'rpc failed' })
end)

-- ===========================================================================
-- NUI callbacks — RESEAU SOCIAL
-- ===========================================================================

RegisterNUICallback('social:getFeed', function(_, cb)
  local res = lib.callback.await('sl-phone:social:getFeed', false)
  cb(res or { ok = false, error = 'rpc failed', posts = {} })
end)

RegisterNUICallback('social:createPost', function(data, cb)
  local res = lib.callback.await('sl-phone:social:createPost', false, data.body, data.image)
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('social:likePost', function(data, cb)
  local res = lib.callback.await('sl-phone:social:likePost', false, data.id)
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('social:deletePost', function(data, cb)
  local res = lib.callback.await('sl-phone:social:deletePost', false, data.id)
  cb(res or { ok = false, error = 'rpc failed' })
end)

-- ===========================================================================
-- NUI callbacks — MARKETPLACE
-- ===========================================================================

RegisterNUICallback('market:getListings', function(_, cb)
  local res = lib.callback.await('sl-phone:market:getListings', false)
  cb(res or { ok = false, error = 'rpc failed', listings = {} })
end)

RegisterNUICallback('market:createListing', function(data, cb)
  local res = lib.callback.await('sl-phone:market:createListing', false,
    data.title, data.price, data.body)
  cb(res or { ok = false, error = 'rpc failed' })
end)

RegisterNUICallback('market:deleteListing', function(data, cb)
  local res = lib.callback.await('sl-phone:market:deleteListing', false, data.id)
  cb(res or { ok = false, error = 'rpc failed' })
end)

-- ===========================================================================
-- NUI callbacks — URGENCES 911 / SAMU
-- Les coordonnees GPS du joueur sont collectees ici cote client et envoyees
-- ===========================================================================

RegisterNUICallback('emergency', function(data, cb)
  local ped = PlayerPedId()
  local pedCoords = GetEntityCoords(ped)
  local res = lib.callback.await('sl-phone:emergency', false,
    data.service, data.message,
    { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z })
  cb(res or { ok = false, error = 'rpc failed' })
end)

-- ============= Calls (UI only) =============

local function clearCall()
  if currentCall and currentCall.timeoutThread then
    -- pas de cancel direct, on s'appuie sur l'état pour ignorer
  end
  currentCall = nil
end

local function notifyCall(payload)
  -- envoie à la NUI pour afficher l'écran d'appel
  nuiSend({ action = 'callUpdate', call = payload })
end

RegisterNUICallback('ringPeer', function(data, cb)
  local res = lib.callback.await('sl-phone:ring', false, data.number)
  if not res or not res.ok then
    cb(res or { ok = false, error = 'rpc failed' })
    return
  end
  currentCall = { peer = data.number, status = 'outgoing', startedAt = GetGameTimer() }
  notifyCall({ status = 'outgoing', peer = data.number })
  -- timeout sortant
  CreateThread(function()
    Wait((Phone.CallTimeoutSec or 30) * 1000)
    if currentCall and currentCall.status == 'outgoing' then
      lib.callback.await('sl-phone:logCall', false, data.number, 'missed', 0)
      currentCall = nil
      notifyCall({ status = 'ended', reason = 'no-answer' })
    end
  end)
  cb({ ok = true })
end)

RegisterNUICallback('answerCall', function(_, cb)
  if not currentCall or currentCall.status ~= 'incoming' then
    cb({ ok = false }); return
  end
  lib.callback.await('sl-phone:answerCall', false, currentCall.peerSource)
  currentCall.status = 'inCall'
  currentCall.startedAt = GetGameTimer()
  notifyCall({ status = 'inCall', peer = currentCall.peer })
  cb({ ok = true })
end)

RegisterNUICallback('declineCall', function(_, cb)
  if not currentCall or currentCall.status ~= 'incoming' then
    cb({ ok = false }); return
  end
  lib.callback.await('sl-phone:declineCall', false, currentCall.peerSource)
  lib.callback.await('sl-phone:logCall', false, currentCall.peer, 'declined', 0)
  currentCall = nil
  notifyCall({ status = 'ended', reason = 'declined' })
  cb({ ok = true })
end)

RegisterNUICallback('hangup', function(_, cb)
  if not currentCall then cb({ ok = false }); return end
  local duration = 0
  if currentCall.status == 'inCall' and currentCall.startedAt then
    duration = math.floor((GetGameTimer() - currentCall.startedAt) / 1000)
  end
  local peerSrc = currentCall.peerSource
  local peer    = currentCall.peer
  local status  = (currentCall.status == 'inCall') and 'ended' or 'declined'
  lib.callback.await('sl-phone:hangup', false, peerSrc)
  lib.callback.await('sl-phone:logCall', false, peer, status, duration)
  currentCall = nil
  notifyCall({ status = 'ended', reason = 'hangup' })
  cb({ ok = true })
end)

-- ===========================================================================
-- ROUTING AUDIO MUMBLE (Option B : réaliste)
--
-- Quand on est en appel :
--   - On RESTE sur notre canal de proximité (sl-voice continue) → les bystanders
--     entendent toujours notre moitié de la conversation.
--   - On AJOUTE un listen sur le canal du phone → on entend l'interlocuteur
--     même à 5 km (canal sans atténuation distance).
--   - On configure un voice target qui contient le canal phone → notre voix
--     part dans le canal phone aussi (en plus de la proximité par défaut).
--
-- Slot voice target 6 dédié au téléphone (slots 1-5 réservés futurs : radio,
-- canaux métier, etc.). Plage 1-30 dispo.
-- ===========================================================================

local PHONE_VOICE_TARGET_SLOT = 6
local activePhoneChannel = nil

local function mumbleAvailable()
  return type(MumbleIsConnected) == 'function' and MumbleIsConnected()
end

local function startPhoneAudio(channelId)
  if not channelId then return end
  -- En cas de double-démarrage (rare, mais defensive), on coupe d'abord l'ancien
  if activePhoneChannel then
    if type(MumbleRemoveVoiceChannelListen) == 'function' then
      pcall(MumbleRemoveVoiceChannelListen, activePhoneChannel)
    end
  end
  activePhoneChannel = channelId
  if not mumbleAvailable() then
    print('[sl-phone] Mumble indisponible, audio routing inactif')
    return
  end
  -- 1) Écouter le canal phone (= entendre l'interlocuteur)
  if type(MumbleAddVoiceChannelListen) == 'function' then
    pcall(MumbleAddVoiceChannelListen, channelId)
  end
  -- 2) Configurer un voice target avec le canal phone
  if type(MumbleClearVoiceTarget) == 'function' then
    pcall(MumbleClearVoiceTarget, PHONE_VOICE_TARGET_SLOT)
  end
  if type(MumbleAddVoiceTargetChannel) == 'function' then
    pcall(MumbleAddVoiceTargetChannel, PHONE_VOICE_TARGET_SLOT, channelId)
  end
  -- 3) Activer le target → notre voix part AUSSI dans le canal phone
  if type(MumbleSetVoiceTarget) == 'function' then
    pcall(MumbleSetVoiceTarget, PHONE_VOICE_TARGET_SLOT)
  end
  print(('[sl-phone] audio routing started : channel=%d (proximity sl-voice toujours actif)'):format(channelId))
end

local function stopPhoneAudio()
  if activePhoneChannel and type(MumbleRemoveVoiceChannelListen) == 'function' then
    pcall(MumbleRemoveVoiceChannelListen, activePhoneChannel)
  end
  if type(MumbleClearVoiceTarget) == 'function' then
    pcall(MumbleClearVoiceTarget, PHONE_VOICE_TARGET_SLOT)
  end
  if type(MumbleSetVoiceTarget) == 'function' then
    pcall(MumbleSetVoiceTarget, 0)   -- retour au target par défaut (proximité)
  end
  local ch = activePhoneChannel
  activePhoneChannel = nil
  if ch then print(('[sl-phone] audio routing stopped : channel=%d'):format(ch)) end
end

-- Export pour qu'un futur sl-radio puisse vérifier si on est en appel
exports('IsInCall', function() return activePhoneChannel ~= nil end)
exports('GetCallChannel', function() return activePhoneChannel end)

-- ===========================================================================
-- Events serveur
-- ===========================================================================
RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  if event == 'sl:phone:hydrated' and payload then
    myNumber = payload.number
    lastState = nil   -- force un refetch à l'ouverture

  elseif event == 'sl:phone:smsReceived' and payload then
    -- Notif systeme (toast in-phone si ouvert, ox_lib sinon)
    if uiOpen then
      nuiSend({ action = 'toast', text = ('📩 %s : %s'):format(
        Phone.FormatNumber(payload.from or ''), payload.body or ''), type = 'inform', duration = 5000 })
      refreshFromServer()
    else
      lib.notify({
        title = '📩 ' .. Phone.FormatNumber(payload.from or ''),
        description = payload.body or '',
        type = 'inform',
        duration = 6000,
      })
      lastState = nil  -- force refetch à la prochaine ouverture
    end

  elseif event == 'sl:phone:incomingCall' and payload then
    if currentCall then
      -- déjà en appel, on log un missed côté nous
      return
    end
    currentCall = {
      peer = payload.from,
      peerSource = payload.fromSource,
      status = 'incoming',
      startedAt = GetGameTimer(),
    }
    -- Notif systeme (toujours visible, même si phone fermé)
    lib.notify({
      title = '📞 Appel entrant',
      description = Phone.FormatNumber(payload.from or ''),
      type = 'inform',
      duration = 6000,
    })
    -- Ouvre auto le phone si on a l'item (sinon, c'est dommage on n'a pas pris l'appel)
    if hasPhoneItem() and not uiOpen then
      openPhone()
    end
    notifyCall({ status = 'incoming', peer = payload.from })
    -- timeout entrant
    CreateThread(function()
      Wait((Phone.CallTimeoutSec or 30) * 1000)
      if currentCall and currentCall.status == 'incoming' then
        currentCall = nil
        notifyCall({ status = 'ended', reason = 'missed' })
      end
    end)

  elseif event == 'sl:phone:callAccepted' and payload then
    if currentCall and currentCall.status == 'outgoing' then
      currentCall.peerSource = payload.peerSource
      currentCall.status = 'inCall'
      currentCall.startedAt = GetGameTimer()
      notifyCall({ status = 'inCall', peer = currentCall.peer })
    end

  elseif event == 'sl:phone:callDeclined' then
    if currentCall and currentCall.status == 'outgoing' then
      lib.callback.await('sl-phone:logCall', false, currentCall.peer, 'declined', 0)
      currentCall = nil
      notifyCall({ status = 'ended', reason = 'declined' })
    end

  elseif event == 'sl:phone:callEnded' then
    if currentCall then
      local duration = 0
      if currentCall.status == 'inCall' and currentCall.startedAt then
        duration = math.floor((GetGameTimer() - currentCall.startedAt) / 1000)
      end
      lib.callback.await('sl-phone:logCall', false, currentCall.peer,
        (currentCall.status == 'inCall') and 'ended' or 'missed', duration)
      currentCall = nil
      notifyCall({ status = 'ended', reason = 'peer-hangup' })
    end
    -- Coupe le routing audio (le serveur a déjà envoyé audioStop mais on est defensive)
    stopPhoneAudio()

  elseif event == 'sl:phone:audioStart' and payload and payload.channelId then
    -- Serveur nous dit de joindre un canal Mumble pour l'audio de l'appel.
    -- Cf. Option B : on reste sur proximité + on AJOUTE le canal phone.
    startPhoneAudio(payload.channelId)

  elseif event == 'sl:phone:audioStop' then
    stopPhoneAudio()

  elseif event == 'sl:phone:emergencyBlip' and payload then
    -- Cree un blip temporaire GPS vers les coordonnees de l'appelant d'urgence
    local c = payload.coords or {}
    local x, y, z = c.x or 0, c.y or 0, c.z or 0
    local blip = AddBlipForCoord(x, y, z)
    local isPolice = (payload.service == 'police')
    SetBlipSprite(blip, isPolice and 161 or 153)
    SetBlipColour(blip, isPolice and 38 or 1)
    SetBlipScale(blip, 1.3)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Urgence %s | %s'):format(
      isPolice and 'Police' or 'SAMU',
      tostring(payload.message or '')))
    EndTextCommandSetBlipName(blip)
    -- Auto-remove apres 5 minutes
    CreateThread(function()
      Wait(300000)
      if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)

  elseif event == 'sl:phone:skillLevelUp' and payload then
    -- Notification optionnelle quand un skill monte de niveau
    if uiOpen then
      nuiSend({ action = 'toast',
        text = ('Niveau %s atteint : %d !'):format(tostring(payload.skill or ''), tonumber(payload.level) or 0),
        type = 'success', duration = 4000 })
    else
      lib.notify({
        title = 'Competence augmentee',
        description = ('Niveau %s : %d'):format(tostring(payload.skill or ''), tonumber(payload.level) or 0),
        type = 'success',
        duration = 5000,
      })
    end
  end
end)

-- Hook depuis sl-inventory : effet 'open_phone' quand on utilise l'item.
RegisterNetEvent('sl-inventory:effect', function(effect)
  if effect and effect.type == 'open_phone' then
    if not uiOpen then openPhone() end
  end
end)

-- ===========================================================================
-- Commandes / keymap
-- ===========================================================================
RegisterCommand('phone', togglePhone, false)
-- Keymap centralisé dans sl-keybinds (catégorie "SimpleLife" dans Settings)

-- ESC pour fermer
CreateThread(function()
  while true do
    if uiOpen then
      if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 200) then
        closePhone()
      end
      Wait(0)
    else
      Wait(300)
    end
  end
end)

-- Au respawn / character change, reset cache local + coupe le routing audio
AddEventHandler('sl:core:characterSelected', function()
  lastState = nil; myNumber = nil; currentCall = nil
  stopPhoneAudio()
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    if hasFocus then setFocus(false) end
    stopPhoneAudio()  -- sécurité : ne pas laisser un canal Mumble écouté
  end
end)
