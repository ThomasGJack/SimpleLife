SL = SL or {}
SL.State = {
  loaded = false,
  spawned = false,
  citizenId = nil,
  characterId = nil,
  data = {},
  position = nil,
}

function SL.State.IsReady() return SL.State.loaded end
function SL.State.IsSpawned() return SL.State.spawned end
function SL.State.GetCitizenId() return SL.State.citizenId end
function SL.State.GetData() return SL.State.data end

SL.Bus.On('sl:core:characterSelected', function(payload)
  SL.State.loaded = true
  SL.State.citizenId = payload.citizenId
  SL.State.characterId = payload.characterId
  SL.State.data = payload.data or {}
  SL.State.position = payload.position
end)

exports('GetState', function() return SL.State end)
exports('Bus', function()
  return {
    On = SL.Bus.On,
    Emit = SL.Bus.Emit,
    EmitServer = SL.Bus.EmitServer,
  }
end)
