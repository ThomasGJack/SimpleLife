local SL = exports['sl-core']

local function persistJob(source)
  local entry = Cache[source]
  if not entry then return end
  local player = SL:GetPlayer(source)
  if not player then return end
  player.data = player.data or {}
  player.data.job = { name = entry.name, grade = entry.grade, onDuty = entry.onDuty }
  player.modified = true
end

local function emitJobChanged(source, entry)
  local payload = {
    source = source,
    name = entry.name,
    grade = entry.grade,
    onDuty = entry.onDuty,
    label = Jobs.GetJob(entry.name) and Jobs.GetJob(entry.name).label or entry.name,
    gradeLabel = Jobs.GetGrade(entry.name, entry.grade) and Jobs.GetGrade(entry.name, entry.grade).label or '?',
  }
  TriggerEvent('sl:jobs:jobChanged', payload)
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:jobs:jobChanged', payload)
end

local function setJob(source, jobName, gradeId)
  gradeId = tonumber(gradeId) or 0
  if not Jobs.IsValid(jobName, gradeId) then return false, 'invalid job/grade' end
  local entry = Cache[source]
  if not entry then return false, 'not loaded' end
  entry.name = jobName
  entry.grade = gradeId
  entry.onDuty = false
  persistJob(source)
  emitJobChanged(source, entry)
  return true
end

local function setGrade(source, gradeId)
  gradeId = tonumber(gradeId) or 0
  local entry = Cache[source]
  if not entry then return false, 'not loaded' end
  if not Jobs.IsValid(entry.name, gradeId) then return false, 'invalid grade' end
  entry.grade = gradeId
  persistJob(source)
  emitJobChanged(source, entry)
  return true
end

local function setDuty(source, onDuty)
  local entry = Cache[source]
  if not entry then return false, 'not loaded' end
  entry.onDuty = onDuty == true
  persistJob(source)
  TriggerEvent('sl:jobs:dutyChanged', {
    source = source, name = entry.name, grade = entry.grade, onDuty = entry.onDuty,
  })
  TriggerClientEvent('sl:bus:dispatch', source, 'sl:jobs:dutyChanged', {
    name = entry.name, grade = entry.grade, onDuty = entry.onDuty,
  })
  return true, entry.onDuty
end

local function getJob(source)
  local entry = Cache[source]
  if not entry then return nil end
  return {
    name = entry.name,
    grade = entry.grade,
    onDuty = entry.onDuty,
    label = Jobs.GetJob(entry.name) and Jobs.GetJob(entry.name).label or entry.name,
    gradeLabel = Jobs.GetGrade(entry.name, entry.grade) and Jobs.GetGrade(entry.name, entry.grade).label or '?',
  }
end

local function getOnDutyPlayers(jobName)
  local out = {}
  for source, entry in pairs(Cache) do
    if entry.name == jobName and entry.onDuty then
      table.insert(out, source)
    end
  end
  return out
end

exports('SetJob', setJob)
exports('SetGrade', setGrade)
exports('SetDuty', setDuty)
exports('GetJob', getJob)
exports('GetOnDutyPlayers', getOnDutyPlayers)
exports('GetCatalog', function() return Jobs.Catalog end)

lib.callback.register('sl-jobs:setDuty', function(source, onDuty)
  local ok, res = setDuty(source, onDuty)
  return { ok = ok, onDuty = res }
end)

lib.callback.register('sl-jobs:apply', function(source, jobName)
  local job = Jobs.GetJob(jobName)
  if not job then return { ok = false, error = 'unknown job' } end
  if not job.isPublic then return { ok = false, error = 'ce métier est privé (contacte un patron)' } end
  local ok, err = setJob(source, jobName, 0)
  if not ok then return { ok = false, error = err } end
  return { ok = true, name = jobName, grade = 0 }
end)

lib.callback.register('sl-jobs:publicList', function()
  return Jobs.PublicList()
end)

lib.callback.register('sl-jobs:getMine', function(source)
  return getJob(source)
end)
