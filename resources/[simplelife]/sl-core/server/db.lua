SL = SL or {}
SL.DB = {}

local SLOW_QUERY_MS = 50

local function wrap(name, fn)
  return function(sql, params)
    params = params or {}
    if Config.Env == 'dev' then
      local t0 = os.clock()
      local ok, result = pcall(fn, sql, params)
      local elapsed = (os.clock() - t0) * 1000
      if not ok then
        print(('^1[sl-core] db.%s error: %s | sql=%s^0'):format(name, tostring(result), sql))
        error(result, 2)
      end
      if elapsed > SLOW_QUERY_MS then
        print(('^3[sl-core] slow %s (%.1fms): %s^0'):format(name, elapsed, sql:sub(1, 120)))
      end
      return result
    end
    return fn(sql, params)
  end
end

SL.DB.query = wrap('query', function(sql, params) return MySQL.query.await(sql, params) end)
SL.DB.single = wrap('single', function(sql, params) return MySQL.single.await(sql, params) end)
SL.DB.scalar = wrap('scalar', function(sql, params) return MySQL.scalar.await(sql, params) end)
SL.DB.insert = wrap('insert', function(sql, params) return MySQL.insert.await(sql, params) end)
SL.DB.update = wrap('update', function(sql, params) return MySQL.update.await(sql, params) end)

function SL.DB.transaction(queries)
  return MySQL.transaction.await(queries)
end

function SL.DB.ping()
  local ok, result = pcall(MySQL.scalar.await, 'SELECT 1')
  return ok and result == 1
end

function SL.DB.dbName()
  local row = SL.DB.single('SELECT DATABASE() AS db')
  return row and row.db or 'unknown'
end
