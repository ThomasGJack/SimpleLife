print('[sl-phone/server] api.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- Active calls tracking (pour routing audio Mumble)
-- ActiveCalls[source] = { peerSource, channelId, startedAt }
-- ===========================================================================
ActiveCalls = ActiveCalls or {}

-- Compteur de canaux Mumble. Chaque appel reçoit un canal unique.
-- Plage choisie haute pour éviter collisions avec d'éventuels canaux radio futurs.
local _channelCounter = 100000
local function nextChannelId()
  _channelCounter = _channelCounter + 1
  return _channelCounter
end

-- Démarre le routing audio pour 2 joueurs : leur dit de joindre le canal Mumble
-- en LISTEN (pour entendre l'autre) + voice target (pour parler dans le canal).
-- Les joueurs restent sur leur proximité (sl-voice continue de marcher), donc
-- les bystanders entendent toujours leur moitié de la conversation.
local function startCallAudio(sourceA, sourceB)
  local channelId = nextChannelId()
  ActiveCalls[sourceA] = { peerSource = sourceB, channelId = channelId, startedAt = os.time() }
  ActiveCalls[sourceB] = { peerSource = sourceA, channelId = channelId, startedAt = os.time() }
  TriggerClientEvent('sl:bus:dispatch', sourceA, 'sl:phone:audioStart', { channelId = channelId, peerSource = sourceB })
  TriggerClientEvent('sl:bus:dispatch', sourceB, 'sl:phone:audioStart', { channelId = channelId, peerSource = sourceA })
end

local function stopCallAudio(source, alsoNotifyPeer)
  local entry = ActiveCalls[source]
  if not entry then return end
  local peer = entry.peerSource
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:phone:audioStop', { channelId = entry.channelId })
  if alsoNotifyPeer and peer and ActiveCalls[peer] then
    TriggerClientEvent('sl:bus:dispatch', peer, 'sl:phone:audioStop', { channelId = entry.channelId })
    ActiveCalls[peer] = nil
  end
  ActiveCalls[source] = nil
end

-- Exposé pour main.lua (cleanup au drop)
function PhoneStopCallAudio(source) stopCallAudio(source, true) end

-- ===========================================================================
-- helpers
-- ===========================================================================

local function getEntry(source)
  local c = Cache[source]
  if not c then return nil, 'phone not loaded' end
  return c
end

-- ===========================================================================
-- API
-- ===========================================================================

function PhoneSendSMS(source, toNumberRaw, body)
  local entry, err = getEntry(source); if not entry then return false, err end
  if not body or body == '' then return false, 'message vide' end
  if #body > (Phone.MaxMessageLength or 500) then return false, 'message trop long' end

  local toNumber = Phone.NormalizeNumber(toNumberRaw)
  if #toNumber < 10 then return false, 'numéro invalide' end
  if toNumber == entry.number then return false, 'vous ne pouvez pas vous SMS à vous-même' end

  local toSource, toCharId = FindByNumber(toNumber)
  if not toCharId then return false, 'numéro inconnu' end

  local db = SL:DB()
  local insertId = db.insert([[
    INSERT INTO sl_phone_messages (from_character_id, to_character_id, from_number, to_number, body)
    VALUES (?, ?, ?, ?, ?)
  ]], { entry.characterId, toCharId, entry.number, toNumber, body })

  if toSource then
    TriggerClientEvent('sl:bus:dispatch', toSource, 'sl:phone:smsReceived', {
      id = insertId,
      from = entry.number,
      body = body,
      time = os.time(),
    })
  end

  return true, insertId
end

function PhoneGetConversations(source)
  local entry, err = getEntry(source); if not entry then return {} end
  -- Pour chaque interlocuteur distinct, dernier message + count unread + last_at.
  local rows = SL:DB().query([[
    SELECT
      CASE WHEN from_character_id = ? THEN to_number ELSE from_number END AS peer_number,
      MAX(created_at) AS last_at,
      SUM(CASE WHEN to_character_id = ? AND is_read = 0 THEN 1 ELSE 0 END) AS unread,
      (SELECT body  FROM sl_phone_messages m2
        WHERE ((m2.from_character_id = m1.from_character_id AND m2.to_character_id = m1.to_character_id)
            OR (m2.from_character_id = m1.to_character_id   AND m2.to_character_id = m1.from_character_id))
        ORDER BY m2.created_at DESC LIMIT 1) AS last_body,
      (SELECT from_character_id FROM sl_phone_messages m3
        WHERE ((m3.from_character_id = m1.from_character_id AND m3.to_character_id = m1.to_character_id)
            OR (m3.from_character_id = m1.to_character_id   AND m3.to_character_id = m1.from_character_id))
        ORDER BY m3.created_at DESC LIMIT 1) AS last_from_cid
    FROM sl_phone_messages m1
    WHERE from_character_id = ? OR to_character_id = ?
    GROUP BY peer_number
    ORDER BY last_at DESC
  ]], { entry.characterId, entry.characterId, entry.characterId, entry.characterId }) or {}

  -- Marque la direction "out" pour le dernier message si on était l'émetteur.
  for _, r in ipairs(rows) do
    r.last_outgoing = (tonumber(r.last_from_cid) == entry.characterId)
    r.last_from_cid = nil
  end
  return rows
end

function PhoneGetMessagesWith(source, peerNumberRaw, limit)
  local entry, err = getEntry(source); if not entry then return {} end
  local peerNumber = Phone.NormalizeNumber(peerNumberRaw)
  if #peerNumber < 10 then return {} end
  local _, peerCharId = FindByNumber(peerNumber)
  if not peerCharId then return {} end

  limit = math.min(math.max(tonumber(limit) or Phone.SmsHistoryLimit, 1), 500)

  local rows = SL:DB().query([[
    SELECT id, from_character_id, to_character_id, from_number, to_number, body, is_read, created_at
    FROM sl_phone_messages
    WHERE (from_character_id = ? AND to_character_id = ?)
       OR (from_character_id = ? AND to_character_id = ?)
    ORDER BY created_at DESC
    LIMIT ]] .. limit, {
    entry.characterId, peerCharId,
    peerCharId, entry.characterId,
  }) or {}

  -- Renverse pour chronologique ASC (plus récent en bas)
  local out = {}
  for i = #rows, 1, -1 do
    local r = rows[i]
    r.outgoing = (tonumber(r.from_character_id) == entry.characterId)
    out[#out+1] = r
  end

  -- Marque comme lus côté reçus
  SL:DB().query([[
    UPDATE sl_phone_messages SET is_read = 1
    WHERE from_character_id = ? AND to_character_id = ? AND is_read = 0
  ]], { peerCharId, entry.characterId })

  return out
end

function PhoneGetUnreadCount(source)
  local entry, err = getEntry(source); if not entry then return 0 end
  local row = SL:DB().single([[
    SELECT COUNT(*) AS n FROM sl_phone_messages WHERE to_character_id = ? AND is_read = 0
  ]], { entry.characterId })
  return row and tonumber(row.n) or 0
end

-- ============= Contacts =============

function PhoneGetContacts(source)
  local entry, err = getEntry(source); if not entry then return {} end
  return SL:DB().query([[
    SELECT id, name, number, favorite, created_at
    FROM sl_phone_contacts
    WHERE character_id = ?
    ORDER BY favorite DESC, name ASC
  ]], { entry.characterId }) or {}
end

function PhoneAddContact(source, name, numberRaw)
  local entry, err = getEntry(source); if not entry then return false, err end
  name = tostring(name or ''):sub(1, 64):gsub('^%s+', ''):gsub('%s+$', '')
  local number = Phone.NormalizeNumber(numberRaw)
  if name == '' then return false, 'nom requis' end
  if #number < 10 then return false, 'numéro invalide' end
  local id = SL:DB().insert([[
    INSERT INTO sl_phone_contacts (character_id, name, number) VALUES (?, ?, ?)
  ]], { entry.characterId, name, number })
  return true, id
end

function PhoneUpdateContact(source, id, name, numberRaw, favorite)
  local entry, err = getEntry(source); if not entry then return false, err end
  id = tonumber(id); if not id then return false, 'id invalide' end
  local row = SL:DB().single('SELECT character_id FROM sl_phone_contacts WHERE id = ?', { id })
  if not row or tonumber(row.character_id) ~= entry.characterId then return false, 'interdit' end
  name = tostring(name or ''):sub(1, 64):gsub('^%s+', ''):gsub('%s+$', '')
  local number = Phone.NormalizeNumber(numberRaw)
  if name == '' then return false, 'nom requis' end
  if #number < 10 then return false, 'numéro invalide' end
  SL:DB().query([[
    UPDATE sl_phone_contacts SET name = ?, number = ?, favorite = ? WHERE id = ?
  ]], { name, number, favorite and 1 or 0, id })
  return true
end

function PhoneDeleteContact(source, id)
  local entry, err = getEntry(source); if not entry then return false, err end
  id = tonumber(id); if not id then return false, 'id invalide' end
  local row = SL:DB().single('SELECT character_id FROM sl_phone_contacts WHERE id = ?', { id })
  if not row or tonumber(row.character_id) ~= entry.characterId then return false, 'interdit' end
  SL:DB().query('DELETE FROM sl_phone_contacts WHERE id = ?', { id })
  return true
end

-- ============= Calls (UI only en v1, pas d'audio routing) =============

function PhoneGetRecentCalls(source, limit)
  local entry, err = getEntry(source); if not entry then return {} end
  limit = math.min(math.max(tonumber(limit) or 30, 1), 100)
  local rows = SL:DB().query([[
    SELECT id, from_character_id, to_character_id, from_number, to_number,
           duration_sec, status, created_at
    FROM sl_phone_calls
    WHERE from_character_id = ? OR to_character_id = ?
    ORDER BY created_at DESC
    LIMIT ]] .. limit, { entry.characterId, entry.characterId }) or {}
  for _, r in ipairs(rows) do
    r.outgoing = (tonumber(r.from_character_id) == entry.characterId)
    r.peer_number = r.outgoing and r.to_number or r.from_number
  end
  return rows
end

function PhoneLogCall(source, toNumberRaw, status, durationSec)
  local entry, err = getEntry(source); if not entry then return false, err end
  local toNumber = Phone.NormalizeNumber(toNumberRaw)
  local _, peerCharId = FindByNumber(toNumber)
  SL:DB().insert([[
    INSERT INTO sl_phone_calls (from_character_id, to_character_id, from_number, to_number, duration_sec, status)
    VALUES (?, ?, ?, ?, ?, ?)
  ]], { entry.characterId, peerCharId, entry.number, toNumber, durationSec or 0, status or 'ended' })
  return true
end

-- Sonne le destinataire (UI seulement : son toast/banner "appel entrant")
function PhoneRing(source, toNumberRaw)
  local entry, err = getEntry(source); if not entry then return false, err end
  local toNumber = Phone.NormalizeNumber(toNumberRaw)
  local toSource, toCharId = FindByNumber(toNumber)
  if not toCharId then return false, 'numéro inconnu' end
  if not toSource then
    -- Hors-ligne → loggue en missed et notifie l'appelant
    PhoneLogCall(source, toNumber, 'missed', 0)
    return false, 'destinataire hors-ligne'
  end
  TriggerClientEvent('sl:bus:dispatch', toSource, 'sl:phone:incomingCall', {
    from = entry.number,
    fromSource = source,
  })
  return true
end

-- ===========================================================================
-- Exports publics
-- ===========================================================================
exports('GetMyNumber',          function(src) local c = Cache[src]; return c and c.number or nil end)
exports('GetCharacterByNumber', function(num) local _, cid = FindByNumber(num); return cid end)
exports('SendSMS',              PhoneSendSMS)
exports('GetUnreadCount',       PhoneGetUnreadCount)
exports('AddContact',           PhoneAddContact)

-- ===========================================================================
-- Callbacks ox_lib (client -> server)
-- ===========================================================================

lib.callback.register('sl-phone:getState', function(source)
  local entry = Cache[source]
  if not entry then return nil end
  return {
    number        = entry.number,
    contacts      = PhoneGetContacts(source),
    conversations = PhoneGetConversations(source),
    recentCalls   = PhoneGetRecentCalls(source, 30),
    unread        = PhoneGetUnreadCount(source),
    apps          = Phone.Apps,
  }
end)

lib.callback.register('sl-phone:sendSMS', function(source, toNumber, body)
  local ok, err = PhoneSendSMS(source, toNumber, body)
  return { ok = ok, error = err }
end)

lib.callback.register('sl-phone:getMessages', function(source, peerNumber)
  return PhoneGetMessagesWith(source, peerNumber, Phone.SmsHistoryLimit or 100)
end)

lib.callback.register('sl-phone:addContact', function(source, name, number)
  local ok, idOrErr = PhoneAddContact(source, name, number)
  if ok then return { ok = true, id = idOrErr } end
  return { ok = false, error = idOrErr }
end)

lib.callback.register('sl-phone:updateContact', function(source, id, name, number, favorite)
  local ok, err = PhoneUpdateContact(source, id, name, number, favorite)
  return { ok = ok, error = err }
end)

lib.callback.register('sl-phone:deleteContact', function(source, id)
  local ok, err = PhoneDeleteContact(source, id)
  return { ok = ok, error = err }
end)

lib.callback.register('sl-phone:ring', function(source, toNumber)
  local ok, err = PhoneRing(source, toNumber)
  return { ok = ok, error = err }
end)

lib.callback.register('sl-phone:logCall', function(source, toNumber, status, duration)
  PhoneLogCall(source, toNumber, status, duration)
  return true
end)

lib.callback.register('sl-phone:answerCall', function(source, fromSource)
  if not fromSource then return false end
  -- Notifie l'appelant que l'appel a été accepté
  TriggerClientEvent('sl:bus:dispatch', fromSource, 'sl:phone:callAccepted', { peerSource = source })
  -- Démarre le routing audio Mumble pour les 2 joueurs
  startCallAudio(source, fromSource)
  return true
end)

lib.callback.register('sl-phone:declineCall', function(source, fromSource)
  if not fromSource then return false end
  TriggerClientEvent('sl:bus:dispatch', fromSource, 'sl:phone:callDeclined', { peerSource = source })
  return true
end)

lib.callback.register('sl-phone:hangup', function(source, peerSource)
  -- Notifie le peer que l'appel est terminé
  if peerSource then
    TriggerClientEvent('sl:bus:dispatch', peerSource, 'sl:phone:callEnded', { peerSource = source })
  end
  -- Arrête le routing audio des deux côtés (si actif)
  stopCallAudio(source, true)
  return true
end)
