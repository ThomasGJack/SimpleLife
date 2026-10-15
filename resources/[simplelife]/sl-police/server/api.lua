print('[sl-police/server] api.lua loaded')

-- sl-core handle (les locals ne traversent pas les fichiers d'une resource :
-- ce fichier doit redeclarer son propre SL, sinon SL:DB() indexe un nil global)
local SL = exports['sl-core']

-- ===========================================================================
-- Helpers internes
-- ===========================================================================
local function isOnline(src)
  return src and GetPlayerName(src) ~= nil
end

-- ===========================================================================
-- IsCuffed(src) -> bool
-- ===========================================================================
function IsCuffedFn(src)
  return Cuffed[src] ~= nil
end

-- ===========================================================================
-- Cuff(by, target) -> bool, err
-- ===========================================================================
function CuffFn(by, target)
  if not isOnline(target) then return false, 'target offline' end
  if Cuffed[target]       then return false, 'already cuffed' end

  Cuffed[target] = by
  if Cache[target] then Cache[target].cuffed = true; Cache[target].cuffedBy = by end

  -- Notif au target
  TriggerClientEvent('ox_lib:notify', target, {
    description = 'Vous avez ete menotte.',
    type        = 'error',
  })
  -- Dispatch bus -> client pour appliquer les controles
  TriggerClientEvent('sl:bus:dispatch', target, 'sl:police:applyCuff', { by = by })
  -- Event global serveur
  TriggerEvent('sl:police:cuffed', { target = target, by = by })

  return true
end

-- ===========================================================================
-- Uncuff(by, target) -> bool, err
-- ===========================================================================
function UncuffFn(by, target)
  if not Cuffed[target] then return false, 'not cuffed' end

  Cuffed[target] = nil
  if Cache[target] then Cache[target].cuffed = false; Cache[target].cuffedBy = nil end

  TriggerClientEvent('ox_lib:notify', target, {
    description = 'Vous avez ete demenotte.',
    type        = 'success',
  })
  TriggerClientEvent('sl:bus:dispatch', target, 'sl:police:applyUncuff', {})
  TriggerEvent('sl:police:uncuffed', { target = target })

  return true
end

-- ===========================================================================
-- Jail(target, seconds) -> bool, err
-- ===========================================================================
function JailFn(target, seconds)
  if not isOnline(target) then return false, 'target offline' end
  seconds = math.max(30, math.floor(tonumber(seconds) or 60))

  -- TP vers Bolingbroke
  TriggerClientEvent('sl:bus:dispatch', target, 'sl:police:jailTeleport', {
    coords  = { x = Police.Coords.Prison.x, y = Police.Coords.Prison.y, z = Police.Coords.Prison.z },
    seconds = seconds,
  })

  -- Declenchement timer cote serveur pour liberation automatique
  if Jailed[target] then
    -- reset du timer existant
    Jailed[target] = nil
  end
  Jailed[target] = { endAt = os.time() + seconds }

  TriggerEvent('sl:police:jailed', { target = target, seconds = seconds })

  -- Thread de liberation
  CreateThread(function()
    Wait(seconds * 1000)
    -- Verifier que le joueur est toujours online et en prison
    if not Jailed[target] then return end
    Jailed[target] = nil
    if not isOnline(target) then return end
    -- Liberation : TP sortie
    TriggerClientEvent('sl:bus:dispatch', target, 'sl:police:jailRelease', {
      coords = { x = Police.Coords.PrisonExit.x, y = Police.Coords.PrisonExit.y, z = Police.Coords.PrisonExit.z },
    })
    TriggerClientEvent('ox_lib:notify', target, {
      description = 'Vous avez purge votre peine. Vous etes libre.',
      type        = 'success',
      duration    = 8000,
    })
  end)

  return true
end

-- ===========================================================================
-- AddCharge(citizenId, charge, fine) -> bool, err
-- Insere ou met a jour le casier ; deduit la somme du compte bancaire
-- ===========================================================================
function AddChargeFn(citizenId, charge, fine)
  if not citizenId or citizenId == '' then return false, 'no citizenId' end
  fine = math.max(0, math.floor(tonumber(fine) or 0))

  -- Chercher un enregistrement existant
  local existing = SL:DB().single(
    'SELECT id, charges, total_fine FROM sl_police_records WHERE citizen_id = ?',
    { citizenId })

  if existing then
    -- Ajouter la charge au JSON existant
    local charges = {}
    local ok, decoded = pcall(function() return json.decode(existing.charges or '[]') end)
    if ok and type(decoded) == 'table' then charges = decoded end
    table.insert(charges, {
      label      = charge,
      fine       = fine,
      created_at = os.date('%Y-%m-%d %H:%M:%S'),
    })
    local newTotal = (tonumber(existing.total_fine) or 0) + fine
    SL:DB().update(
      'UPDATE sl_police_records SET charges = ?, total_fine = ? WHERE id = ?',
      { json.encode(charges), newTotal, existing.id })
  else
    local charges = json.encode({
      { label = charge, fine = fine, created_at = os.date('%Y-%m-%d %H:%M:%S') }
    })
    SL:DB().insert(
      'INSERT INTO sl_police_records (citizen_id, charges, total_fine, created_at) VALUES (?, ?, ?, NOW())',
      { citizenId, charges, fine })
  end

  -- Deduire l'amende du compte bancaire si le joueur est en ligne
  if fine > 0 then
    for src, entry in pairs(Cache) do
      if entry.citizenId == citizenId and isOnline(src) then
        local ok2, err2 = pcall(function()
          exports['sl-economy']:RemoveMoney(src, 'bank', fine, 'Amende police: ' .. charge)
        end)
        if not ok2 then
          print('[sl-police] RemoveMoney error: ' .. tostring(err2))
        end
        TriggerClientEvent('ox_lib:notify', src, {
          description = ('Amende de $%d — %s'):format(fine, charge),
          type        = 'error',
          duration    = 8000,
        })
        break
      end
    end
  end

  return true
end

-- ===========================================================================
-- Exports publics (INTEGRATION.md)
-- ===========================================================================
exports('IsCuffed',   IsCuffedFn)
exports('Cuff',       CuffFn)
exports('Jail',       JailFn)
exports('AddCharge',  AddChargeFn)

-- ===========================================================================
-- Events reseau entrants depuis le client
-- ===========================================================================

-- Demande menottage (cop -> serveur)
RegisterNetEvent('sl:police:net:cuff', function(targetSrc)
  local src = source
  -- Verifier que le cop est en service
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local ok, err = CuffFn(src, targetSrc)
  if not ok then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Impossible : ' .. tostring(err), type = 'error' })
  else
    TriggerClientEvent('ox_lib:notify', src, { description = 'Joueur menotte.', type = 'success' })
  end
end)

-- Demande demenottage (cop -> serveur)
RegisterNetEvent('sl:police:net:uncuff', function(targetSrc)
  local src = source
  if not OnDuty[src] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Vous devez etre en service.', type = 'error' })
    return
  end
  local ok, err = UncuffFn(src, targetSrc)
  if not ok then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Impossible : ' .. tostring(err), type = 'error' })
  else
    TriggerClientEvent('ox_lib:notify', src, { description = 'Joueur demenotte.', type = 'success' })
  end
end)

-- Drag/escorte : attacher le menotte au cop
RegisterNetEvent('sl:police:net:drag', function(targetSrc)
  local src = source
  if not OnDuty[src] then return end
  if not Cuffed[targetSrc] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Ce joueur n est pas menotte.', type = 'error' })
    return
  end
  -- Notif au target
  TriggerClientEvent('ox_lib:notify', targetSrc, { description = 'Un officier vous escorte.', type = 'inform' })
  -- Dispatch pour le client du cop (attach les entites)
  TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:startDrag', { target = targetSrc })
end)

-- Mettre en vehicule : /putin
RegisterNetEvent('sl:police:net:putin', function(targetSrc, vehicleNetId, seat)
  local src = source
  if not OnDuty[src] then return end
  if not Cuffed[targetSrc] then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Ce joueur n est pas menotte.', type = 'error' })
    return
  end
  TriggerClientEvent('sl:bus:dispatch', targetSrc, 'sl:police:forceInVehicle', {
    vehicleNetId = vehicleNetId,
    seat         = seat or -2,
  })
  TriggerClientEvent('ox_lib:notify', src, { description = 'Joueur mis dans le vehicule.', type = 'success' })
end)

-- Saisie item lors de la fouille
RegisterNetEvent('sl:police:net:seizeItem', function(targetSrc, itemName, count)
  local src = source
  if not OnDuty[src] then return end
  count = math.max(1, math.floor(tonumber(count) or 1))

  local okR = pcall(function()
    exports['sl-inventory']:RemoveItem(targetSrc, itemName, count)
  end)
  local okA = pcall(function()
    exports['sl-inventory']:AddItem(src, itemName, count)
  end)

  if okR and okA then
    TriggerClientEvent('ox_lib:notify', src, {
      description = ('Item saisi : %s x%d'):format(itemName, count),
      type        = 'success',
    })
    TriggerClientEvent('ox_lib:notify', targetSrc, {
      description = ('Item confisque : %s x%d'):format(itemName, count),
      type        = 'error',
    })
    -- Raffraichir la NUI de fouille cote cop
    local items = exports['sl-inventory']:GetItems(targetSrc)
    TriggerClientEvent('sl:bus:dispatch', src, 'sl:police:searchSync', {
      targetSrc = targetSrc,
      items     = items,
    })
  else
    TriggerClientEvent('ox_lib:notify', src, { description = 'Echec de la saisie.', type = 'error' })
  end
end)

-- ===========================================================================
-- Callbacks lib pour la NUI MDT
-- ===========================================================================

-- Recherche citoyen par nom ou citizenId
lib.callback.register('sl-police:mdt:searchCitizen', function(source, query)
  if not OnDuty[source] then return nil end
  query = tostring(query or ''):sub(1, 64)
  if query == '' then return {} end

  -- Le nom n'est PAS une colonne : il vit dans le JSON data.$.identity.firstName/lastName
  -- (cf. sl-core/sql/001_init.sql + sl-identity/server/creation.lua).
  local rows = SL:DB().query(
    [[SELECT id, citizen_id,
             JSON_UNQUOTE(JSON_EXTRACT(data, '$.identity.firstName')) AS first_name,
             JSON_UNQUOTE(JSON_EXTRACT(data, '$.identity.lastName'))  AS last_name
        FROM sl_characters
       WHERE deleted_at IS NULL
         AND (citizen_id LIKE ?
              OR CONCAT(
                   COALESCE(JSON_UNQUOTE(JSON_EXTRACT(data, '$.identity.firstName')), ''),
                   ' ',
                   COALESCE(JSON_UNQUOTE(JSON_EXTRACT(data, '$.identity.lastName')), '')
                 ) LIKE ?)
       LIMIT ?]],
    { '%' .. query .. '%', '%' .. query .. '%', Police.MDTSearchLimit })

  if not rows then return {} end

  local results = {}
  for _, row in ipairs(rows) do
    -- Recuperer le casier
    local record = SL:DB().single(
      'SELECT charges, total_fine, created_at FROM sl_police_records WHERE citizen_id = ?',
      { row.citizen_id })
    local charges = {}
    if record and record.charges then
      local ok, decoded = pcall(json.decode, record.charges)
      if ok and type(decoded) == 'table' then charges = decoded end
    end
    table.insert(results, {
      citizenId  = row.citizen_id,
      firstName  = row.first_name or '',
      lastName   = row.last_name or '',
      totalFine  = record and tonumber(record.total_fine) or 0,
      charges    = charges,
      since      = record and record.created_at or nil,
    })
  end
  return results
end)

-- Liste des BOLOs
lib.callback.register('sl-police:mdt:getBolos', function(source)
  if not OnDuty[source] then return {} end
  local rows = SL:DB().query(
    [[SELECT b.id, b.citizen_id, b.reason, b.created_by, b.created_at,
             JSON_UNQUOTE(JSON_EXTRACT(c.data, '$.identity.firstName')) AS first_name,
             JSON_UNQUOTE(JSON_EXTRACT(c.data, '$.identity.lastName'))  AS last_name
        FROM sl_police_bolos b
        LEFT JOIN sl_characters c ON c.citizen_id = b.citizen_id
       ORDER BY b.created_at DESC
       LIMIT 50]],
    {})
  return rows or {}
end)

-- Ajouter un BOLO
lib.callback.register('sl-police:mdt:addBolo', function(source, citizenId, reason)
  if not OnDuty[source] then return false end
  citizenId = tostring(citizenId or ''):sub(1, 20)
  reason    = tostring(reason    or ''):sub(1, 200)
  if citizenId == '' or reason == '' then return false end

  local byCzid = GetCitizenId(source) or 'inconnu'
  SL:DB().insert(
    'INSERT INTO sl_police_bolos (citizen_id, reason, created_by, created_at) VALUES (?, ?, ?, NOW())',
    { citizenId, reason, byCzid })
  return true
end)

-- Ajouter une charge depuis NUI MDT (event cote serveur)
RegisterNetEvent('sl:police:net:addCharge', function(citizenId, charge, fine)
  local src = source
  if not OnDuty[src] then return end
  AddChargeFn(citizenId, charge, fine)
end)

-- Supprimer un BOLO
lib.callback.register('sl-police:mdt:deleteBolo', function(source, boloId)
  if not OnDuty[source] then return false end
  SL:DB().update('DELETE FROM sl_police_bolos WHERE id = ?', { boloId })
  return true
end)

-- Membres en service
lib.callback.register('sl-police:mdt:getOnDuty', function(source)
  if not OnDuty[source] then return {} end
  -- GetOnDutyPlayers renvoie un tableau de sources (nombres), pas des objets :
  -- on resout ici nom + grade pour que la NUI affiche autre chose que "Officier".
  local ok, list = pcall(function()
    return exports['sl-jobs']:GetOnDutyPlayers(Police.JobName)
  end)
  if not ok then return {} end
  local result = {}
  for _, srcId in ipairs(list or {}) do
    local firstName, lastName, grade = nil, nil, nil
    local okP, player = pcall(function() return SL:GetPlayer(srcId) end)
    if okP and player and player.data and player.data.identity then
      firstName = player.data.identity.firstName
      lastName  = player.data.identity.lastName
    end
    local okJ, job = pcall(function() return exports['sl-jobs']:GetJob(srcId) end)
    if okJ and job then grade = job.gradeLabel or job.grade end
    table.insert(result, {
      source    = srcId,
      firstName = firstName,
      lastName  = lastName,
      name      = (firstName or lastName) and ((firstName or '') .. ' ' .. (lastName or '')) or ('Officier #' .. tostring(srcId)),
      grade     = grade,
    })
  end
  return result
end)

-- Fouille : recuperer l'inventaire du target
lib.callback.register('sl-police:search:getItems', function(source, targetSrc)
  if not OnDuty[source] then return nil end
  targetSrc = tonumber(targetSrc)
  if not targetSrc then return nil end

  local ok, items = pcall(function()
    return exports['sl-inventory']:GetItems(targetSrc)
  end)
  if not ok then return nil end
  return { items = items, targetSrc = targetSrc }
end)
