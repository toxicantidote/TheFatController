--- TrainList module
-- @module TrainList

--- Train info
-- @type TrainInfo
TrainInfo = {
  current_station = false, --name of current station
  depart_at = 0, --tick when train will depart the station
  --main_index = 0, -- always equal to global.trainsByForce[force.name] index
  train = false, -- ref to lua_train
  mainIndex = false, --
  last_update = 0, --tick of last inventory update
  previous_state = 0,
  previous_state_tick = 0,
  last_state = 0, -- last trainstate
  last_state_tick = 0,
  unfiltered_state = {
    previous_state = 0,
    previous_tick = 0,
    last_state = 0,
    last_tick = 0
  },
  first_carriage = false,
  last_carriage = false,
  force = false,
  follower_index = 0, -- player_index of following player
  opened_guis = {}, -- contains references to opened player guis, indexed by player_index
  stations = {}, --boolean table, indexed by stations in the schedule, new global trains_by_station?? should speedup filtered display
  automated = false,
  alarm = {
    active = false,
    type = false,
    message = "",
    last_message = 0, --tick
    arrived_at_signal = false, -- tick
    left_station = false, --tick
  }
}

--- foo
-- @type TrainList
TrainList = {}

--- add a train to the list
-- @return #TrainInfo description
TrainList.add_train = function(train)
  local force = train.carriages[1].force
  local ti = TrainList.createTrainInfo(train)
  if ti then
    table.insert(global.trainsByForce[force.name], ti)
  end
  local removed = TrainList.remove_invalid(force,true)
  return ti
end

TrainList.remove_invalid = function(force, show)
  local removed = 0
  local show = show or debug
  TrainList.removeAlarms()
  local decoupled = false
  for i=#global.trainsByForce[force.name],1,-1 do
    local ti = global.trainsByForce[force.name][i]
    if ti then
      if not ti.train or not ti.train.valid then
        local first_train = (ti.first_carriage and ti.first_carriage.valid and ti.first_carriage.train.valid) and ti.first_carriage.train or false
        local last_train = (ti.last_carriage and ti.last_carriage.valid and ti.last_carriage.train.valid) and ti.last_carriage.train or false
        if first_train then
          local tmp = TrainList.createTrainInfo(first_train)
          if tmp then
            tmp.mainIndex = i
            global.trainsByForce[force.name][i] = tmp
          else
            table.remove(global.trainsByForce[force.name], i)
          end
        end
        if last_train then
          local tmp = TrainList.createTrainInfo(last_train)
          if tmp then
            if first_train then
              decoupled = tmp
            else
              tmp.mainIndex = i
              global.trainsByForce[force.name][i] = tmp
            end
          else
            table.remove(global.trainsByForce[force.name], i)
          end
        end
      end
      if ti.train and ti.train.valid and #ti.train.locomotives.front_movers == 0 and #ti.train.locomotives.back_movers == 0 then
        table.remove(global.trainsByForce[force.name], i)
        removed = removed + 1
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
    if ti.train.state == defines.trainstate.manual_control and ti.train.speed == 0 then
      TrainList.add_manual(ti)
    end
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


--- empty traininfo
-- @return #TrainInfo description
TrainList.createTrainInfo = function(train)
  log(#train.locomotives.front_movers)
  log(#train.locomotives.back_movers)
  if #train.locomotives.front_movers == 0 and #train.locomotives.back_movers == 0 then
    return false
  end
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
  ti.automated = train.state ~= defines.trainstate.manual_control and train.state ~= defines.trainstate.stop_for_auto_control
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

--- Get traininfo by LuaTrain
-- @return #TrainInfo
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

TrainList.matchStationFilter = function(trainInfo, activeFilterList, alarm, modeOR)
  if trainInfo ~= nil then
    if alarm then
      return trainInfo.alarm.active
    end
    if not activeFilterList then
      return true
    end
    for filter, value in pairs(activeFilterList) do
      if modeOR and trainInfo.stations[filter] then
        return true
      end
      if not modeOR and not trainInfo.stations[filter] then
        return false
      end
    end
    if not modeOR then
      return true
    else
      return false
    end
  end
  return false
end

TrainList.get_filtered_trains = function(force, guiSettings)
  local trains = global.trainsByForce[force.name]
  local alarm_only = guiSettings.filter_alarms
  local filterList = guiSettings.activeFilterList
  local mode = guiSettings.filterModeOr
  local filtered = {}
  if trains then
    guiSettings.automatedCount = 0
    guiSettings.filteredIndex = {}
    for i, ti in pairs(trains) do
      if TrainList.matchStationFilter(ti, filterList, alarm_only, mode) then
        ti.mainIndex = i
        table.insert(filtered, ti)
        guiSettings.filteredIndex[i] = true
        if ti.automated then
          guiSettings.automatedCount = guiSettings.automatedCount + 1 
        end
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
      --debugDump("no alarms"..tick,true)
      table.insert(remove, tick)
    end
  end
  for _,tick in pairs(remove) do
    global.updateAlarms[tick] = nil
  end
end

TrainList.add_manual = function(ti, player)
  if ti and ti.train and ti.train.valid then
    local state = ti.train.state
    if state == defines.trainstate.manual_control
      or state == defines.trainstate.no_path then
      if player or ti.train.speed == 0 then
        ti.passenger = player
        --debugDump("added to manual",true)
        if TickTable.insert_unique(game.tick + update_rate_manual, "updateManual", ti) then
        --debugDump("inserted",true)
        else
        --debugDump("didn't insert, duplicate",true)
        end
      end
    end
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
            TickTable.insert(game.tick + update_rate_manual+p.index, "updateManual", ti)
          end
          global.gui[p.index].vehicle = ti.train
        end
      end
    end
  elseif train.valid then
    for tick, trains in pairs(global.updateManual) do
      for i=#trains,1,-1 do
        local ti = trains[i]
        if ti and ti.train.valid and ti.train == train and train.speed ~= 0 then
          trains[i] = nil
        elseif not ti or not ti.train.valid then
          trains[i] = nil
        end
      end
    end
  end
end

TrainList.count = function(force)
  if force then
    return #global.trainsByForce[force.name]
  else
    local c = 0
    for force, trains in pairs(global.trainsByForce) do
      c = c + #trains
    end
    return c
  end
end
