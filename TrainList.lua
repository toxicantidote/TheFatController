TrainList = {}
TrainList.add_train = function(train)
  local ti = TrainList.createTrainInfo(train)
  table.insert(global.trainsByForce[ti.force.name], ti)
  local removed = TrainList.remove_invalid(ti.force,true)
  return ti
end

TrainList.remove_invalid = function(force, show)
  local removed = 0
  local show = show or debug
  TrainList.removeAlarms()
  local revalidated = false
  local decoupled = false
  for i=#global.trainsByForce[force.name],1,-1 do
    local ti = global.trainsByForce[force.name][i]
    if ti then
      if not ti.train or not ti.train.valid then
        local first_train = (ti.first_carriage and ti.first_carriage.valid and ti.first_carriage.train.valid) and ti.first_carriage.train or false 
        local last_train = (ti.last_carriage and ti.last_carriage.valid and ti.last_carriage.train.valid) and ti.last_carriage.train or false
        if first_train then
          local tmp = TrainList.createTrainInfo(first_train)
          tmp.mainIndex = i
          global.trainsByForce[force.name][i] = tmp
          revalidated = true
          debugDump("first"..i,true)
        end
        if last_train then
          local tmp = TrainList.createTrainInfo(last_train)
          if first_train then
            debugDump("train split",true)
            decoupled = tmp 
          else
            tmp.mainIndex = i
            global.trainsByForce[force.name][i] = tmp
            revalidated = true
            debugDump("last"..i,true)
          end
        end
      end
    else
      debugDump("oops",true)
      table.remove(global.trainsByForce[force.name], i)
    end
  end
  if decoupled then
    table.insert(global.trainsByForce[force.name], decoupled)
  end
  TrainList.remove_duplicates(force)
  for i,ti in pairs(global.trainsByForce[force.name]) do
    ti.mainIndex = i
    ti.opened_guis = {}
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

TrainList.remove_duplicates = function(force)
  for i=#global.trainsByForce[force.name],1,-1 do
    local trainA = global.trainsByForce[force.name][i].train
    for j=i-1,1,-1 do
      if trainA and trainA == global.trainsByForce[force.name][j].train then
        --debugDump("Duplicate: "..i.."=="..j,true)
        table.remove(global.trainsByForce[force.name], i)
      end
    end
  end
end

TrainList.createTrainInfo = function(train)
  local ti = table.deepcopy(TrainInfo)
  ti.train = train
  ti.first_carriage = train.carriages[1]
  ti.last_carriage = train.carriages[#train.carriages]
  ti.force = ti.first_carriage.force
  if ti.first_carriage == ti.last_carriage then
    ti.last_carriage = false
  end
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

TrainList.remove_train = function(train)
  local force = train.carriages[1].force
  local trains = global.trainsByForce[force.name]
  local removed = false
  for i=#trains, 1,-1 do
    if trains[i].train == train then
      table.remove(trains, i)
      break
    end
  end
  TrainList.removeAlarms(train)
  for i,ti in pairs(global.trainsByForce[force.name]) do
    ti.mainIndex = i
    ti.opened_guis = {}
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

TrainList.removeAlarms = function(train)
  local remove = {}
  for tick, trains in pairs(global.updateAlarms) do
    for i=#trains,1,-1 do
      local ti = trains[i]
      if ti then
        if not ti.train or not ti.train.valid then
          trains[i] = nil
        elseif ti.train == train then
          trains[i] = nil
        end
      else
        trains[i] = nil
      end
    end
    if #trains == 0 then
      debugDump("no alarms"..tick,true)
      table.insert(remove, tick)
    end
  end
  for _,tick in pairs(remove) do
    global.updateAlarms[tick] = nil
  end
end

TrainList.reset_manual = function(train)
  if not train then
    global.updateManual = {}
    for i, p in pairs(game.players) do
      if p.vehicle and (p.vehicle.type == "locomotive" or p.vehicle.type == "cargo-wagon") then
        local ti = TrainList.get_traininfo(p.force, p.vehicle.train)
        if ti and ti.train and ti.train.valid then
          local state = ti.train.state
          if state == defines.trainstate.manual_control 
            or state == defines.trainstate.manual_control_stop
            or state == defines.trainstate.no_path then
              insert_in_tick_table("updateManual",game.tick+update_rate_manual+p.index,ti)
          end
          global.gui[p.index].vehicle = ti.train
        end
      end
    end
  elseif train.valid then
    for tick, trains in pairs(global.updateManual) do
      for i=#trains,1,-1 do
        local ti = trains[i]
        if ti and ti.train.valid and ti.train == train then
          trains[i] = nil
        elseif not ti or not ti.train.valid then
          trains[i] = nil
        end
      end
    end
  end
end
