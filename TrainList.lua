TrainList = {}
TrainList.add_train = function(train)
  local force = train.carriages[1].force
  local ti = TrainList.createTrainInfo(train)
  table.insert(global.trainsByForce[force.name], ti)
  local removed = TrainList.remove_invalid(force,true)
  return ti
end

TrainList.remove_invalid = function(force, show)
  local removed = 0
  local show = show or debug
  for i=#global.trainsByForce[force.name],1,-1 do
    local ti = global.trainsByForce[force.name][i]
    if not ti.train or not ti.train.valid then
      table.remove(global.trainsByForce[force.name], i)
      removed = removed + 1
      -- try to detect change through pressing G/V
    else
      local test = ti.type
      if test ~= ti.type then
        debugDump("De-/coupled train?", true)
        table.remove(global.trainsByForce[force.name], i)
        removed = removed + 1
      end
    end
  end
  for i,ti in pairs(global.trainsByForce[force.name]) do
    ti.mainIndex = i
  end
  if removed > 0 then
    if show then --removed > 0 and show then
      debugDump(game.tick.." Removed "..removed.." invalid trains",true)
      --flyingText("Removed "..removed.." invalid trains", RED, false, true)
    end
  end
  GUI.refreshAllTrainInfoGuis(force)
  return removed
end

TrainList.createTrainInfo = function(train)
  local ti = table.deepcopy(TrainInfo)
  ti.train = train
  ti.locomotives = TrainList.getLocomotives(train)
  ti.type = TrainList.getType(train)
  ti.first_carriage = train.carriages[1]
  ti.last_carriage = train.carriages[#train.carriages]
  ti.last_state = ti.train.state
  ti.last_update = 0
  ti.inventory = getHighestInventoryCount(ti)
  TrainList.update_stations(ti)
  local station = (#train.schedule.records > 0) and train.schedule.records[train.schedule.current].station or false
  ti.current_station = station
  if ti.train.state == defines.trainstate.wait_station and train.schedule and #train.schedule.records > 1 then
    ti.depart_at = game.tick
  end
  return ti
end

TrainList.getLocomotives = function(train)
  local locos = {}
  for i, fm in pairs(train.locomotives.front_movers) do
    table.insert(locos, fm)
  end
  for i, fm in pairs(train.locomotives.back_movers) do
    table.insert(locos, fm)
  end
  return locos
end

TrainList.getType = function(train)
  local type = string.rep("L",#train.locomotives.front_movers).."-"..string.rep("C", #train.cargo_wagons).."-"..string.rep("L",#train.locomotives.back_movers)
  type = string.gsub(type, "L%-%-L", "LL")
  return string.gsub(string.gsub(type, "^-", ""), "-$", "")
end

TrainList.remove_train = function(train)
  local force = train.carriages[1].force
  local trains = global.trainsByForce[force.name]
  local removed = false
  for i=#trains, 1,-1 do
    if trains[i].train == train then
      trains[i] = nil
      removed = true
    end
  end
  GUI.refreshAllTrainInfoGuis(force)
end

TrainList.get_traininfo = function(force, train)
  local trains = global.trainsByForce[force.name]
  if trains then
    for i, ti in pairs(trains) do
      if ti.train and ti.train.valid and ti.train == train then
        ti.mainIndex = i
        return ti
      end
    end
  else
    return false
  end
end

TrainList.update_stations = function(ti)
  local records = (ti.train.schedule and #ti.train.schedule.records > 0) and ti.train.schedule.records or false
  ti.stations = {}
  if not records then return end
  for i, record in pairs(records) do
    ti.stations[record.station] = true
  end
end

TrainList.get_filtered_trains = function(force, filterList)
  local trains = global.trainsByForce[force.name]
  local filtered = {}
  if trains and filterList then
    for i, ti in pairs(trains) do
      if matchStationFilter(ti, filterList) then
        ti.mainIndex = i
        table.insert(filtered, ti)
      end
    end
  end
  return filtered
end