local SL = exports['sl-core']

local function getLicense(source)
  local player = SL:GetPlayer(source)
  return player and player.identifiers and player.identifiers.license or nil
end

local function getAccountId(source)
  local player = SL:GetPlayer(source)
  return player and player.accountId or nil
end

local function getSexFor(source)
  local player = SL:GetPlayer(source)
  if player and player.data and player.data.identity and player.data.identity.sex == 'f' then return 'f' end
  return 'm'
end

ActiveCuratorSources = ActiveCuratorSources or {}

local function getStats(sex, accountId, phase)
  local phaseStats = SL:DB().single(
    [[SELECT
        COUNT(*) AS y,
        SUM(CASE WHEN pass_count >= 2 THEN 1 ELSE 0 END) AS y_reviewed,
        SUM(CASE WHEN pass_count < 2 THEN 1 ELSE 0 END) AS y_to_review
      FROM sl_clothing_outfit_votes
      WHERE sex = ? AND vote = 'yes' AND phase = ?]],
    { sex, phase }
  )
  local totalStats = SL:DB().single(
    [[SELECT COUNT(*) AS y FROM sl_clothing_outfit_votes WHERE sex = ? AND vote = 'yes']],
    { sex }
  )
  local session = accountId and SL:DB().single(
    'SELECT votes_yes FROM sl_clothing_curator_session WHERE account_id = ?',
    { accountId }
  ) or nil
  local activeCount = 0
  local activeBreakdown = { p1 = 0, p2 = 0, p3 = 0, p4 = 0 }
  for src, info in pairs(ActiveCuratorSources) do
    activeCount = activeCount + 1
    if info.phase and activeBreakdown[info.phase] ~= nil then
      activeBreakdown[info.phase] = activeBreakdown[info.phase] + 1
    end
  end

  return {
    yes_phase = phaseStats and phaseStats.y or 0,
    yes_reviewed = phaseStats and phaseStats.y_reviewed or 0,
    yes_to_review = phaseStats and phaseStats.y_to_review or 0,
    yes_total = totalStats and totalStats.y or 0,
    mine_yes = session and session.votes_yes or 0,
    active_users = activeCount,
    active_breakdown = activeBreakdown,
  }
end

local function markActive(source, phase, mode)
  ActiveCuratorSources[source] = { phase = phase, mode = mode, ts = os.time() }
end

local function unmarkActive(source)
  ActiveCuratorSources[source] = nil
end

AddEventHandler('playerDropped', function()
  unmarkActive(source)
end)

lib.callback.register('sl-curator:leave', function(source)
  unmarkActive(source)
  return true
end)

local function getCurrentPhase(accountId)
  if not accountId then return 'p1' end
  local row = SL:DB().single('SELECT phase FROM sl_clothing_curator_session WHERE account_id = ?', { accountId })
  return (row and row.phase) or 'p1'
end

lib.callback.register('sl-curator:setEnum', function(source, enumData)
  CuratorEnum[source] = enumData
  return true
end)

lib.callback.register('sl-curator:next', function(source, payload)
  payload = payload or {}
  local accountId = getAccountId(source)
  local sex = getSexFor(source)
  local phase = payload.phase or getCurrentPhase(accountId)
  if not Curator.Phases[phase] then phase = 'p1' end
  local mode = payload.mode or 'normal'

  markActive(source, phase, mode)

  local res, err
  if mode == 'review' then
    res, err = CuratorGenerator.generateForReview(sex, phase)
  else
    res, err = CuratorGenerator.generateForPhase(source, sex, phase, payload.excludeHashes or {})
  end
  if not res then return { ok = false, error = err, phase = phase, mode = mode } end

  local phaseConf = Curator.Phases[phase]
  return {
    ok = true,
    outfit = res.outfit,
    hash = res.hash,
    sex = sex,
    phase = phase,
    mode = mode,
    isReview = res.isReview == true,
    phaseLabel = phaseConf.label,
    phaseTitle = phaseConf.title,
    phaseDesc = phaseConf.desc,
    slots = phaseConf.testSlots,
    extraSlot = phaseConf.extraSlot and (phaseConf.extraSlot.kind .. ':' .. phaseConf.extraSlot.id) or nil,
    stats = getStats(sex, accountId, phase),
  }
end)

lib.callback.register('sl-curator:voteYes', function(source, payload)
  if not payload or not payload.outfit or not payload.hash then
    return { ok = false, error = 'missing fields' }
  end
  local sex = payload.sex or getSexFor(source)
  local phase = payload.phase or 'p1'
  local accountId = getAccountId(source)
  local license = getLicense(source)

  pcall(function()
    SL:DB().query([[
      INSERT INTO sl_clothing_outfit_votes (sex, outfit_hash, outfit_json, vote, voted_by, phase)
      VALUES (?, ?, ?, 'yes', ?, ?)
      ON DUPLICATE KEY UPDATE vote = 'yes', voted_by = VALUES(voted_by), voted_at = CURRENT_TIMESTAMP
    ]], { sex, payload.hash, json.encode(payload.outfit), license, phase })
  end)

  if accountId then
    pcall(function()
      SL:DB().query([[
        INSERT INTO sl_clothing_curator_session (account_id, votes_yes, phase)
        VALUES (?, 1, ?)
        ON DUPLICATE KEY UPDATE votes_yes = votes_yes + 1, phase = VALUES(phase)
      ]], { accountId, phase })
    end)
  end

  return { ok = true, stats = getStats(sex, accountId, phase) }
end)

lib.callback.register('sl-curator:setPhase', function(source, phase)
  if not phase or not Curator.Phases[phase] then return { ok = false } end
  local accountId = getAccountId(source)
  if accountId then
    pcall(function()
      SL:DB().query([[
        INSERT INTO sl_clothing_curator_session (account_id, phase)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE phase = VALUES(phase)
      ]], { accountId, phase })
    end)
  end
  return { ok = true, phase = phase }
end)

lib.callback.register('sl-curator:confirmReview', function(source, payload)
  if not payload or not payload.hash then return { ok = false } end
  local sex = payload.sex or getSexFor(source)
  local phase = payload.phase or 'p1'
  pcall(function()
    SL:DB().query(
      'UPDATE sl_clothing_outfit_votes SET pass_count = 2 WHERE sex = ? AND outfit_hash = ?',
      { sex, payload.hash }
    )
  end)
  return { ok = true, stats = getStats(sex, getAccountId(source), phase) }
end)

lib.callback.register('sl-curator:rejectReview', function(source, payload)
  if not payload or not payload.hash then return { ok = false } end
  local sex = payload.sex or getSexFor(source)
  local phase = payload.phase or 'p1'
  pcall(function()
    SL:DB().query(
      'DELETE FROM sl_clothing_outfit_votes WHERE sex = ? AND outfit_hash = ?',
      { sex, payload.hash }
    )
  end)
  local accountId = getAccountId(source)
  if accountId then
    pcall(function()
      SL:DB().query(
        'UPDATE sl_clothing_curator_session SET votes_yes = GREATEST(votes_yes - 1, 0) WHERE account_id = ?',
        { accountId })
    end)
  end
  return { ok = true, stats = getStats(sex, accountId, phase) }
end)

lib.callback.register('sl-curator:undo', function(source, payload)
  if not payload or not payload.hash then return { ok = false } end
  local sex = payload.sex or getSexFor(source)
  local accountId = getAccountId(source)
  local phase = payload.phase or 'p1'

  pcall(function()
    SL:DB().query('DELETE FROM sl_clothing_outfit_votes WHERE sex = ? AND outfit_hash = ?',
      { sex, payload.hash })
  end)
  if accountId then
    pcall(function()
      SL:DB().query(
        'UPDATE sl_clothing_curator_session SET votes_yes = GREATEST(votes_yes - 1, 0) WHERE account_id = ?',
        { accountId })
    end)
  end
  return { ok = true, stats = getStats(sex, accountId, phase) }
end)

lib.callback.register('sl-curator:dumpPresets', function(source, phase)
  local sex = getSexFor(source)
  local rows
  if phase then
    rows = SL:DB().query([[
      SELECT phase, outfit_json FROM sl_clothing_outfit_votes
      WHERE sex = ? AND vote = 'yes' AND phase = ? ORDER BY voted_at DESC LIMIT 500
    ]], { sex, phase }) or {}
  else
    rows = SL:DB().query([[
      SELECT phase, outfit_json FROM sl_clothing_outfit_votes
      WHERE sex = ? AND vote = 'yes' ORDER BY voted_at DESC LIMIT 500
    ]], { sex }) or {}
  end
  local presets = {}
  for _, row in ipairs(rows) do
    local outfit = type(row.outfit_json) == 'string' and json.decode(row.outfit_json) or row.outfit_json
    table.insert(presets, { sex = sex, phase = row.phase, outfit = outfit })
  end
  return { ok = true, count = #presets, presets = presets }
end)
