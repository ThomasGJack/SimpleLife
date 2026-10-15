SL = SL or {}
SL.Utils = {}

local function deepCopy(t, seen)
  if type(t) ~= 'table' then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local copy = {}
  seen[t] = copy
  for k, v in pairs(t) do copy[deepCopy(k, seen)] = deepCopy(v, seen) end
  return copy
end
SL.Utils.deepCopy = deepCopy

local LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
function SL.Utils.genCitizenId()
  local i1 = math.random(1, 26)
  local i2 = math.random(1, 26)
  local a = LETTERS:sub(i1, i1)
  local b = LETTERS:sub(i2, i2)
  local digits = ''
  for _ = 1, 8 do digits = digits .. tostring(math.random(0, 9)) end
  return a .. b .. digits
end

local function parseSemver(v)
  local a, b, c = v:match('^(%d+)%.(%d+)%.(%d+)')
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

function SL.Utils.semverSatisfies(version, range)
  if not range or range == '' or range == '*' then return true end
  local op, rv = range:match('^([%^~>=<]+)(.+)$')
  if not op then op, rv = '=', range end
  local va, vb, vc = parseSemver(version)
  local ra, rb, rc = parseSemver(rv)
  if op == '^' then
    return va == ra and (vb > rb or (vb == rb and vc >= rc))
  elseif op == '~' then
    return va == ra and vb == rb and vc >= rc
  elseif op == '=' or op == '==' then
    return va == ra and vb == rb and vc == rc
  elseif op == '>=' then
    if va ~= ra then return va > ra end
    if vb ~= rb then return vb > rb end
    return vc >= rc
  end
  return false
end

function SL.Utils.hash(str)
  local h = 5381
  for i = 1, #str do
    h = (h * 33 + str:byte(i)) % 4294967296
  end
  return string.format('%08x', h)
end

function SL.Utils.jsonEncode(t) return json.encode(t) end
function SL.Utils.jsonDecode(s)
  if not s or s == '' then return nil end
  local ok, r = pcall(json.decode, s)
  return ok and r or nil
end
