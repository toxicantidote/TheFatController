require "defines"
require "util"
require "GUI"

MOD_NAME = "TheFatController"
defaults = {stationDuration=10,signalDuration=2}

defaultGuiSettings = {
  alarm={active=false,noPath=true,timeAtSignal=true,timeToStation=true},
  displayCount=9,
  fatControllerButtons = {},
  fatControllerGui = {},
  page = 1,
  pageCount = 5,
  filter_page = 1,
  filter_pageCount = 1,
  stationFilterList = {},
  stopButton_state = false
}

character_blacklist = {
  ["orbital-uplink"] = true, --Satellite Uplink Station
  ["yarm-remote-viewer"] = true, --YARM
}

TRAINS = {}

global2 = {
  trainsByForce = {player={}}, --seperated by force, indexed by table.insert ?
  trainsByStation = {}


}
TrainInfo = {
  dirty = false, -- flag to indicate the guis need updating
  current_station = "Station", --name of current station
  main_index = 0, -- always equal to global.trainsByForce[force.name] index
  train = false, -- ref to lua_train
  last_state = 0, -- last trainstate
  last_update = 0, -- tick when inventory, infotext was last updated
  locomotices = {}, -- locomotives of train (to revalidate a train?)
  follower_index = 0, -- player_index of following player
  opened_guis = {}, -- contains references to opened player guis, indexed by player_index
  stations = {}, --boolean table, indexed by stations in the schedule, new global trains_by_station?? should speedup filtered display
  matches_filter = false, --whether the stations match the filter
  alarm = {
    last_message = 0, --tick
    arrived_at_signal = 0, -- tick
    arrived_at_station = 0, --tick

  }
}

function buildStationFilterList(trains)
  local newList = {}
  if trains ~= nil then
    for i, trainInfo in pairs(trains) do
      if trainInfo.stations ~= nil then
        for station, value in pairs(trainInfo.stations) do
          --debugLog(station)
          newList[station] = true
        end
      end
    end
  end
  return newList
end

local function init_global()
  global = global or {}
  global.guiSettings = global.guiSettings or {}
  global.trainsByForce = global.trainsByForce or {}
  global.character = global.character or {}
  global.unlocked = global.unlocked or false
  global.unlockedByForce = global.unlockedByForce or {}
  global.PAGE_SIZE = global.PAGE_SIZE or 60
  global.force_settings = global.force_settings or {}
  global.version = "0.3.1"
end

local function init_player(player)
  global.guiSettings[player.index] = global.guiSettings[player.index] or util.table.deepcopy(defaultGuiSettings)
  if global.unlockedByForce[player.force.name] then
    GUI.init_gui(player)
  end
end

local function init_players()
  for i,player in pairs(game.players) do
    init_player(player)
  end
end

local function init_force(force)
  init_global()
  global.trainsByForce[force.name] = global.trainsByForce[force.name] or {}
  global.force_settings[force.name] = global.force_settings[force.name] or {signalDuration=defaults.signalDuration*3600,stationDuration=defaults.stationDuration*3600}
  if force.technologies["rail-signals"].researched then
    global.unlockedByForce[force.name] = true
    global.unlocked = true
    register_events()
    for i,p in pairs(force.players) do
      init_player(p)
    end
  end
end

local function init_forces()
  for i, force in pairs(game.forces) do
    init_force(force)
  end
end

local function on_init()
  init_global()
  init_forces()
  init_players()
end

local function on_load()
  if global.unlocked then
    register_events()
  end
  --  for force, trains in pairs(global.trainsByForce) do
  --    for i, trainInfo in pairs(trains) do
  --      if trainInfo.train and trainInfo.train.valid then
  --        TRAINS[trainInfo.train] = trainInfo
  --        TRAINS[trainInfo.train].index = i
  --      end
  --    end
  --  end
end

function destroyGui(guiA)
  if guiA ~= nil and guiA.valid then
    guiA.destroy()
  end
end

-- run once
local function on_configuration_changed(data)
  if not data or not data.mod_changes then
    return
  end
  if data.mod_changes[MOD_NAME] then
    local newVersion = data.mod_changes[MOD_NAME].new_version
    local oldVersion = data.mod_changes[MOD_NAME].old_version
    if oldVersion then
      if oldVersion <= "0.3.14" then
        -- Kill all old versions of TFC
        if global.fatControllerGui ~= nil or global.fatControllerButtons ~= nil then
          destroyGui(global.fatControllerGui)
          destroyGui(global.fatControllerButtons)
        end
        for i,p in pairs(game.players) do
          destroyGui(p.gui.top.fatControllerButtons)
          destroyGui(p.gui.left.fatController)
        end
        if type(global.character) == "table" then
          for i, c in pairs(global.character) do
            if game.players[i].connected and c.valid then
              swapPlayer(game.players[i], c)
            end
          end
        end
        global = nil
      end
    end
    on_init()
    if oldVersion then
      if oldVersion < "0.3.19" then
        global.PAGE_SIZE = 60
        for i,g in pairs(global.guiSettings) do
          g.filter_page = 1
          g.filter_pageCount = 5
        end
      end
      if oldVersion < "0.3.21" then
        for i,g in pairs(global.guiSettings) do
          g.stopButton_state = false
        end
      end
      if oldVersion < "0.3.23" then
        init_forces()
      end
      if oldVersion < "0.4.0" then
        for i, guiSettings in pairs(global.guiSettings) do
          if guiSettings.alarm == nil then
            guiSettings.alarm = {}
          end
        end
      end
    end
    if not oldVersion or oldVersion < "0.3.14" or newVersion == "0.3.19" then
      findTrains()
    end
    global.version = newVersion
  end
  --check for other mods
end

local function on_player_created(event)
  init_player(game.players[event.player_index])
end

local function on_force_created(event)
  init_force(event.force)
end

local function on_forces_merging(event)

end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)
script.on_event(defines.events.on_forces_merging, on_forces_merging)

function is_waiting_forever(train)
  local smart_trains_installed = remote.interfaces.st and remote.interfaces.st.is_waiting_forever
  --debugDump({st=smart_trains_installed, rc = remote.call("st", "is_waiting_forever", train)},true)
  if smart_trains_installed then
    return remote.call("st", "is_waiting_forever", train)
  else
    return false
  end
end

function sanitizeNumber(number, default)
  return tonumber(number) or default
end

function on_research_finished(event)
  if event.research.name == "rail-signals" then
    global.unlockedByForce[event.research.force.name] = true
    global.unlocked = true
    register_events() ;
    for _, p in pairs(event.research.force.players) do
      GUI.init_gui(p)
    end
  end
end

script.on_event(defines.events.on_research_finished, function(event)
  local status, err = pcall(on_research_finished, event)
  if err then debugDump(err,true) end
end)

function alertPlayer(player,guiSettings,tick,message)
  if player ~= nil and guiSettings ~= nil and guiSettings.alarm ~= nil and guiSettings.alarm.active and (guiSettings.alarm.lastMessage == nil or guiSettings.alarm.lastMessage + 120 < tick) then
    guiSettings.lastMessage = tick
    player.print(message)
  end
end

onTickAfterUnlocked = function(event)
  local status, err = pcall(function()
    if not SAVED then
      saveVar(TRAINS, "onLoad", "TRAINS")
      saveVar(global, "onLoadG")
      SAVED = true
    end
    if global.to_swap then
      local tmp = {}
      for i, c in pairs(global.to_swap) do
        if game.players[c.index].connected then
          local guiSettings = global.guiSettings[c.index]
          swapPlayer(game.players[c.index], global.character[c.index])
          global.character[c.index] = nil
          if guiSettings.fatControllerButtons.returnToPlayer ~= nil then
            guiSettings.fatControllerButtons.returnToPlayer.destroy()
          end
          guiSettings.followEntity = nil
        else
          table.insert(tmp, {index=c.index, character=c.character})
        end
      end
      global.to_swap = #tmp > 0 and tmp or false
    end

    if global.dead_players then
      for i, character in pairs(global.dead_players) do
        if not character.valid then
          debugDump(game.players[i].name.." died while remote controlling",true)
          debugDump("Killing "..game.players[i].name.." softly",true)
          game.players[i].character.die()
          global.guiSettings[i].followEntity = nil
        else

        end
      end
      global.dead_players = nil
    end

    if event.tick%60==13 then
      local updateGui = false
      -- move to on_gui_click ???
      for i,guiSettings in pairs(global.guiSettings) do
        if game.players[i] and game.players[i].connected and guiSettings.fatControllerGui ~= nil and guiSettings.fatControllerGui.trainInfo ~= nil then
          updateGui = true
        end
      end
      if updateGui then
        debugLog("updateGUI")
        for _,trains in pairs(global.trainsByForce) do
          updateTrains(trains)
        end
        GUI.refreshAllTrainInfoGuis(global.trainsByForce, global.guiSettings, game.players, false)
        for i,player in pairs(game.players) do
          if player.connected then
            GUI.refreshTrainInfoGui(global.trainsByForce[player.force.name], global.guiSettings[i], player)
            global.guiSettings[i].pageCount = getPageCount(global.trainsByForce[player.force.name], global.guiSettings[i])
          end
        end
      end
    end

    --handle remote camera
    for i,guiSettings in pairs(global.guiSettings) do
      if guiSettings.followEntity ~= nil then -- Are we in remote camera mode?
        if not guiSettings.followEntity.valid  or game.players[i].vehicle == nil then
          swapPlayer(game.players[i], global.character[i])
          if guiSettings.fatControllerButtons ~= nil and guiSettings.fatControllerButtons.returnToPlayer ~= nil then
            guiSettings.fatControllerButtons.returnToPlayer.destroy()
          end
          if not guiSettings.followEntity.valid then
            removeTrainInfoFromEntity(global.trainsByForce[game.players[i].force.name], guiSettings.followEntity)
            GUI.newTrainInfoWindow(guiSettings)
            GUI.refreshTrainInfoGui(global.trainsByForce[game.players[i].force.name], guiSettings, game.players[i])
          end
          global.character[i] = nil
          guiSettings.followEntity = nil
      elseif global.character[i] and global.character[i].valid and guiSettings.fatControllerButtons ~= nil and guiSettings.fatControllerButtons.returnToPlayer == nil then
        guiSettings.fatControllerButtons.add({ type="button", name="returnToPlayer", caption={"text-player"}, style = "fatcontroller_selected_button"})
        --game.players[1].teleport(global.followEntity.position)
      elseif global.character[i] ~= nil and not global.character[i].valid  then
        game.set_game_state({gamefinished=true, playerwon=false})
      end
      end
    end

    if event.tick%120 == 37 then
      local alarmState = {}
      alarmState.timeToStation = false
      alarmState.timeAtSignal = false
      alarmState.noPath = false
      alarmState.noFuel = false
      local newAlarm = {}
      for forceName,trains in pairs(global.trainsByForce) do
        local stationDuration = global.force_settings[forceName].stationDuration
        local signalDuration = global.force_settings[forceName].signalDuration
        newAlarm[forceName] = false
        for i,trainInfo in pairs(trains) do
          local alarmSet = false
          if trainInfo.lastState == 1 or trainInfo.lastState == 3 then
            --game.players[1].print("No Path " .. i .. " " .. game.tick)
            if not trainInfo.alarm then
              alarmState.noPath = true
              newAlarm[forceName] = true
              trainInfo.updated = true
              trainInfo.alarmType = "noPath"
            end
            alarmSet = true
            trainInfo.alarm = true
          end
          -- 36000, 10 minutes

          if trainInfo.lastState ~= 7 and trainInfo.lastStateStation ~= nil and (trainInfo.lastStateStation + stationDuration < game.tick and (trainInfo.lastState ~= 2 or trainInfo.lastState ~= 8 or trainInfo.lastState ~= 9)) then
            if not trainInfo.alarm then
              alarmState.timeToStation = true
              newAlarm[forceName] = true
              trainInfo.updated = true
              trainInfo.alarmType = "timeToStation"
            end
            alarmSet = true
            trainInfo.alarm = true
          end
          -- 72002 minutes lol, wtf?
          if trainInfo.lastState == 5 and (trainInfo.lastStateSignal ~= nil and trainInfo.lastStateSignal + signalDuration < game.tick ) then
            if not trainInfo.alarm then
              alarmState.timeAtSignal = true
              newAlarm[forceName] = true
              trainInfo.updated = true
              trainInfo.alarmType = "timeAtSignal"
            end
            alarmSet = true
            trainInfo.alarm = true
          end
          if trainInfo.train.valid then
            local noFuel = false
            local locos = trainInfo.train.locomotives
            for i,carriage in pairs(locos.front_movers) do
              if carriage.get_inventory(1).is_empty() then
                noFuel = true
                break
              end
            end
            if not noFuel then
              for i,carriage in pairs(locos.back_movers) do
                if carriage.get_inventory(1).is_empty() then
                  noFuel = true
                  break
                end
              end
            end
            if noFuel then
              if not trainInfo.alarm then
                alarmState.noFuel = true
                newAlarm[forceName] = true
                trainInfo.updated = true
                trainInfo.alarmType = "noFuel"
              end
              alarmSet = true
              trainInfo.alarm = true
            end
          end
          if not alarmSet then
            if trainInfo.alarm then
              trainInfo.updated = true
            end
            trainInfo.alarm = false
          end
        end
      end

      for i,guiSettings in pairs(global.guiSettings) do
        if guiSettings.alarm == nil or guiSettings.alarm.noPath == nil or guiSettings.alarm.noFuel == nil then
          guiSettings.alarm = {}
          guiSettings.alarm.timeToStation = true
          guiSettings.alarm.timeAtSignal = true
          guiSettings.alarm.noPath = true
          guiSettings.alarm.noFuel = true
        end
        local forceName = game.players[i].force.name
        local stationDuration = global.force_settings[forceName].stationDuration/3600
        local signalDuration = global.force_settings[forceName].signalDuration/3600
        if newAlarm[forceName] and (guiSettings.alarm.timeToStation or guiSettings.alarm.timeAtSignal or guiSettings.alarm.noPath or guiSettings.alarm.noFuel) then
          if guiSettings.alarm.timeToStation and alarmState.timeToStation then
            guiSettings.alarm.active = true
            alertPlayer(game.players[i], guiSettings, game.tick, ({"msg-alarm-toolongtostation", stationDuration}))
          end
          if guiSettings.alarm.timeAtSignal and alarmState.timeAtSignal then
            guiSettings.alarm.active = true
            alertPlayer(game.players[i], guiSettings, game.tick, ({"msg-alarm-toolongatsignal", signalDuration}))
          end
          if guiSettings.alarm.noPath and alarmState.noPath then
            guiSettings.alarm.active = true
            alertPlayer(game.players[i], guiSettings, game.tick, ({"msg-alarm-nopath"}))
          end
          if guiSettings.alarm.noFuel and alarmState.noFuel then
            guiSettings.alarm.active = true
            alertPlayer(game.players[i], guiSettings, game.tick, ({"msg-alarm-nofuel"}))
          end
          GUI.refreshTrainInfoGui(global.trainsByForce[game.players[i].force.name], guiSettings, game.players[i])
        else
          guiSettings.alarm.active = false
        end
      end
    end
  end)
  if err then debugDump(err,true) end
end

function getLocomotives(train)
  if train ~= nil and train.valid then
    local locos = {}
    for i, fm in pairs(train.locomotives.front_movers) do
      table.insert(locos, fm)
    end
    for i, fm in pairs(train.locomotives.back_movers) do
      table.insert(locos, fm)
    end
    return locos
  end
end

function getTrainFromLocomotives(locomotives)
  if locomotives ~= nil then
    for i,loco in pairs(locomotives) do
      if loco ~= nil and loco.valid and loco.train ~= nil and loco.train.valid then
        return loco.train
      end
    end
  end
end

function updateTrainInfo(trainInfo, tick)
  if trainInfo ~= nil then
    trainInfo.updated = false

    if trainInfo.lastState == nil or trainInfo.lastState ~= trainInfo.train.state then
      --return if state changes from on the path to wait at signal in 2 ticks
      if (trainInfo.train.state == 5 and trainInfo.lastState == 0 and tick-1 == trainInfo.lastStateTick) or
        (trainInfo.train.state == 0 and trainInfo.lastState == 5 and tick-300 == trainInfo.lastStateTick) then
        --debugDump("wrong update",true)
        trainInfo.lastState = trainInfo.train.state
        trainInfo.lastStateTick = tick
        return
      end
      trainInfo.updated = true
      if trainInfo.train.state == 7 then
        trainInfo.lastStateStation = tick
      elseif trainInfo.train.state == 4 then
        trainInfo.lastStateSignal = tick
      elseif trainInfo.train.state == 0 then
        if trainInfo.alarmType then
          if trainInfo.alarmType == "timeToStation" then
            trainInfo.alarm = false
            trainInfo.alarmType = false
            trainInfo.lastStateStation = nil
          end
        end
        --was waiting at signal and last state change is more than 1 tick ago --> left signal
      elseif trainInfo.lastState == 5 and trainInfo.train.state == 0 then
        if tick-1 > trainInfo.lastStateTick then
          --debugDump("left signal",true)
          if trainInfo.alarmType == "tiemAtSignal" then
            trainInfo.alarm  = false
            trainInfo.alarmType = false
            trainInfo.lastStateSignal = nil
          end
        end
      end
      trainInfo.lastState = trainInfo.train.state
      trainInfo.lastStateTick = tick
    end

    updateTrainInfoIfChanged(trainInfo, "manualMode", trainInfo.train.manual_mode)
    updateTrainInfoIfChanged(trainInfo, "speed", trainInfo.train.speed)

    --SET InventoryText (trainInfo.train.state == 9 or trainInfo.train.state == 7
    if (trainInfo.train.state == 7 or (trainInfo.train.state == 9 and trainInfo.train.speed == 0)) or not trainInfo.updatedInventory then
      local tempInventory = getHighestInventoryCount(trainInfo)
      trainInfo.updatedInventory = true
      if tempInventory ~= nil then
        updateTrainInfoIfChanged(trainInfo, "inventory", tempInventory)
      end
    end

    --SET CurrentStationText
    if trainInfo.train.schedule ~= nil and trainInfo.train.schedule.current ~= nil and trainInfo.train.schedule.current ~= 0 then
      if trainInfo.train.schedule.records[trainInfo.train.schedule.current] ~= nil then
        updateTrainInfoIfChanged(trainInfo, "currentStation", trainInfo.train.schedule.records[trainInfo.train.schedule.current].station)
      else
        updateTrainInfoIfChanged(trainInfo, "currentStation", "Auto")
      end
    end


    if trainInfo.train.schedule ~= nil and trainInfo.train.schedule.records ~= nil and trainInfo.train.schedule.records[1] ~= nil then
      trainInfo.stations = {}
      for i, record in pairs(trainInfo.train.schedule.records) do
        trainInfo.stations[record.station] = true
      end
    else
      trainInfo.stations = nil
    end
  end
end

function isTrainInfoDuplicate(trains, trainInfoB, index)
  --local trainInfoB = trains[index]
  if trainInfoB ~= nil and trainInfoB.train ~= nil and trainInfoB.train.valid then
    for i, trainInfo in pairs(trains) do
      --debugLog(i)
      if i ~= index and trainInfo.train ~= nil and trainInfo.train.valid and compareTrains(trainInfo.train, trainInfoB.train) then
        return true
      end
    end
  end

  return false
end

function updateTrains(trains)
  --if trains ~= nil then
  local to_remove = {}
  for i, trainInfo in pairs(trains) do

    --refresh invalid train objects
    if trainInfo.train == nil or not trainInfo.train.valid then
      if trainInfo.locomotives then
        for i, carriage in pairs(trainInfo.locomotives) do
          if carriage and carriage.valid then
            trainInfo.train = carriage.train
          end
        end
      end
      --trainInfo.train = getTrainFromLocomotives(trainInfo.locomotives)
      trainInfo.locomotives = getLocomotives(trainInfo.train)
      if isTrainInfoDuplicate(trains, trainInfo, i) then
        trainInfo.train = nil
      end
    end

    if (trainInfo.train == nil or not trainInfo.train.valid) then
      table.insert(to_remove, i)
    else
      trainInfo.locomotives = getLocomotives(trainInfo.train)
      updateTrainInfo(trainInfo, game.tick)
      --debugLog(trainInfo.train.state)
    end
  end
  for i=#to_remove,1,-1 do
    table.remove(trains, to_remove[i])
  end
  --end
end

entityBuilt = function(event)
  local entity = event.created_entity
  if entity.type == "locomotive" and global.unlocked then --or entity.type == "cargo-wagon"
    getTrainInfoOrNewFromEntity(global.trainsByForce[entity.force.name], entity)
  end
end

script.on_event(defines.events.on_built_entity, entityBuilt)
script.on_event(defines.events.on_robot_built_entity, entityBuilt)

function on_train_changed_state(event)
  local status, err = pcall(function()
    --debugLog("State Change - " .. game.tick)

    local train = event.train
    local entity = train.carriages[1]
    --debugDump(game.tick.." state:"..train.state,true)
    local trains = global.trainsByForce[entity.force.name]
    local trainInfo = getTrainInfoOrNewFromEntity(trains, entity)
    if trainInfo ~= nil then
      local newtrain = false
      if trainInfo.updated == nil then
        newtrain = true
      end
      updateTrainInfo(trainInfo,game.tick)
      if newtrain then
        for i,player in pairs(game.players) do
          global.guiSettings[i].pageCount = getPageCount(trains, global.guiSettings[i])
        end
      end
      GUI.refreshAllTrainInfoGuis(global.trainsByForce, global.guiSettings, game.players, newtrain)
    end
  end)
  if err then debugDump(err,true) end
end

function register_events()
  script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
  script.on_event(defines.events.on_tick, onTickAfterUnlocked)
  script.on_event(defines.events.on_gui_click, GUI.onguiclick)
end

function getTrainInfoFromElementName(trains, elementName)
  for i, trainInfo in pairs(trains) do
    if trainInfo ~= nil and trainInfo.guiName ~= nil and startsWith(elementName, trainInfo.guiName .. "_") then
      return trainInfo
    end
  end
end

function getTrainInfoFromEntity(trains, entity)
  if trains ~= nil then
    for i, trainInfo in pairs(trains) do
      if trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid
        and entity == trainInfo.train.carriages[1] then
        return trainInfo
      end
    end
  end
end

function getNewTrainInfo(train)
  if train ~= nil then
    local carriages = train.carriages
    if carriages ~= nil and carriages[1] ~= nil and carriages[1].valid then
      local newTrainInfo = {}
      newTrainInfo.train = train
      newTrainInfo.locomotives = getLocomotives(train)
      return newTrainInfo
    end
  end
end

function getTrainInfoOrNewFromTrain(trains, train)
  if trains ~= nil then
    for i, trainInfo in pairs(trains) do
      if trainInfo ~= nil and trainInfo.train and trainInfo.train.valid and train == trainInfo.train then
        return trainInfo
      end
    end
    local newTrainInfo = getNewTrainInfo(train)
    table.insert(trains, newTrainInfo)
    return newTrainInfo
  end
end

function getTrainInfoOrNewFromEntity(trains, entity)
  local trainInfo = getTrainInfoFromEntity(trains, entity)
  if trainInfo == nil then
    local newTrainInfo = getNewTrainInfo(entity.train)
    table.insert(trains, newTrainInfo)
    return newTrainInfo
  else
    return trainInfo
  end
end

function tableIsEmpty(tableA)
  if tableA ~= nil then
    for i,v in pairs(tableA) do
      return false
    end
  end
  return true
end

function getPageCount(trains, guiSettings)
  local trainCount = 0
  for i,trainInfo in pairs(trains) do
    if guiSettings.activeFilterList == nil or trainInfo.matchesStationFilter then
      trainCount = trainCount + 1
    end
  end
  return math.floor((trainCount - 1) / guiSettings.displayCount) + 1
end

function get_filter_PageCount(guiSettings)
  local stationCount = 0
  for _, s in pairs(guiSettings.stationFilterList) do
    stationCount = stationCount + 1
  end
  return math.floor((stationCount - 1) / (global.PAGE_SIZE)) + 1
end

local onEntityDied = function (event)
  if global.unlocked and global.guiSettings ~= nil then
    local entities = {locomotive=true, ["cargo-wagon"]=true, player=true}
    if not entities[event.entity.type] then
      return
    end
    if event.entity.type == "locomotive" or event.entity.type == "cargo-wagon" then
      for forceName,trains in pairs(global.trainsByForce) do
        updateTrains(trains)
      end
    else
      if event.entity.name ~= "fatcontroller" then
        -- player died
        for i,guiSettings in pairs(global.guiSettings) do
          -- check if character is still valid next tick for players remote controlling a train
          if guiSettings.followEntity then
            global.dead_players = global.dead_players or {}
            global.dead_players[i] = global.character[i]
          end
        end
      end
    end

    for i, player in pairs(game.players) do
      local guiSettings = global.guiSettings[i]
      if guiSettings.followEntity ~= nil and guiSettings.followEntity == event.entity then --Go back to player
        if game.players[i].vehicle ~= nil then
          game.players[i].vehicle.passenger = nil
      end
      if player.connected then
        swapPlayer(game.players[i], global.character[i])
        global.character[i] = nil
        if guiSettings.fatControllerButtons.returnToPlayer ~= nil then
          guiSettings.fatControllerButtons.returnToPlayer.destroy()
        end
        guiSettings.followEntity = nil
      else
        if not global.to_swap then
          global.to_swap = {}
        end
        table.insert(global.to_swap, {index=i, character=global.character[i]})
      end
      end
    end
    GUI.refreshAllTrainInfoGuis(global.trainsByForce, global.guiSettings, game.players, true)
  end
end

script.on_event(defines.events.on_entity_died, onEntityDied)
script.on_event(defines.events.on_preplayer_mined_item, onEntityDied)

function on_player_mined(event)
  local entities = {locomotive=true, ["cargo-wagon"]=true, player=true}
  local ent_type = game.entity_prototypes[event.item_stack.name] and game.entity_prototypes[event.item_stack.name].type or "fo"
  --debugDump(ent_type,true)
  if entities[ent_type] then
    for force_name, trains in pairs(global.trainsByForce) do
      updateTrains(trains)
    end
    GUI.refreshAllTrainInfoGuis(global.trainsByForce, global.guiSettings, game.players, true)
  end
end

script.on_event(defines.events.on_player_mined_item, on_player_mined)

function swapPlayer(player, character)
  --player.teleport(character.position)
  if not player.connected then return end
  if player.character ~= nil and player.character.valid and player.character.name == "fatcontroller" then
    player.character.destroy()
  end
  if character.valid then
    player.character = character
  end
end

function removeTrainInfoFromElementName(trains, elementName)
  for i, trainInfo in pairs(trains) do
    if trainInfo ~= nil and trainInfo.guiName ~= nil and startsWith(elementName, trainInfo.guiName .. "_") then
      table.remove(trains, i)
      return
    end
  end
end

function removeTrainInfoFromEntity(trains, entity)
  for i, trainInfo in pairs(trains) do
    if trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid and trainInfo.train.carriages[1] == entity then
      table.remove(trains, i)
      return
    end
  end
end

function getHighestInventoryCount(trainInfo)
  local inventory = nil

  if trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid and trainInfo.train.carriages ~= nil then
    local itemsCount = 0
    local largestItem = {}
    local items = trainInfo.train.get_contents() or {}

    for i, carriage in pairs(trainInfo.train.carriages) do
      if carriage and carriage.valid and carriage.name == "rail-tanker" then
        debugLog("Looking for Oil!")
        local liquid = remote.call("railtanker","getLiquidByWagon",carriage)
        if liquid then
          debugLog("Liquid!")
          local name = liquid.type
          local count = math.floor(liquid.amount)
          if name then
            if not items[name] then
              items[name] = 0
            end
            items[name] = items[name] + count
          end
        end
      end
    end
    for name, count in pairs(items) do
      if largestItem.count == nil or largestItem.count < items[name] then
        largestItem.name = name
        largestItem.count = items[name]
      end
      itemsCount = itemsCount + 1
    end

    if largestItem.name ~= nil then
      local isItem = game.item_prototypes[largestItem.name] or game.fluid_prototypes[largestItem.name]
      local displayName = isItem and isItem.localised_name or largestItem.name
      local suffix = itemsCount > 1 and "..." or ""
      inventory = {"", displayName,": ",largestItem.count, suffix}
    else
      inventory = ""
    end
  end
  return inventory
end

function newFatControllerEntity(player)
  return player.surface.create_entity({name="fatcontroller", position=player.position, force=player.force})
end

function compareTrains(trainA, trainB)
  if trainA ~= nil and trainA.valid and trainB ~= nil and trainB.valid and trainA.carriages[1] == trainB.carriages[1] then
    return true
  end
  return false
end

function updateTrainInfoIfChanged(trainInfo, field, value)
  if trainInfo ~= nil and field ~= nil and trainInfo[field] ~= value then
    trainInfo[field] = value
    trainInfo.updated = true
    return true
  end
  return false
end

function containsEntity(entityTable, entityA)
  if entityTable ~= nil and entityA ~= nil then
    for i, entityB in pairs(entityTable) do
      if entityB ~= nil and entityB == entityA then
        return true
      end
    end
  end
  return false
end

function filterTrainInfoList(trains, activeFilterList)
  --if trains ~= nil  then
  for i,trainInfo in pairs(trains) do
    if activeFilterList ~= nil then
      trainInfo.matchesStationFilter = matchStationFilter(trainInfo, activeFilterList)
    else
      trainInfo.matchesStationFilter = true
    end
  end

  --end

end

function matchStationFilter(trainInfo, activeFilterList)
  local fullMatch = false
  if trainInfo ~= nil and trainInfo.stations ~= nil then
    for filter, value in pairs(activeFilterList) do
      if trainInfo.stations[filter] then
        fullMatch = true
      else
        return false
      end
    end
  end

  return fullMatch
end

function trainInList(trains, train)
  for i, trainInfo in pairs(trains) do
    if train ~= nil and train.valid and train.carriages[1] ~= nil and
      trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid and
      trainInfo.train.carriages[1] ~= nil and train.carriages[1] == trainInfo.train.carriages[1] then
      return true
    end
  end
  return false
end

function matchStringInTable(stringA, tableA)
  for i, stringB in pairs(tableA) do
    if stringA == stringB then
      return true
    end
  end
  return false
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function debugLog(message)
  if false then -- set for debug
    for i,player in pairs(game.players) do
      player.print(message)
  end
  end
end

function startsWith(String,Start)
  debugLog(String)
  debugLog(Start)
  return string.sub(String,1,string.len(Start))==Start
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function debugDump(var, force)
  if false or force then
    for i,player in pairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end

function saveVar(var, name, varname)
  local var = var or global
  local varname = varname or "global"
  local n = name or ""
  game.write_file("FAT"..n..".lua", serpent.block(var, {name=varname}))
end

function findTrains()
  -- create shorthand object for primary game surface
  local surface = game.surfaces['nauvis']

  -- determine map size
  local min_x, min_y, max_x, max_y = 0, 0, 0, 0
  for c in surface.get_chunks() do
    if c.x < min_x then
      min_x = c.x
    elseif c.x > max_x then
      max_x = c.x
    end
    if c.y < min_y then
      min_y = c.y
    elseif c.y > max_y then
      max_y = c.y
    end
  end

  -- create bounding box covering entire generated map
  local bounds = {{min_x*32,min_y*32},{max_x*32,max_y*32}}
  for _, loco in pairs(surface.find_entities_filtered{area=bounds, type="locomotive"}) do
    getTrainInfoOrNewFromTrain(global.trainsByForce[loco.force.name], loco.train)
  end
end

remote.add_interface("fat",
  {
    saveVar = function(name)
      saveVar(global, name)
    end,

    remove_invalid_players = function()
      local delete = {}
      for i,p in pairs(global.guiSettings) do
        if not game.players[i] then
          delete[i] = true
        end
      end
      for j,c in pairs(delete) do
        global.guiSettings[j] = nil
      end
    end,

    init = function()
      global.PAGE_SIZE = 60
      for i,g in pairs(global.guiSettings) do
        g.filter_page = 1
        g.filter_pageCount = get_filter_PageCount(g)
        g.stopButton_state = false
      end
      init_forces()
    end,

    rescan_trains = function()
      for i, guiSettings in pairs(global.guiSettings) do
        if guiSettings.fatControllerGui.trainInfo ~= nil then
          guiSettings.fatControllerGui.trainInfo.destroy()
          if global.character[i] then
            swapPlayer(game.players[i], global.character[i])
          end
          if guiSettings.fatControllerButtons ~= nil and guiSettings.fatControllerButtons.toggleTrainInfo then
            guiSettings.fatControllerButtons.toggleTrainInfo.caption = {"text-trains-collapsed"}
          end
        end
      end
      for force, trains in pairs(global.trainsByForce) do
        local c = #trains
        for i=c,1,-1 do
          if not trains[i].train.valid then
            trains[i] = nil
          end
        end
      end
      findTrains()
    end,

    page_size = function(size)
      global.PAGE_SIZE = tonumber(size)
    end,
  })
