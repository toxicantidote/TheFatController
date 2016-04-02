require "defines"
require "util"
require "TrainList"
require "GUI"

MOD_NAME = "TheFatController"

-- myevent = game.generateeventname()
-- the name and tick are filled for the event automatically
-- this event is raised with extra parameter foo with value "bar"
--game.raiseevent(myevent, {foo="bar"})
events = {}
events["on_player_opened"] = script.generate_event_name()
events["on_player_closed"] = script.generate_event_name()

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
  stopButton_state = false,
  displayed_trains = {}
}

character_blacklist = {
  ["orbital-uplink"] = true, --Satellite Uplink Station
  ["yarm-remote-viewer"] = true, --YARM
}

TRAINS = {}

TrainInfo = {
  dirty = false, -- flag to indicate the guis need updating
  current_station = false, --name of current station
  depart_at = 0, --tick when train will depart the station
  --main_index = 0, -- always equal to global.trainsByForce[force.name] index
  train = false, -- ref to lua_train
  previous_state = 0,
  previous_state_tick = 0,
  last_state = 0, -- last trainstate
  last_state_tick = 0,
  locomotives = {}, -- locomotives of train (to revalidate a train?)
  first_carriage = false,
  last_carriage = false,
  type = "", -- L-CC-L etc
  follower_index = 0, -- player_index of following player
  opened_guis = {}, -- contains references to opened player guis, indexed by player_index
  stations = {}, --boolean table, indexed by stations in the schedule, new global trains_by_station?? should speedup filtered display
  matches_filter = {}, --whether the stations match the filter
  alarm = {
    active = false,
    last_message = 0, --tick
    arrived_at_signal = 0, -- tick
    arrived_at_station = 0, --tick
  }
}

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

function pauseError(err, desc)
  if game then
    debugDump("Error in FatController:",true)
    debugDump(err,true)
    --global.error = {msg = err, desc = desc}
    --game.write_file("errorReportFatController.txt", serpent.block(global, {name="global"}))
    --global.error = nil
  else
    log(err)
  end
end

local function init_global()
  global = global or {}
  global.gui = global.gui or {}
  global.trainsByForce = global.trainsByForce or {}
  global.character = global.character or {}
  global.unlocked = global.unlocked or false
  global.unlockedByForce = global.unlockedByForce or {}
  global.updateEntities = global.updateEntities or false
  global.updateTrains = global.updateTrains or {}
  global.PAGE_SIZE = global.PAGE_SIZE or 60
  global.station_count = global.station_count or {}
  global.player_opened = global.player_opened or {}
  global.opened_name = global.opened_name or {}
  --global.force_settings = global.force_settings or {}
end

local function init_player(player)
  global.gui[player.index] = global.gui[player.index] or util.table.deepcopy(defaultGuiSettings)
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
  global.station_count[force.name] = global.station_count[force.name] or {}
  --global.force_settings[force.name] = global.force_settings[force.name] or {signalDuration=defaults.signalDuration*3600,stationDuration=defaults.stationDuration*3600}
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
  --  global.TRAINS = {}
  --  for force, trains in pairs(global.trainsByForce) do
  --    for i, trainInfo in pairs(trains) do
  --      if trainInfo.train and trainInfo.train.valid then
  --        global.TRAINS[trainInfo.train] = trainInfo
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
      debugDump("Updating TheFatController from "..oldVersion.." to "..newVersion,true)
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
      if oldVersion < "0.4.0" then
        local tmp = {}
        for i, player in pairs(game.players) do
          tmp[i] = {}
          tmp[i].fatControllerGui = global.guiSettings[i].fatControllerGui
          tmp[i].fatControllerButtons = global.guiSettings[i].fatControllerButtons
        end
        global = nil
        on_init()
        for i, player in pairs(game.players) do
          global.gui[i].fatControllerGui = tmp[i].fatControllerGui
          global.gui[i].fatControllerButtons = tmp[i].fatControllerButtons
        end
        findTrains()
      end
    end
    if not oldVersion or oldVersion < "0.3.14" or newVersion == "0.3.19" then
      findTrains()
    end
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

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)
script.on_event(defines.events.on_forces_merging, on_forces_merging)

script.on_event(defines.events.on_research_finished, function(event)
  local status, err = pcall(on_research_finished, event)
  if err then debugDump(err,true) end
end)

function register_events()
  script.on_event(defines.events.on_gui_click, GUI.onguiclick)
end

function getHighestInventoryCount(trainInfo)
  local inventory = nil

  if trainInfo and trainInfo.train and trainInfo.train.valid and trainInfo.train.cargo_wagons then
    local itemsCount = 0
    local largestItem = {}
    local items = trainInfo.train.get_contents() or {}

    for i, carriage in pairs(trainInfo.train.cargo_wagons) do
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

function on_tick(event)
  local status, err = pcall(function()
    if global.updateEntities then
      for i, ent in pairs(global.updateEntities) do
        debugDump("updateEnt"..i,true)
        if ent.valid then
          TrainList.add_train(ent.train)
        end
      end
      global.updateEntities = false
      --script.on_event(defines.events.on_tick, nil)
    end

    if global.updateTrains[game.tick] then
      for _, ti in pairs(global.updateTrains[game.tick]) do
        ti.inventory = getHighestInventoryCount(ti)
        GUI.update_single_traininfo(ti)
        if ti.last_state == defines.trainstate.wait_station then
          local nextUpdate = game.tick+60
          global.updateTrains[nextUpdate] = global.updateTrains[nextUpdate] or {}
          table.insert(global.updateTrains[nextUpdate], ti)
        else
          ti.depart_at = false
        end
      end
      global.updateTrains[game.tick] = nil
    end

    if event.tick%10==7  then
      for pi, player in pairs(game.players) do
        if player.connected then
          if player.opened ~= nil and not global.player_opened[pi] then
            game.raise_event(events["on_player_opened"], {entity=player.opened, player_index=pi})
            global.player_opened[pi] = player.opened
          end
          if global.player_opened[pi] and player.opened == nil then
            game.raise_event(events["on_player_closed"], {entity=global.player_opened[pi], player_index=pi})
            global.player_opened[pi] = nil
          end
        end
      end
    end

  end)
  if err then debugDump(err,true) end
end

script.on_event(defines.events.on_tick, on_tick)

function on_built_entity(event)
  local status, err = pcall(function()
    local ent = event.created_entity
    local ctype = ent.type
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      -- can be a new train or added to an existing one
      TrainList.add_train(ent.train)
    end
  end)
  if not status then
    pauseError(err, "on_built_entity")
  end
end

function on_preplayer_mined_item(event)
  local status, err = pcall(function()
    local ent = event.entity
    local ctype = ent.type
    if ctype == "locomotive" or ctype == "cargo-wagon" then
      local oldTrain = ent.train
      -- an existing train can be shortened or split in two trains or be removed completely
      local length = #oldTrain.carriages
      if length == 1 then
        TrainList.remove_train(ent.train)
        return
      end
      local ownPos
      for i,carriage in pairs(ent.train.carriages) do
        if ent == carriage then
          ownPos = i
          break
        end
      end
      if ent.train.carriages[ownPos-1] ~= nil then
        if not global.updateEntities then global.updateEntities = {} end
        debugDump(game.tick.."Add 1 front",true)
        table.insert(global.updateEntities, ent.train.carriages[ownPos-1])
        --script.on_event(defines.events.on_tick, on_tick)
      end
      if ent.train.carriages[ownPos+1] ~= nil then
        if not global.updateEntities then global.updateEntities = {} end
        debugDump(game.tick.."Add 1 behind",true)
        table.insert(global.updateEntities, ent.train.carriages[ownPos+1])
        --script.on_event(defines.events.on_tick, on_tick)
      end
    end
  end)
  if not status then
    pauseError(err, "on_pre_player_mined_item")
  end
end

script.on_event(defines.events.on_preplayer_mined_item, on_preplayer_mined_item)
script.on_event(defines.events.on_built_entity, on_built_entity)

function on_train_changed_state(event)
  local status, err = pcall(function()
    local train = event.train
    local entity = train.carriages[1]
    --debugDump(game.tick.." state:"..train.state,true)
    local trainInfo = TrainList.get_traininfo(entity.force, train)
    if trainInfo then
      trainInfo.previous_state = trainInfo.last_state
      trainInfo.previous_state_tick = trainInfo.last_state_tick
      trainInfo.last_state = train.state
      trainInfo.last_state_tick = game.tick
      -- skip update if:
      --  going from wait_signal to on_the_path after 300 ticks
      --  going from on_the_path to wait_signal after 1 tick
      --  arrive_signal
      local diff = game.tick - trainInfo.previous_state_tick
      if  train.state == defines.trainstate.arrive_signal or
        (trainInfo.previous_state == defines.trainstate.wait_signal and train.state == defines.trainstate.on_the_path
        and diff == 300)
        or (trainInfo.previous_state == defines.trainstate.on_the_path and train.state == defines.trainstate.wait_signal
        and diff == 1) then
        --debugDump(game.tick.." Skipped",true)
        return
      end

      if train.state == defines.trainstate.wait_station then
        trainInfo.depart_at = game.tick + train.schedule.records[train.schedule.current].time_to_wait
        trainInfo.inventory = getHighestInventoryCount(trainInfo)
        local nextUpdate = game.tick+60
        global.updateTrains[nextUpdate] = global.updateTrains[nextUpdate] or {}
        table.insert(global.updateTrains[nextUpdate], trainInfo)
      else
        trainInfo.depart_at = false
      end
      local station = (#train.schedule.records > 0) and train.schedule.records[train.schedule.current].station or false
      trainInfo.current_station = station
      GUI.update_single_traininfo(trainInfo)
    end
  end)
  if err then debugDump(err,true) end
end

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)

function decreaseStationCount(station, name)
  local force = station.force.name
  if not global.station_count[force][name] then
    global.station_count[force][name] = 1
  end
  global.station_count[force][name] = global.station_count[force][name] - 1
  return global.station_count[force][name]
end

function increaseStationCount(station)
  local name = station.backer_name
  local force = station.force.name
  if not global.station_count[force][name] or global.station_count[force][name] < 0 then
    global.station_count[force][name] = 0
  end
  global.station_count[force][name] = global.station_count[force][name] + 1
  return global.station_count[force][name]
end

function on_station_rename(station, oldName)
  local oldc = decreaseStationCount(station, oldName)
  local newc = increaseStationCount(station)
  if oldc == 0 then
    global.station_count[station.force.name][oldName] = nil
  end
end

function on_player_opened(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" and event.entity.train then
    
    elseif event.entity.type == "cargo-wagon" and event.entity.train then 
    
    elseif event.entity.type == "train-stop" then
      global.opened_name[event.player_index] = event.entity.backer_name
    end
  end
end

function on_player_closed(event)
  if event.entity.valid and game.players[event.player_index].valid then
    if event.entity.type == "locomotive" and event.entity.train then

    elseif event.entity.type == "cargo-wagon" and event.entity.train then

    elseif event.entity.type == "train-stop" then
      if event.entity.backer_name ~= global.opened_name[event.player_index] then
        on_station_rename(event.entity, global.opened_name[event.player_index])
        global.opened_name[event.player_index] = nil
      end
    end
  end
end

script.on_event(events.on_player_opened, on_player_opened)
script.on_event(events.on_player_closed, on_player_closed)

function getPageCount(trains, guiSettings, player)
  local trainCount = 0
  if not trains then error("no trains", 2) end
  for i,trainInfo in pairs(trains) do
    if guiSettings.activeFilterList == nil or trainInfo.matches_filter[player.index] then
      trainCount = trainCount + 1
    end
  end
  return math.floor((trainCount - 1) / guiSettings.displayCount) + 1
end

function get_filter_PageCount(force)
  local stationCount = 0
  for _, s in pairs(global.station_count[force.name]) do
    stationCount = stationCount + 1
  end
  return math.floor((stationCount - 1) / (global.PAGE_SIZE)) + 1
end

local on_entity_died = function (event)
  local entities = {locomotive=true, ["cargo-wagon"]=true, player=true}
  if not entities[event.entity.type] then
    return
  end
  if event.entity.type == "locomotive" or event.entity.type == "cargo-wagon" then
    local ent = event.entity
    local oldTrain = ent.train
    -- an existing train can be shortened or split in two trains or be removed completely
    local length = #oldTrain.carriages
    if length == 1 then
      TrainList.remove_train(oldTrain)
      return
    end
    local ownPos
    for i,carriage in pairs(ent.train.carriages) do
      if ent == carriage then
        ownPos = i
        break
      end
    end
    if ent.train.carriages[ownPos-1] ~= nil then
      if not global.updateEntities then global.updateEntities = {} end
      table.insert(global.updateEntities, ent.train.carriages[ownPos-1])
      --script.on_event(defines.events.on_tick, on_tick)
    end
    if ent.train.carriages[ownPos+1] ~= nil then
      if not global.updateEntities then global.updateEntities = {} end
      table.insert(global.updateEntities, ent.train.carriages[ownPos+1])
      --script.on_event(defines.events.on_tick, on_tick)
    end
    return
  end
  if event.entity.name ~= "fatcontroller" then
    -- player died
    for i,guiSettings in pairs(global.gui) do
      -- check if character is still valid next tick for players remote controlling a train
      if guiSettings.followEntity then
        global.dead_players = global.dead_players or {}
        global.dead_players[i] = global.character[i]
      end
    end
  end

  --    for i, player in pairs(game.players) do
  --      local guiSettings = global.gui[i]
  --      if guiSettings.followEntity ~= nil and guiSettings.followEntity == event.entity then --Go back to player
  --        if game.players[i].vehicle ~= nil then
  --          game.players[i].vehicle.passenger = nil
  --      end
  --      if player.connected then
  --        swapPlayer(game.players[i], global.character[i])
  --        global.character[i] = nil
  --        if guiSettings.fatControllerButtons.returnToPlayer ~= nil then
  --          guiSettings.fatControllerButtons.returnToPlayer.destroy()
  --        end
  --        guiSettings.followEntity = nil
  --      else
  --        if not global.to_swap then
  --          global.to_swap = {}
  --        end
  --        table.insert(global.to_swap, {index=i, character=global.character[i]})
  --      end
  --      end
  --    end
  --    GUI.refreshAllTrainInfoGuis(global.trainsByForce, global.gui, game.players, true)
end

script.on_event(defines.events.on_entity_died, on_entity_died)

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

function newFatControllerEntity(player)
  return player.surface.create_entity({name="fatcontroller", position=player.position, force=player.force})
end

function matchStationFilter(trainInfo, activeFilterList)
  local fullMatch = false
  local stations = {}
  local records = (trainInfo.train.schedule and #trainInfo.train.schedule.records > 0) and trainInfo.train.schedule.records or false
  if not records then return false end
  for i, record in pairs(records) do
    stations[record.station] = true
  end
  if trainInfo ~= nil then
    for filter, value in pairs(activeFilterList) do
      if stations[filter] then
        fullMatch = true
      else
        return false
      end
    end
  end

  return fullMatch
end

function filterTrainInfoList(trains, activeFilterList, player)
  for i,trainInfo in pairs(trains) do
    if activeFilterList ~= nil then
      trainInfo.matches_filter[player.index] = matchStationFilter(trainInfo, activeFilterList)
    else
      trainInfo.matches_filter[player.index] = true
    end
  end
end

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

function tableIsEmpty(tableA)
  if tableA ~= nil then
    for i,v in pairs(tableA) do
      return false
    end
  end
  return true
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
    if not TrainList.get_traininfo(loco.force, loco.train) then
      TrainList.add_train(loco.train)
    end
  end
  for _, station in pairs(surface.find_entities_filtered{area=bounds, type="train-stop"}) do
    increaseStationCount(station)
  end
end

remote.add_interface("fat",
  {
    saveVar = function(name)
      saveVar(global, name)
    end,

    remove_invalid_players = function()
      local delete = {}
      for i,p in pairs(global.gui) do
        if not game.players[i] then
          delete[i] = true
        end
      end
      for j,c in pairs(delete) do
        global.gui[j] = nil
      end
    end,

    init = function()
      global.PAGE_SIZE = 60
      for i,g in pairs(global.gui) do
        g.filter_page = 1
        g.filter_pageCount = get_filter_PageCount(g)
        g.stopButton_state = false
      end
      init_forces()
    end,

    rescan_trains = function()
      for i, guiSettings in pairs(global.gui) do
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

    test = function(selected)
      assert(global.TRAINS[selected.train])
    end,

    find_trains = function()
      global.stations = nil
      on_init()
      findTrains()
    end,
  })
