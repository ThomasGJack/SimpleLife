print('[sl-phone/server] api_apps.lua loaded')

local SL = exports['sl-core']

-- ===========================================================================
-- HELPERS (shared)
-- ===========================================================================

local function getEntry(source)
  local c = Cache[source]
  if not c then return nil, 'phone not loaded' end
  return c
end

-- ===========================================================================
-- BANQUE MOBILE
-- ===========================================================================

-- Retourne les soldes du joueur via sl-economy
lib.callback.register('sl-phone:bankBalances', function(source)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end
  local ok, balances = pcall(function()
    return exports['sl-economy']:GetBalances(source)
  end)
  if not ok or not balances then
    return { ok = false, error = 'service indisponible' }
  end
  return { ok = true, balances = balances }
end)

-- Effectue un virement vers un numero de telephone
lib.callback.register('sl-phone:bankTransfer', function(source, toNumber, account, amount, reason)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return { ok = false, error = 'Montant invalide' } end

  -- Comptes valides cote sl-economy : cash | bank | crypto (PAS de "black").
  account = tostring(account or 'cash')
  if account ~= 'cash' and account ~= 'bank' and account ~= 'crypto' then
    return { ok = false, error = 'Compte invalide' }
  end

  local normalizedTo = Phone.NormalizeNumber(toNumber)
  if #normalizedTo < 10 then return { ok = false, error = 'Numero invalide' } end
  if normalizedTo == entry.number then return { ok = false, error = 'Virement vers soi-meme interdit' } end

  local toSource, toCharId = FindByNumber(normalizedTo)
  if not toCharId then return { ok = false, error = 'Numero inconnu' } end

  reason = tostring(reason or 'Virement phone'):sub(1, 64)

  -- Destinataire DOIT etre en ligne : sl-economy n'expose pas de credit offline
  -- par characterId. Refuser plutot que de detruire l'argent de l'emetteur.
  if not toSource then
    return { ok = false, error = 'Destinataire hors-ligne' }
  end

  -- Transfer renvoie (false, raison) en cas d'echec logique (solde insuffisant,
  -- compte invalide, limite depassee). On capture A LA FOIS le succes du pcall
  -- ET la valeur de retour, sinon un echec serait rapporte comme succes.
  local pok, transferOk, transferErr = pcall(function()
    return exports['sl-economy']:Transfer(source, toSource, account, amount, reason)
  end)

  if not pok then
    return { ok = false, error = 'Service bancaire indisponible' }
  end
  if not transferOk then
    return { ok = false, error = transferErr or 'Virement echoue (solde insuffisant ?)' }
  end

  -- Notif au destinataire si en ligne
  if toSource then
    TriggerClientEvent('ox_lib:notify', toSource, {
      description = ('📲 Virement recu : +$%d (%s)'):format(amount, reason),
      type = 'success',
    })
  end

  return { ok = true }
end)

-- ===========================================================================
-- RESEAU SOCIAL
-- ===========================================================================

-- Fil de posts recent (50 derniers)
lib.callback.register('sl-phone:social:getFeed', function(source)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err, posts = {} } end

  local rows = SL:DB().query([[
    SELECT id, author_number, body, image, likes, created_at
    FROM sl_phone_social_posts
    ORDER BY created_at DESC
    LIMIT 50
  ]], {}) or {}

  -- Marque les posts de l'utilisateur courant
  for _, r in ipairs(rows) do
    r.is_mine = (Phone.NormalizeNumber(r.author_number) == entry.number)
  end

  return { ok = true, posts = rows }
end)

-- Creer un post
lib.callback.register('sl-phone:social:createPost', function(source, body, image)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  body = tostring(body or ''):sub(1, 280):gsub('^%s+', ''):gsub('%s+$', '')
  if body == '' then return { ok = false, error = 'Contenu vide' } end

  local img = nil
  if image and tostring(image) ~= '' then
    img = tostring(image):sub(1, 255)
  end

  local id = SL:DB().insert([[
    INSERT INTO sl_phone_social_posts (character_id, author_number, body, image)
    VALUES (?, ?, ?, ?)
  ]], { entry.characterId, entry.number, body, img })

  return { ok = true, id = id }
end)

-- Liker un post
lib.callback.register('sl-phone:social:likePost', function(source, postId)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  postId = tonumber(postId)
  if not postId then return { ok = false, error = 'id invalide' } end

  SL:DB().query([[
    UPDATE sl_phone_social_posts SET likes = likes + 1 WHERE id = ?
  ]], { postId })

  local row = SL:DB().single('SELECT likes FROM sl_phone_social_posts WHERE id = ?', { postId })
  return { ok = true, likes = row and tonumber(row.likes) or 0 }
end)

-- Supprimer un post (propriétaire uniquement)
lib.callback.register('sl-phone:social:deletePost', function(source, postId)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  postId = tonumber(postId)
  if not postId then return { ok = false, error = 'id invalide' } end

  local row = SL:DB().single('SELECT character_id FROM sl_phone_social_posts WHERE id = ?', { postId })
  if not row or tonumber(row.character_id) ~= entry.characterId then
    return { ok = false, error = 'interdit' }
  end

  SL:DB().query('DELETE FROM sl_phone_social_posts WHERE id = ?', { postId })
  return { ok = true }
end)

-- ===========================================================================
-- MARKETPLACE
-- ===========================================================================

-- Liste des annonces (50 dernieres)
lib.callback.register('sl-phone:market:getListings', function(source)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err, listings = {} } end

  local rows = SL:DB().query([[
    SELECT id, character_id, title, price, body, number, created_at
    FROM sl_phone_market_listings
    ORDER BY created_at DESC
    LIMIT 50
  ]], {}) or {}

  for _, r in ipairs(rows) do
    r.is_mine = (tonumber(r.character_id) == entry.characterId)
  end

  return { ok = true, listings = rows }
end)

-- Creer une annonce
lib.callback.register('sl-phone:market:createListing', function(source, title, price, body)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  title = tostring(title or ''):sub(1, 80):gsub('^%s+', ''):gsub('%s+$', '')
  body  = tostring(body  or ''):sub(1, 280):gsub('^%s+', ''):gsub('%s+$', '')
  price = math.floor(tonumber(price) or 0)

  if title == '' then return { ok = false, error = 'Titre requis' } end
  if body == ''  then return { ok = false, error = 'Description requise' } end
  if price < 0   then return { ok = false, error = 'Prix invalide' } end

  local id = SL:DB().insert([[
    INSERT INTO sl_phone_market_listings (character_id, title, price, body, number)
    VALUES (?, ?, ?, ?, ?)
  ]], { entry.characterId, title, price, body, entry.number })

  return { ok = true, id = id }
end)

-- Supprimer une annonce (propriétaire uniquement)
lib.callback.register('sl-phone:market:deleteListing', function(source, listingId)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  listingId = tonumber(listingId)
  if not listingId then return { ok = false, error = 'id invalide' } end

  local row = SL:DB().single('SELECT character_id FROM sl_phone_market_listings WHERE id = ?', { listingId })
  if not row or tonumber(row.character_id) ~= entry.characterId then
    return { ok = false, error = 'interdit' }
  end

  SL:DB().query('DELETE FROM sl_phone_market_listings WHERE id = ?', { listingId })
  return { ok = true }
end)

-- ===========================================================================
-- URGENCES 911 / SAMU
-- ===========================================================================

-- Reçoit { service, message, coords } depuis le client
lib.callback.register('sl-phone:emergency', function(source, service, message, coords)
  local entry, err = getEntry(source)
  if not entry then return { ok = false, error = err } end

  service = tostring(service or ''):lower()
  if service ~= 'police' and service ~= 'ambulance' then
    return { ok = false, error = 'Service inconnu' }
  end

  message = tostring(message or ''):sub(1, 255):gsub('^%s+', ''):gsub('%s+$', '')
  if message == '' then return { ok = false, error = 'Message requis' } end

  if type(coords) ~= 'table' then
    return { ok = false, error = 'Coordonnees manquantes' }
  end

  local coordsJson = json.encode({ x = coords.x or 0, y = coords.y or 0, z = coords.z or 0 })

  SL:DB().insert([[
    INSERT INTO sl_phone_emergency_calls (from_number, service, coords, message)
    VALUES (?, ?, ?, ?)
  ]], { entry.number, service, coordsJson, message })

  -- Recuperer les joueurs en service pour le bon job
  local jobName = (service == 'police') and 'police' or 'ambulance'
  local onDuty = {}
  local jobsOk, jobsResult = pcall(function()
    return exports['sl-jobs']:GetOnDutyPlayers(jobName)
  end)
  if jobsOk and type(jobsResult) == 'table' then
    onDuty = jobsResult
  end

  -- Notification avec blip GPS vers le joueur appelant
  local serviceLabel = (service == 'police') and 'Police' or 'SAMU'
  local serviceEmoji = (service == 'police') and '🚔' or '🚑'

  for _, officerSrc in ipairs(onDuty) do
    -- Notif ox_lib
    TriggerClientEvent('ox_lib:notify', officerSrc, {
      description = ('%s Appel urgence %s | %s | Numero: %s'):format(
        serviceEmoji, serviceLabel, message, Phone.FormatNumber(entry.number)),
      type = 'error',
      duration = 15000,
    })
    -- Blip GPS : bus event avec les coordonnées
    TriggerClientEvent('sl:bus:dispatch', officerSrc, 'sl:phone:emergencyBlip', {
      coords    = { x = coords.x or 0, y = coords.y or 0, z = coords.z or 0 },
      number    = entry.number,
      service   = service,
      message   = message,
    })
  end

  -- Si aucun officier en service, notifier quand même l'appelant
  if #onDuty == 0 then
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Alerte envoyee. Aucun %s disponible pour le moment.'):format(serviceLabel),
      type = 'inform',
    })
  else
    TriggerClientEvent('ox_lib:notify', source, {
      description = ('Alerte envoyee aux %s (%d en service).'):format(serviceLabel, #onDuty),
      type = 'success',
    })
  end

  return { ok = true, onDuty = #onDuty }
end)

-- ===========================================================================
-- EVENT : notification phone quand un skill monte de niveau
-- ===========================================================================
AddEventHandler('sl:skills:levelUp', function(payload)
  if not payload or not payload.source or not payload.skill or not payload.level then return end
  local src = payload.source
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:phone:skillLevelUp', {
    skill = payload.skill,
    level = payload.level,
  })
end)
