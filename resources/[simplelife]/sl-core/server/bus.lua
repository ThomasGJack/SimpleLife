SL = SL or {}
SL.Bus = {}

function SL.Bus.On(event, handler)
  assert(type(event) == 'string', 'event must be string')
  assert(type(handler) == 'function', 'handler must be function')
  AddEventHandler(event, handler)
end

function SL.Bus.Emit(event, payload)
  TriggerEvent(event, payload)
end

function SL.Bus.EmitClient(source, event, payload)
  TriggerClientEvent('sl:bus:dispatch', source, event, payload)
end

function SL.Bus.Broadcast(event, payload)
  TriggerClientEvent('sl:bus:dispatch', -1, event, payload)
end
