local SL = exports['sl-core']

local started = false

local function payAll()
  local paid = 0
  local total = 0
  for source, entry in pairs(Cache) do
    if entry and entry.onDuty then
      local grade = Jobs.GetGrade(entry.name, entry.grade)
      local amount = grade and grade.payCheck or 0
      if amount > 0 then
        local ok = exports['sl-economy']:AddMoney(source, Jobs.PaycheckAccount or 'bank', amount, 'paycheck:' .. entry.name)
        if ok then
          paid = paid + 1
          total = total + amount
          local jobLabel = Jobs.GetJob(entry.name) and Jobs.GetJob(entry.name).label or entry.name
          TriggerClientEvent('sl:bus:dispatch', source, 'sl:jobs:paycheck', {
            amount = amount,
            account = Jobs.PaycheckAccount or 'bank',
            jobLabel = jobLabel,
            gradeLabel = grade.label,
          })
        end
      end
    end
  end
  if paid > 0 then
    print(('[sl-jobs] paycheck: %d players paid, total %d $'):format(paid, total))
    TriggerEvent('sl:jobs:paycheck', { count = paid, total = total })
  end
end

CreateThread(function()
  while not started do Wait(500); started = true end
  while true do
    Wait((Jobs.PaycheckIntervalMin or 30) * 60 * 1000)
    pcall(payAll)
  end
end)

exports('TriggerPaycheck', payAll)
