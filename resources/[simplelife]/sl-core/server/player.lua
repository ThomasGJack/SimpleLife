SL = SL or {}
SL.Players = {}

local Player = {}
Player.__index = Player

local function newPlayer(source, accountId, identifiers)
  return setmetatable({
    source = source,
    accountId = accountId,
    identifiers = identifiers,
    citizenId = nil,
    characterId = nil,
    data = {},
    position = nil,
    modified = false,
    spawned = false,
  }, Player)
end

function Player:GetIdentifier() return self.identifiers.license end
function Player:GetCitizenId() return self.citizenId end
function Player:IsSpawned() return self.spawned end

function Player:SetData(key, value)
  self.data[key] = value
  self.modified = true
end

function Player:SetPosition(pos)
  self.position = pos
  self.modified = true
end

function Player:Save(reason)
  if not self.characterId then return false end
  if not self.modified and reason ~= 'shutdown' then return false end
  local dataJson = json.encode(self.data or {})
  local posJson = self.position and json.encode(self.position) or nil
  SL.DB.update(
    'UPDATE sl_characters SET data = ?, position = ? WHERE id = ?',
    { dataJson, posJson, self.characterId }
  )
  self.modified = false
  return true
end

SL.Player = Player

function SL.Players.Load(source)
  local identifiers = SL.Identifiers.Extract(source)
  if not identifiers.license then
    print(('^1[sl-core] player %s has no license identifier, refusing^0'):format(source))
    return nil
  end

  local row = SL.DB.single('SELECT id FROM sl_accounts WHERE license = ?', { identifiers.license })
  local accountId
  if row then
    accountId = row.id
    SL.DB.update(
      'UPDATE sl_accounts SET steam = ?, discord = ?, fivem_id = ?, last_seen = CURRENT_TIMESTAMP WHERE id = ?',
      { identifiers.steam, identifiers.discord, identifiers.fivem, accountId }
    )
  else
    accountId = SL.DB.insert(
      'INSERT INTO sl_accounts (license, steam, discord, fivem_id, last_seen) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)',
      { identifiers.license, identifiers.steam, identifiers.discord, identifiers.fivem }
    )
  end

  local player = newPlayer(source, accountId, identifiers)
  SL.Players[source] = player

  SL.Bus.Emit('sl:core:playerLoaded', {
    source = source,
    accountId = accountId,
    identifiers = identifiers,
  })

  print(('^2[sl-core] player loaded: src=%d account=%d license=%s^0'):format(source, accountId, identifiers.license:sub(1, 16) .. '...'))
  return player
end

function SL.Players.HydrateCharacter(source, characterRow)
  local player = SL.Players[source]
  if not player then return false end
  player.citizenId = characterRow.citizen_id
  player.characterId = characterRow.id
  player.data = type(characterRow.data) == 'string' and (json.decode(characterRow.data) or {}) or (characterRow.data or {})
  player.position = type(characterRow.position) == 'string' and json.decode(characterRow.position) or characterRow.position
  player.modified = false

  local afk = nil
  local license = player.identifiers and player.identifiers.license
  if license and SL.Persistence and SL.Persistence.OnReconnect then
    afk = SL.Persistence.OnReconnect(license)
    if afk then
      player.position = afk.position
      print(('[sl-core] AFK reconnect for src=%d, position overridden'):format(source))
    end
  end

  local payload = {
    source = source,
    citizenId = player.citizenId,
    characterId = player.characterId,
    data = player.data,
    position = player.position,
    vehicleNetId = afk and afk.vehicleNetId or nil,
    seat = afk and afk.seat or nil,
  }
  SL.Bus.Emit('sl:core:characterSelected', payload)
  SL.Bus.EmitClient(source, 'sl:core:characterSelected', {
    citizenId = player.citizenId,
    characterId = player.characterId,
    data = player.data,
    position = player.position,
    vehicleNetId = payload.vehicleNetId,
    seat = payload.seat,
  })
  return true
end

function SL.Players.Get(source)
  return SL.Players[source]
end

function SL.Players.GetByCitizenId(citizenId)
  for _, p in pairs(SL.Players) do
    if type(p) == 'table' and p.citizenId == citizenId then return p end
  end
end

function SL.Players.GetByIdentifier(license)
  for _, p in pairs(SL.Players) do
    if type(p) == 'table' and p.identifiers and p.identifiers.license == license then return p end
  end
end

function SL.Players.All()
  local out = {}
  for src, p in pairs(SL.Players) do
    if type(src) == 'number' then table.insert(out, p) end
  end
  return out
end

function SL.Players.Drop(source, reason)
  local player = SL.Players[source]
  if not player then return end
  if player.characterId then
    pcall(function() player:Save(reason or 'dropped') end)
  end
  local license = player.identifiers and player.identifiers.license
  if license and SL.Persistence and SL.Persistence.OnDrop then
    pcall(function() SL.Persistence.OnDrop(source, license) end)
  end
  SL.DB.update('UPDATE sl_accounts SET last_seen = CURRENT_TIMESTAMP WHERE id = ?', { player.accountId })
  SL.Bus.Emit('sl:core:playerDropped', { source = source, reason = reason })
  SL.Players[source] = nil
  print(('^3[sl-core] player dropped: src=%d (%s)^0'):format(source, reason or 'unknown'))
end

function SL.Players.SaveAll(reason)
  local n = 0
  for _, p in pairs(SL.Players) do
    if type(p) == 'table' and p.characterId then
      local ok = pcall(function() p:Save(reason) end)
      if ok then n = n + 1 end
    end
  end
  SL.Bus.Emit('sl:core:save', { reason = reason })
  return n
end
