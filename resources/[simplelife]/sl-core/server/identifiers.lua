SL = SL or {}
SL.Identifiers = {}

function SL.Identifiers.Extract(source)
  local out = { license = nil, steam = nil, discord = nil, fivem = nil }
  local ids = GetPlayerIdentifiers(source) or {}
  for _, id in ipairs(ids) do
    local prefix, value = id:match('^([^:]+):(.+)$')
    if prefix == 'license' and not out.license then
      out.license = value
    elseif prefix == 'license2' and not out.license then
      out.license = value
    elseif prefix == 'steam' then
      out.steam = value
    elseif prefix == 'discord' then
      out.discord = value
    elseif prefix == 'fivem' then
      out.fivem = value
    end
  end
  return out
end

function SL.Identifiers.Primary(source)
  local i = SL.Identifiers.Extract(source)
  return i.license
end
