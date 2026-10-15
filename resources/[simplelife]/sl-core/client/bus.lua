SL = SL or {}
SL.Bus = { handlers = {} }

function SL.Bus.On(event, handler, owner)
  owner = owner or GetInvokingResource() or GetCurrentResourceName()
  if not SL.Bus.handlers[event] then SL.Bus.handlers[event] = {} end
  table.insert(SL.Bus.handlers[event], { fn = handler, owner = owner })
end

function SL.Bus.Emit(event, payload)
  TriggerEvent(event, payload)
  local list = SL.Bus.handlers[event]
  if not list then return end
  for _, h in ipairs(list) do
    local ok, err = pcall(h.fn, payload)
    if not ok then print(('[sl-core] client bus error on %s: %s'):format(event, tostring(err))) end
  end
end

function SL.Bus.Off(event, handler)
  local list = SL.Bus.handlers[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i].fn == handler then table.remove(list, i) end
  end
end

function SL.Bus.OffByOwner(owner)
  for _, list in pairs(SL.Bus.handlers) do
    for i = #list, 1, -1 do
      if list[i].owner == owner then table.remove(list, i) end
    end
  end
end

RegisterNetEvent('sl:bus:dispatch', function(event, payload)
  SL.Bus.Emit(event, payload)
end)

function SL.Bus.EmitServer(event, payload)
  TriggerServerEvent('sl:bus:dispatch', event, payload)
end
