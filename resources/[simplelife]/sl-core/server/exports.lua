exports('GetPlayer', function(source) return SL.Players.Get(source) end)
exports('GetPlayerByCitizenId', function(cid) return SL.Players.GetByCitizenId(cid) end)
exports('GetPlayerByIdentifier', function(license) return SL.Players.GetByIdentifier(license) end)
exports('GetPlayers', function() return SL.Players.All() end)

exports('RegisterModule', function(spec) return SL.Modules.Register(spec) end)
exports('ListModules', function() return SL.Modules.List() end)
exports('GetModule', function(name) return SL.Modules.Get(name) end)

exports('EmitBus', function(event, payload) SL.Bus.Emit(event, payload) end)
exports('EmitClientBus', function(source, event, payload) SL.Bus.EmitClient(source, event, payload) end)
exports('BroadcastBus', function(event, payload) SL.Bus.Broadcast(event, payload) end)

exports('Bus', function()
  return {
    Emit = function(event, payload) TriggerEvent(event, payload) end,
    EmitClient = function(src, event, payload) TriggerClientEvent('sl:bus:dispatch', src, event, payload) end,
    Broadcast = function(event, payload) TriggerClientEvent('sl:bus:dispatch', -1, event, payload) end,
  }
end)

exports('DB', function()
  return {
    query = SL.DB.query,
    single = SL.DB.single,
    scalar = SL.DB.scalar,
    insert = SL.DB.insert,
    update = SL.DB.update,
    transaction = SL.DB.transaction,
    ping = SL.DB.ping,
  }
end)

exports('Identifiers', function(source) return SL.Identifiers.Extract(source) end)

exports('HydrateCharacter', function(source, characterRow)
  return SL.Players.HydrateCharacter(source, characterRow)
end)

exports('SaveAll', function(reason) return SL.Players.SaveAll(reason or 'manual') end)
exports('CoreVersion', function() return SL_CORE_VERSION end)
exports('CoreApi', function() return SL_CORE_API end)
exports('IsReady', function() return SL._ready == true end)

exports('GenCitizenId', function() return SL.Utils.genCitizenId() end)
exports('Hash', function(s) return SL.Utils.hash(s) end)
exports('IsCitizenIdAvailable', function(cid)
  local n = SL.DB.scalar('SELECT COUNT(*) FROM sl_characters WHERE citizen_id = ?', { cid })
  return (n or 0) == 0
end)
