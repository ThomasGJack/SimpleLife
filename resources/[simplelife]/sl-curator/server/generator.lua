local SL = exports['sl-core']

CuratorEnum = CuratorEnum or {}

local function hashOutfit(sex, phase, outfit)
  local parts = { sex, phase or '' }
  local keys = {}
  for k, v in pairs(outfit) do
    if v and v.drawable ~= nil then
      table.insert(keys, k .. '=' .. tostring(v.drawable))
    end
  end
  table.sort(keys)
  for _, kv in ipairs(keys) do table.insert(parts, kv) end
  local raw = table.concat(parts, '|')
  local ok, hash = pcall(function() return SL:Hash(raw) end)
  if ok and hash then return hash end
  local h = 5381
  for i = 1, #raw do h = (h * 33 + raw:byte(i)) % 4294967296 end
  return string.format('%08x_%d', h, #raw)
end

local function getValidDrawables(enumData, kind, id)
  local map = enumData[kind] or {}
  local list = map[tostring(id)] or map[id] or {}
  local out = {}
  for _, d in ipairs(list) do
    if d.valid ~= false and d.drawable ~= -1 then
      table.insert(out, d.drawable)
    end
  end
  return out
end

local function buildNeutral()
  local outfit = {}
  for k, v in pairs(Curator.NeutralBase) do
    outfit[k] = { drawable = v.drawable, texture = v.texture or 0 }
  end
  return outfit
end

local function pickRandom(list)
  if not list or #list == 0 then return 0 end
  return list[math.random(1, #list)]
end

local function loadValidatedFromPhase(sex, phaseId, slotsNeeded)
  local rows = SL:DB().query([[
    SELECT outfit_json FROM sl_clothing_outfit_votes
    WHERE sex = ? AND vote = 'yes' AND phase = ?
    ORDER BY voted_at DESC LIMIT 300
  ]], { sex, phaseId }) or {}
  local out = {}
  for _, row in ipairs(rows) do
    local outfit = type(row.outfit_json) == 'string' and json.decode(row.outfit_json) or row.outfit_json
    if outfit then
      local sub = {}
      local complete = true
      for _, slot in ipairs(slotsNeeded) do
        local key = slot.kind .. ':' .. slot.id
        if outfit[key] then
          sub[key] = { drawable = outfit[key].drawable, texture = outfit[key].texture or 0 }
        else
          complete = false; break
        end
      end
      if complete then table.insert(out, sub) end
    end
  end
  return out
end

local function generateForPhase(source, sex, phase, excludeHashes)
  local enumData = CuratorEnum[source]
  if not enumData then return nil, 'no enum data' end
  local phaseConf = Curator.Phases[phase]
  if not phaseConf then return nil, 'invalid phase' end

  excludeHashes = excludeHashes or {}
  local excludeSet = {}
  for _, h in ipairs(excludeHashes) do excludeSet[h] = true end

  local prevValidated = nil
  if phaseConf.requiresPrev then
    local prevConf = Curator.Phases[phaseConf.requiresPrev]
    prevValidated = loadValidatedFromPhase(sex, phaseConf.requiresPrev, prevConf.testSlots)
    if #prevValidated == 0 then
      return nil, 'Aucune validation en ' .. phaseConf.requiresPrev .. ' — fais d\'abord cette phase'
    end
  end

  for _ = 1, 80 do
    local outfit = buildNeutral()

    if prevValidated then
      local base = prevValidated[math.random(1, #prevValidated)]
      for k, v in pairs(base) do outfit[k] = v end

      if phaseConf.extraSlot then
        local valid = getValidDrawables(enumData, phaseConf.extraSlot.kind, phaseConf.extraSlot.id)
        outfit[phaseConf.extraSlot.kind .. ':' .. phaseConf.extraSlot.id] = {
          drawable = pickRandom(valid), texture = 0
        }
      end
    else
      for _, slot in ipairs(phaseConf.testSlots) do
        local valid = getValidDrawables(enumData, slot.kind, slot.id)
        outfit[slot.kind .. ':' .. slot.id] = { drawable = pickRandom(valid), texture = 0 }
      end
    end

    local hash = hashOutfit(sex, phase, outfit)
    if not excludeSet[hash] then
      return { sex = sex, phase = phase, outfit = outfit, hash = hash }
    end
  end

  return nil, 'Plus de combinaisons fraîches pour cette session — change de phase ou recharge'
end

local function generateForReview(sex, phase)
  local row = SL:DB().single([[
    SELECT outfit_hash, outfit_json FROM sl_clothing_outfit_votes
    WHERE sex = ? AND vote = 'yes' AND phase = ? AND pass_count < 2
    ORDER BY voted_at ASC LIMIT 1
  ]], { sex, phase })
  if not row then return nil, 'Aucune tenue à revoir dans ' .. phase end
  local outfit = type(row.outfit_json) == 'string' and json.decode(row.outfit_json) or row.outfit_json
  return {
    sex = sex,
    phase = phase,
    outfit = outfit,
    hash = row.outfit_hash,
    isReview = true,
  }
end

CuratorGenerator = CuratorGenerator or {}
CuratorGenerator.generateForPhase = generateForPhase
CuratorGenerator.generateForReview = generateForReview
CuratorGenerator.hashOutfit = hashOutfit
