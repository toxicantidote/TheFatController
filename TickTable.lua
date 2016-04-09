--- TickTable
-- @module TickTable
TickTable = {}

function TickTable.insert(tick, key, value)
  global[key][tick] = global[key][tick] or {}
  table.insert(global[key][tick], value)
end

function TickTable.remove(key, value)
  for t, values in pairs(global[key]) do
    for i=#values,1,-1 do
      if values[i] == value or (value.train and not value.train.valid) then
        values[i] = nil
      end
    end
  end
end

function TickTable.remove_by_train(key, train)
  for t, values in pairs(global[key]) do
    for i=#values,1,-1 do
      if values[i].train and values[i].train == train then
        values[i] = nil
      end
    end
  end
end

function TickTable.insert_unique(tick, key, value)
  for t, values in pairs(global[key]) do
    for _, v in pairs(values) do
      if v == value then
        return false
      end
    end
  end
  TickTable.insert(tick,key,value)
  return true
end