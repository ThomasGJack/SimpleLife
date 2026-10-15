SL = SL or {}
SL.Migrations = { applied = {} }

local BOOTSTRAP_TABLE = [[
CREATE TABLE IF NOT EXISTS sl_migrations (
  filename VARCHAR(255) PRIMARY KEY,
  resource VARCHAR(64) NOT NULL,
  hash VARCHAR(64) NOT NULL,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_resource (resource)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local function listMigrationsFor(resource)
  local indexContent = LoadResourceFile(resource, 'sql/index.lua')
  if not indexContent then return {} end
  local chunk, err = load(indexContent, '@' .. resource .. '/sql/index.lua', 't', {})
  if not chunk then
    print(('^1[sl-core] migrations: failed to parse %s/sql/index.lua: %s^0'):format(resource, tostring(err)))
    return {}
  end
  local ok, result = pcall(chunk)
  if not ok or type(result) ~= 'table' then
    print(('^1[sl-core] migrations: %s/sql/index.lua did not return a table^0'):format(resource))
    return {}
  end
  return result
end

local function listSlResources()
  local out = {}
  local count = GetNumResources()
  for i = 0, count - 1 do
    local r = GetResourceByFindIndex(i)
    if r and r:sub(1, 3) == 'sl-' and GetResourceState(r) == 'started' then
      table.insert(out, r)
    end
  end
  -- ORDRE CRITIQUE : sl-core EN PREMIER. Ses tables de base (sl_accounts,
  -- sl_characters) sont referencees par des FOREIGN KEY dans presque tous les
  -- autres modules. L'ordre d'indexation FiveM (GetResourceByFindIndex) n'est
  -- PAS deterministe -> sans ce tri, un module peut migrer avant sl-core et sa
  -- FK echoue (errno 150 "Foreign key constraint is incorrectly formed").
  -- Reste en ordre alphabetique apres sl-core (les FK inter-module pointent
  -- toutes vers sl-core ou vers une table du meme fichier de migration).
  table.sort(out, function(a, b)
    if a == 'sl-core' then return b ~= 'sl-core' end
    if b == 'sl-core' then return false end
    return a < b
  end)
  return out
end

-- Retire les commentaires SQL ligne `-- ...` avant le split, sinon un `;`
-- présent dans un commentaire casse le découpage.
local function stripLineComments(content)
  local out = {}
  for line in (content .. '\n'):gmatch('([^\n]*)\n') do
    local stripped = line:gsub('%-%-.*$', '')
    out[#out+1] = stripped
  end
  return table.concat(out, '\n')
end

local function applySql(content)
  local cleaned = stripLineComments(content)
  for stmt in cleaned:gmatch('([^;]+)') do
    local trimmed = stmt:gsub('^%s+', ''):gsub('%s+$', '')
    if #trimmed > 0 then
      MySQL.query.await(trimmed, {})
    end
  end
end

-- Verrou de serialisation. ApplyAll est appele au boot de sl-core ET par le
-- hook onResourceStart de chaque sl-* qui demarre. Au boot, les ~25 modules
-- demarrent en cascade -> sans verrou, plusieurs ApplyAll tournent en parallele,
-- voient la meme migration comme "non appliquee", l'appliquent toutes, puis
-- l'INSERT de tracking echoue en duplicate (FATAL). Pire : une migration avec
-- un SEED (INSERT de donnees) tournerait plusieurs fois -> doublons.
local migrating = false

local function doApplyAll()
  MySQL.query.await(BOOTSTRAP_TABLE, {})

  local applied = MySQL.query.await('SELECT filename, hash, resource FROM sl_migrations', {}) or {}
  local appliedMap = {}
  for _, row in ipairs(applied) do
    appliedMap[row.resource .. '/' .. row.filename] = row.hash
  end

  local appliedCount = 0
  local skippedCount = 0

  for _, resource in ipairs(listSlResources()) do
    local files = listMigrationsFor(resource)
    table.sort(files)
    for _, filename in ipairs(files) do
      local content = LoadResourceFile(resource, 'sql/' .. filename)
      if not content then
        print(('^1[sl-core] migrations: %s/sql/%s missing^0'):format(resource, filename))
      else
        local hash = SL.Utils.hash(content)
        local key = resource .. '/' .. filename
        local existing = appliedMap[key]
        if existing then
          if existing ~= hash then
            print(('^1[sl-core] migrations: FATAL — %s/%s already applied but hash diverged (db=%s, file=%s).^0'):format(resource, filename, existing, hash))
            print('^1[sl-core] migrations: refuse to boot. Restore the file or create a new migration.^0')
            error('migration hash divergence on ' .. key)
          end
          skippedCount = skippedCount + 1
        else
          local ok, err = pcall(applySql, content)
          if not ok then
            print(('^1[sl-core] migrations: %s/%s failed: %s^0'):format(resource, filename, tostring(err)))
            error(err)
          end
          -- INSERT IGNORE : idempotent. Si une autre passe a deja insere cette
          -- migration entre temps (race residuelle), on ne crashe pas.
          MySQL.insert.await(
            'INSERT IGNORE INTO sl_migrations (filename, resource, hash) VALUES (?, ?, ?)',
            { filename, resource, hash }
          )
          -- Memorise localement pour eviter de re-appliquer dans la meme passe.
          appliedMap[key] = hash
          appliedCount = appliedCount + 1
          print(('^2[sl-core] migrations: applied %s/%s^0'):format(resource, filename))
        end
      end
    end
  end

  print(('^2[sl-core] migrations: %d applied, %d already present^0'):format(appliedCount, skippedCount))
  return appliedCount, skippedCount
end

function SL.Migrations.ApplyAll()
  -- Serialise : attend qu'une passe en cours finisse avant de demarrer (max 30s).
  local waited = 0
  while migrating and waited < 30000 do Wait(100); waited = waited + 100 end
  migrating = true
  local ok, a, b = pcall(doApplyAll)
  migrating = false
  if not ok then error(a) end
  return a, b
end

function SL.Migrations.Status()
  local applied = MySQL.query.await('SELECT filename, resource, applied_at FROM sl_migrations ORDER BY applied_at', {}) or {}
  local pending = {}
  local appliedSet = {}
  for _, row in ipairs(applied) do
    appliedSet[row.resource .. '/' .. row.filename] = true
  end
  for _, resource in ipairs(listSlResources()) do
    local files = listMigrationsFor(resource)
    for _, filename in ipairs(files) do
      local key = resource .. '/' .. filename
      if not appliedSet[key] then
        table.insert(pending, { resource = resource, filename = filename })
      end
    end
  end
  return applied, pending
end

AddEventHandler('onResourceStart', function(resource)
  if resource == GetCurrentResourceName() then return end
  if resource:sub(1, 3) ~= 'sl-' then return end
  Wait(500)
  pcall(SL.Migrations.ApplyAll)
end)
