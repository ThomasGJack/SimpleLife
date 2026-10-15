SL = SL or {}
SL.Persistence = { sessions = {}, snapshots = {} }

local AFK_TIMEOUT_SEC = (Config.AfkBodyTimeoutMin or 30) * 60
local VEHICLE_TRACK_INTERVAL_MS = 10000

local function now() return os.time() end

local function vehicleExists(netId)
  if not netId or netId == 0 then return false, nil, nil end
  local entity = NetworkGetEntityFromNetworkId(netId)
  if not entity or entity == 0 or not DoesEntityExist(entity) then return false, nil, nil end
  local coords = GetEntityCoords(entity)
  local heading = GetEntityHeading(entity)
  return true, coords, heading
end

RegisterNetEvent('sl:core:syncSnapshot', function(snap)
  local src = source
  local player = SL.Players[src]
  if not player or not player.identifiers or not player.identifiers.license then return end
  if type(snap) ~= 'table' or not snap.x or not snap.y or not snap.z then return end
  SL.Persistence.snapshots[player.identifiers.license] = {
    x = tonumber(snap.x) + 0.0,
    y = tonumber(snap.y) + 0.0,
    z = tonumber(snap.z) + 0.0,
    heading = tonumber(snap.heading) or 0.0,
    vehicleNetId = tonumber(snap.vehicleNetId) or 0,
    seat = tonumber(snap.seat) or -2,
    updatedAt = now(),
  }
end)

function SL.Persistence.OnDrop(source, license)
  if not license then return end
  local snap = SL.Persistence.snapshots[license]
  if not snap then return end
  SL.Persistence.sessions[license] = {
    license = license,
    position = { x = snap.x, y = snap.y, z = snap.z, heading = snap.heading },
    vehicleNetId = snap.vehicleNetId,
    seat = snap.seat,
    droppedAt = now(),
  }
  print(('[sl-core/persistence] AFK session created for %s (vehicle netId=%d seat=%d)'):format(license:sub(1, 12), snap.vehicleNetId, snap.seat))
end

function SL.Persistence.OnReconnect(license)
  if not license then return nil end
  local session = SL.Persistence.sessions[license]
  if not session then return nil end
  if (now() - session.droppedAt) > AFK_TIMEOUT_SEC then
    SL.Persistence.sessions[license] = nil
    SL.Persistence.snapshots[license] = nil
    print(('[sl-core/persistence] AFK session expired for %s'):format(license:sub(1, 12)))
    return nil
  end

  local result = {
    position = session.position,
    vehicleNetId = nil,
    seat = nil,
  }

  if session.vehicleNetId and session.vehicleNetId > 0 then
    local exists, coords, heading = vehicleExists(session.vehicleNetId)
    if exists then
      result.position = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
      result.vehicleNetId = session.vehicleNetId
      result.seat = session.seat
      print(('[sl-core/persistence] AFK reconnect: vehicle still alive at %.1f,%.1f,%.1f'):format(coords.x, coords.y, coords.z))
    else
      print(('[sl-core/persistence] AFK reconnect: vehicle gone, using last snapshot position'))
    end
  end

  SL.Persistence.sessions[license] = nil
  SL.Persistence.snapshots[license] = nil
  return result
end

CreateThread(function()
  while true do
    Wait(VEHICLE_TRACK_INTERVAL_MS)
    for license, session in pairs(SL.Persistence.sessions) do
      if (now() - session.droppedAt) > AFK_TIMEOUT_SEC then
        SL.Persistence.sessions[license] = nil
        SL.Persistence.snapshots[license] = nil
        print(('[sl-core/persistence] AFK session expired and purged for %s'):format(license:sub(1, 12)))
      elseif session.vehicleNetId and session.vehicleNetId > 0 then
        local exists, coords, heading = vehicleExists(session.vehicleNetId)
        if exists then
          session.position = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
        end
      end
    end
  end
end)
