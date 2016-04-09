function endsWith(String,End)
  return End == '' or string.sub(String,-string.len(End))==End
end

function sanitizeNumber(number, default)
  return tonumber(number) or default
end

function start_following(carriage, guiSettings, element, player)
  if guiSettings.followGui and guiSettings.followGui.valid then
    guiSettings.followGui.caption = "c"
    guiSettings.followGui.style = "fatcontroller_button_style"
  end
  element.style = "fatcontroller_selected_button"
  element.caption = "X"
  guiSettings.followEntity = carriage
  guiSettings.followGui = element
  if not guiSettings.fatControllerButtons.returnToPlayer then
    guiSettings.fatControllerButtons.add({ type="button", name="returnToPlayer", caption={"text-player"}, style = "fatcontroller_selected_button"})
  end
  carriage.passenger = player.character
end

function stop_following(guiSettings, player)
  guiSettings.followEntity = nil
  if guiSettings.followGui and guiSettings.followGui.valid then
    guiSettings.followGui.caption = "c"
    guiSettings.followGui.style = "fatcontroller_button_style"
    guiSettings.followGui = nil
  end
  if guiSettings.fatControllerButtons ~= nil and guiSettings.fatControllerButtons.returnToPlayer ~= nil then
    guiSettings.fatControllerButtons.returnToPlayer.destroy()
  end
  if player.vehicle then
    player.vehicle.passenger = nil
  end
end

on_gui_click = {}
GUI = {

    new_train_window = function(gui, trainInfo, guiSettings)
      if gui[trainInfo.guiName] == nil then
        gui.add({ type="frame", name=trainInfo.guiName, direction="horizontal", style="fatcontroller_thin_frame"})
      end
      local trainGui = gui[trainInfo.guiName]

      --Add buttons
      if trainGui.buttons == nil then
        trainGui.add({type = "flow", name="buttons",  direction="horizontal", style="fatcontroller_traininfo_button_flow"})
      end

      if trainGui.buttons[trainInfo.guiName .. "_toggleManualMode"] == nil then
        trainGui.buttons.add({type="button", name=trainInfo.guiName .. "_toggleManualMode", caption="", style="fatcontroller_button_style"})
        local caption = trainInfo.train.manual_mode and ">" or "ll"
        trainGui.buttons[trainInfo.guiName.."_toggleManualMode"].caption = caption
      end

      if trainInfo.train.manual_mode then
        trainGui.buttons[trainInfo.guiName .. "_toggleManualMode"].caption = ">"
      else
        trainGui.buttons[trainInfo.guiName .. "_toggleManualMode"].caption = "ll"
      end


      if trainGui.buttons[trainInfo.guiName .. "_toggleFollowMode"] == nil then
        trainGui.buttons.add({type="button", name=trainInfo.guiName .. "_toggleFollowMode", caption={"text-controlbutton"}, style="fatcontroller_button_style"})
      end

      if trainInfo.alarm.active then
        local style = "fatcontroller_icon_" .. trainInfo.alarm.type
        if trainGui.buttons[trainInfo.guiName .. "_alarm"] == nil then
          trainGui.buttons.add({type="checkbox", name=trainInfo.guiName .. "_alarm", state=false, style=style})
        else
          trainGui.buttons[trainInfo.guiName .. "_alarm"].style = style
        end
      end


      --Add info
      if trainGui.info == nil then
        trainGui.add({type = "flow", name="info",  direction="vertical", style="fatcontroller_thin_flow"})
      end

      if trainGui.info.topInfo == nil then
        trainGui.info.add({type="label", name="topInfo", style="fatcontroller_label_style"})
      end
      if trainGui.info.bottomInfo == nil then
        trainGui.info.add({type="label", name="bottomInfo", style="fatcontroller_label_style"})
      end

      local topString = GUI.get_topstring(trainInfo)
      local bottomString = GUI.get_bottomstring(trainInfo)

      trainGui.info.topInfo.caption = topString
      trainGui.info.bottomInfo.caption = bottomString

      trainInfo.last_update = game.tick
      return trainGui
    end,

    get_topstring = function(trainInfo)
      local topString = ""
      local station = trainInfo.current_station
      if not station then station = "" end
      if trainInfo.last_state then
        if trainInfo.last_state == 1  or trainInfo.last_state == 3 then
          topString = "No Path "-- .. trainInfo.last_state
        elseif trainInfo.last_state == 2 then
          topString = "No schedule"
        elseif trainInfo.last_state == 5 then
          topString = "Signal || " .. station
        elseif (trainInfo.last_state == 8  or trainInfo.last_state == 9   or trainInfo.last_state == 10) then
          topString = "Manual"
          if trainInfo.train.speed == 0 then
            topString = topString .. ": " .. "Stopped" -- REPLACE WITH TRANSLAION
          else
            topString = topString .. ": " .. "Moving" -- REPLACE WITH TRANSLAION
          end
        elseif trainInfo.last_state == 6 then
          topString = "Stopping -> " .. station
        elseif trainInfo.last_state == 7 then
          topString = "Station || " .. station
          if trainInfo.depart_at and trainInfo.depart_at > 0 then
            topString = topString .. " (" .. util.formattime(trainInfo.depart_at-game.tick) ..")"
          end
        else
          topString = "Moving -> " .. station
        end
      end

      return topString
    end,

    get_bottomstring = function(trainInfo)
      local bottomString = ""
      if trainInfo.inventory ~= nil then
        bottomString = trainInfo.inventory
      end
      return bottomString
    end,

    update_single_traininfo = function(trainInfo, update_cargo)
      if trainInfo then
        if trainInfo.train and not trainInfo.train.valid then
          TrainList.remove_invalid(trainInfo.force)
          return
        end
        local cargo_updated = false
        local alarm = trainInfo.alarm.active and trainInfo.alarm.type or false
        for player_index, gui in pairs(trainInfo.opened_guis) do
          if gui and gui.valid then
            if alarm then
              local style = "fatcontroller_icon_" .. trainInfo.alarm.type
              --local style = "fatcontroller_icon_timeToStation"
              if gui.buttons[trainInfo.guiName .. "_alarm"] then
                gui.buttons[trainInfo.guiName .. "_alarm"].style = style
              else
                gui.buttons.add({type="checkbox", name=trainInfo.guiName .. "_alarm", state=false, style=style})
              end
            else
              if gui.buttons[trainInfo.guiName .. "_alarm"] then
                gui.buttons[trainInfo.guiName .. "_alarm"].destroy()
              end
            end
            if update_cargo and not cargo_updated then
              trainInfo.inventory = getHighestInventoryCount(trainInfo)
              cargo_updated = true
            end
            gui.info.topInfo.caption = GUI.get_topstring(trainInfo)
            gui.info.bottomInfo.caption = GUI.get_bottomstring(trainInfo)
            if trainInfo.train.manual_mode then
              gui.buttons[trainInfo.guiName .. "_toggleManualMode"].caption = ">"
            else
              gui.buttons[trainInfo.guiName .. "_toggleManualMode"].caption = "ll"
            end
          end
        end
      end
    end,

    swapCaption = function(guiElement, captionA, captionB)
      if guiElement ~= nil and captionA ~= nil and captionB ~= nil then
        if guiElement.caption == captionA then
          guiElement.caption = captionB
        elseif guiElement.caption == captionB then
          guiElement.caption = captionA
        end
      end
    end,

    --refreshAllTrainInfoGuis = function(trainsByForce, guiSettings, players, destroy)
    refreshAllTrainInfoGuis = function(force)
      --debugDump(game.tick.." refresh",true)
      update_pageCount(force)
      for i,player in pairs(force.players) do
        local gui = global.gui[player.index]
        if gui.page > gui.pageCount then gui.page = gui.pageCount end
        gui.page = gui.page > 0 and gui.page or 1
        --debugDump(gui.page, true)
        if gui ~= nil and gui.fatControllerGui.trainInfo ~= nil then
          gui.fatControllerGui.trainInfo.destroy()
          if player.connected then
            GUI.newTrainInfoWindow(gui)
            GUI.refreshTrainInfoGui(gui, player)
          else
            gui.fatControllerButtons.toggleTrainInfo.caption = {"text-trains-collapsed"}
          end
        end
      end
    end,

    init_gui = function(player)
      --debugDump("Init: " .. player.name .. " - " .. player.force.name,true)
      if player.gui.top.fatControllerButtons ~= nil then
        return
      end

      local player_gui = global.gui[player.index]
      local forceName = player.force.name

      if player.gui.left.fatController == nil then
        player_gui.fatControllerGui = player.gui.left.add({ type="flow", name="fatController", direction="vertical"})--, style="fatcontroller_thin_flow"}) --caption="Fat Controller",
      else
        player_gui.fatControllerGui = player.gui.left.fatController
      end
      if player.gui.top.fatControllerButtons == nil then
        player_gui.fatControllerButtons = player.gui.top.add({ type="flow", name="fatControllerButtons", direction="horizontal", style="fatcontroller_thin_flow"})
      else
        player_gui.fatControllerButtons = player.gui.top.fatControllerButtons
      end
      if player_gui.fatControllerButtons.toggleTrainInfo == nil then
        player_gui.fatControllerButtons.add({type="button", name="toggleTrainInfo", caption = {"text-trains-collapsed"}, style="fatcontroller_button_style"})
      end

      if player_gui.fatControllerGui.trainInfo ~= nil then
        GUI.newTrainInfoWindow(player_gui)
      end

      player_gui.pageCount = getPageCount(player_gui, player)

      return player_gui
    end,


    onguiclick = function(event)
      local status, err = pcall(function()
        local refreshGui = false
        local player_index = event.element.player_index
        local guiSettings = global.gui[player_index]
        local player = game.players[player_index]
        if not player.connected then return end
        --debugDump("CLICK! " .. event.element.name .. game.tick,true)

        if on_gui_click[event.element.name] then
          refreshGui = on_gui_click[event.element.name](guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_toggleManualMode") then
          refreshGui = on_gui_click.toggleManualMode(guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_toggleFollowMode") then
          refreshGui = on_gui_click.toggleFollowMode(guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_stationFilter") then
          refreshGui = on_gui_click.stationFilter(guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_alarm") then
          refreshGui = on_gui_click.unsetAlarm(guiSettings, event.element, player)
        end

        if refreshGui then
          GUI.newTrainInfoWindow(guiSettings)
          GUI.refreshTrainInfoGui(guiSettings, player)
        end
      end)
      if err then debugDump(err,true) end
    end,

    -- control buttons only
    newTrainInfoWindow = function(guiSettings)
      local gui = guiSettings.fatControllerGui
      local newGui
      if gui ~= nil and gui.trainInfo ~= nil then
        gui.trainInfo.destroy()
      end

      if gui ~= nil and gui.trainInfo ~= nil then
        newGui = gui.trainInfo
        debugDump("foo",true)
      else
        newGui = gui.add({ type="flow", name="trainInfo", direction="vertical", style="fatcontroller_thin_flow"})
      end

      if newGui.trainInfoControls == nil then
        newGui.add({type = "frame", name="trainInfoControls", direction="horizontal", style="fatcontroller_thin_frame"})
      end

      if newGui.trainInfoControls.pageButtons == nil then
        newGui.trainInfoControls.add({type = "flow", name="pageButtons",  direction="horizontal", style="fatcontroller_button_flow"})
      end

      if newGui.trainInfoControls.pageButtons.page_back == nil then
        if guiSettings.page > 1 then
          newGui.trainInfoControls.pageButtons.add({type="button", name="page_back", caption="<", style="fatcontroller_button_style"})
        else
          newGui.trainInfoControls.pageButtons.add({type="button", name="page_back", caption="<", style="fatcontroller_disabled_button"})
        end
      end

      if newGui.trainInfoControls.pageButtons.page_number == nil then
        newGui.trainInfoControls.pageButtons.add({type="button", name="page_number", caption=guiSettings.page .. "/" .. guiSettings.pageCount, style="fatcontroller_button_style"})
      else
        newGui.trainInfoControls.pageButtons.page_number.caption = guiSettings.page .. "/" .. guiSettings.pageCount
      end

      if newGui.trainInfoControls.pageButtons.page_forward == nil then
        if guiSettings.page < guiSettings.pageCount then
          newGui.trainInfoControls.pageButtons.add({type="button", name="page_forward", caption=">", style="fatcontroller_button_style"})
        else
          newGui.trainInfoControls.pageButtons.add({type="button", name="page_forward", caption=">", style="fatcontroller_disabled_button"})
        end

      end

      if newGui.trainInfoControls.filterButtons == nil then
        newGui.trainInfoControls.add({type = "flow", name="filterButtons",  direction="horizontal", style="fatcontroller_button_flow"})
      end

      if newGui.trainInfoControls.filterButtons.toggleStationFilter == nil then
        local style = (guiSettings.activeFilterList or guiSettings.filter_alarms) and "fatcontroller_selected_button" or "fatcontroller_button_style"
        newGui.trainInfoControls.filterButtons.add({type="button", name="toggleStationFilter", caption="s", style=style})
      end

      if newGui.trainInfoControls.filterButtons.clearStationFilter == nil then
        newGui.trainInfoControls.filterButtons.add({type="button", name="clearStationFilter", caption="x", style="fatcontroller_button_style"})
      end

      if newGui.trainInfoControls.alarm == nil then
        newGui.trainInfoControls.add({type = "flow", name="alarm",  direction="horizontal", style="fatcontroller_button_flow"})
      end

      if newGui.trainInfoControls.alarm.alarmButton == nil then
        newGui.trainInfoControls.alarm.add({type="button", name="alarmButton", caption="!", style="fatcontroller_button_style"})
      end

      if newGui.trainInfoControls.control == nil then
        newGui.trainInfoControls.add({type = "flow", name="control", direction="horizontal", style="fatcontroller_button_flow"})
      end

      if newGui.trainInfoControls.control.toggleButton == nil then
        local caption = guiSettings.activeFilterList and "filtered" or "all"
        if guiSettings.stopButton_state then
          caption = "Resume "..caption
        else
          caption = "Stop "..caption
        end
        newGui.trainInfoControls.control.add({type = "button", name="toggleButton", caption=caption, style="fatcontroller_button_style"})
      end

      return newGui
    end,

    refreshTrainInfoGui = function(guiSettings, player)
      if not player.connected then return end
      local character = player.character
      local gui = guiSettings.fatControllerGui.trainInfo
      local trains = (guiSettings.activeFilterList or guiSettings.filter_alarms) and guiSettings.filtered_trains or global.trainsByForce[player.force.name]
      if guiSettings.page > guiSettings.pageCount then guiSettings.page = guiSettings.pageCount end
      guiSettings.page = guiSettings.page > 0 and guiSettings.page or 1
      if gui ~= nil and trains ~= nil then
        --local pageStart = ((guiSettings.page - 1) * guiSettings.displayCount) + 1
        local pageStart = ((guiSettings.page - 1) * guiSettings.displayCount) + 1
        local remove_invalid = false
        GUI.reset_displayed_trains(guiSettings,player)
        --debugDump({pageStart,pageStart+guiSettings.displayCount-1},true)
        for index=pageStart,pageStart+guiSettings.displayCount-1 do
          local trainInfo = trains[index]
          if trainInfo and trainInfo.train and trainInfo.train.valid then
            if trainInfo.train ~= global.trainsByForce[player.force.name][trainInfo.mainIndex].train then
              player.print("Invalid main index: "..trainInfo.mainIndex)
              player.print("Opening and closing the gui should fix it")
              remove_invalid = true
            end
            local i = trainInfo.mainIndex
            local newGuiName = nil
            newGuiName = "Info" .. i
            if gui[newGuiName] == nil then
              trainInfo.guiName = newGuiName
              guiSettings.displayed_trains[i] = trainInfo
              local trainGui = GUI.new_train_window(gui,trainInfo, guiSettings)
              trainInfo.opened_guis[player.index] = trainGui
            end
            if character ~= nil and character.name == "fatcontroller" and ((character.vehicle.type == "cargo-wagon" or character.vehicle.type == "locomotive") and trainInfo.train == character.vehicle.train) then
              gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].style = "fatcontroller_selected_button"
              gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].caption = "X"
            else
              gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].style = "fatcontroller_button_style"
              gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].caption = "c"
            end
            trainInfo.guiName = newGuiName
          end
        end
        if remove_invalid then
          TrainList.remove_invalid(player.force)
        end
      end
    end,

    toggleStationFilterWindow = function(gui, guiSettings, player)
      if gui ~= nil then
        if gui.stationFilterWindow == nil then
          --local sortedList = table.sort(a)
          local window = gui.add({type="frame", name="stationFilterWindow", caption={"msg-stationFilter"}, direction="vertical" }) --style="fatcontroller_thin_frame"})
          window.add({type="flow", name="buttonFlow"})

          local pageFlow
          if window.buttonFlow.filter_pageButtons == nil then
            pageFlow = window.buttonFlow.add({type = "flow", name="filter_pageButtons",  direction="horizontal", style="fatcontroller_button_flow"})
          else
            pageFlow = window.buttonFlow.filter_pageButtons
          end


          if pageFlow.filter_page_back == nil then

            if guiSettings.filter_page > 1 then
              pageFlow.add({type="button", name="filter_page_back", caption="<", style="fatcontroller_button_style"})
            else
              pageFlow.add({type="button", name="filter_page_back", caption="<", style="fatcontroller_disabled_button"})
            end
          end
          local pageCount = get_filter_PageCount(player.force)
          if pageFlow.filter_page_number == nil then
            pageFlow.add({type="button", name="filter_page_number", caption=guiSettings.filter_page .. "/" ..pageCount , style="fatcontroller_disabled_button"})
          else
            pageFlow.filter_page_number.caption = guiSettings.filter_page .. "/" .. pageCount
          end

          if pageFlow.filter_page_forward == nil then
            if guiSettings.filter_page < pageCount then
              pageFlow.add({type="button", name="filter_page_forward", caption=">", style="fatcontroller_button_style"})
            else
              pageFlow.add({type="button", name="filter_page_forward", caption=">", style="fatcontroller_disabled_button"})
            end

          end
          window.buttonFlow.add({type="button", name="stationFilterClear", caption={"msg-Clear"}, style="fatcontroller_button_style"})
          window.buttonFlow.add({type="button", name="stationFilterOK", caption={"msg-OK"} , style="fatcontroller_button_style"})
          local style = guiSettings.filter_alarms and "fatcontroller_selected_button" or "fatcontroller_button_style"
          pageFlow.add({type="button", name="filterAlarms", caption="Alarms", style=style})

          window.add({type="table", name="checkboxGroup", colspan=3})
          local i=0
          local upper = guiSettings.filter_page*global.PAGE_SIZE
          local lower = guiSettings.filter_page*global.PAGE_SIZE-global.PAGE_SIZE
          for name, value in pairsByKeys(global.station_count[player.force.name]) do
            if i>=lower and i<upper then
              local state = false
              if guiSettings.activeFilterList and guiSettings.activeFilterList[name] then
                state = true
              end
              window.checkboxGroup.add({type="checkbox", name=name .. "_stationFilter", caption=name, state=state}) --style="filter_group_button_style"})
            end
            i=i+1
          end

        else
          gui.stationFilterWindow.destroy()
        end
      end
    end,

    togglePageSelectWindow = function(gui, guiSettings)
      if gui ~= nil then
        if gui.pageSelect == nil then
          local window = gui.add({type="frame", name="pageSelect", caption={"msg-displayCount"}, direction="vertical" }) --style="fatcontroller_thin_frame"})
          window.add({type="textfield", name="pageSelectValue", text=guiSettings.displayCount .. ""})
          window.pageSelectValue.text = guiSettings.displayCount .. ""
          window.add({type="button", name="pageSelectOK", caption={"msg-OK"}})
        else
          gui.pageSelect.destroy()
        end
      end
    end,

    toggleAlarmWindow = function(gui, player_index)
      local guiSettings = global.gui[player_index]
      if gui ~= nil then
        if gui.alarmWindow == nil then
          local window = gui.add({type="frame",name="alarmWindow", caption={"text-alarmwindow"}, direction="vertical" })
          local stateTimeToStation = true
          if guiSettings.alarm ~= nil and not guiSettings.alarm.timeToStation then
            stateTimeToStation = false
          end
          local flow1 = window.add({name="flowStation", type="flow", direction="horizontal"})
          flow1.add({type="checkbox", name="alarmTimeToStation", caption={"text-alarmMoreThan"}, state=stateTimeToStation}) --style="filter_group_button_style"})
          local stationDuration = flow1.add({type="textfield", name="alarmTimeToStationDuration", style="fatcontroller_textfield_small"})
          flow1.add({type="label", caption={"text-alarmtimetostation"}})
          local stateTimeAtSignal = true
          if guiSettings.alarm ~= nil and not guiSettings.alarm.timeAtSignal then
            stateTimeAtSignal = false
          end
          local flow2 = window.add({name="flowSignal",type="flow", direction="horizontal"})
          flow2.add({type="checkbox", name="alarmTimeAtSignal", caption={"text-alarmMoreThan"}, state=stateTimeAtSignal}) --style="filter_group_button_style"})
          local signalDuration = flow2.add({type="textfield", name="alarmTimeAtSignalDuration", style="fatcontroller_textfield_small"})
          flow2.add({type="label", caption={"text-alarmtimeatsignal"}})
          local stateNoPath = true
          if guiSettings.alarm ~= nil and not guiSettings.alarm.noPath then
            stateNoPath = false
          end
          window.add({type="checkbox", name="alarmNoPath", caption={"text-alarmtimenopath"}, state=stateNoPath}) --style="filter_group_button_style"})
          local stateNoFuel = true
          if guiSettings.alarm ~= nil and not guiSettings.alarm.noFuel then
            stateNoFuel = false
          end
          window.add({type="checkbox", name="alarmNoFuel", caption={"text-alarmtimenofuel"}, state=stateNoFuel})
          window.add({type="button", name="alarmOK", caption={"msg-OK"}})
          window.add({type="button", name="findCharacter", caption="Find character"})

          stationDuration.text = global.force_settings[game.players[player_index].force.name].stationDuration/3600
          signalDuration.text = global.force_settings[game.players[player_index].force.name].signalDuration/3600
        else
          gui.alarmWindow.destroy()
        end
      end
    end,

    reset_displayed_trains = function(guiSettings, player)
      local trains = global.trainsByForce[player.force.name]
      for i, ti in pairs(guiSettings.displayed_trains) do
        if ti then
          ti.opened_guis[player.index] = nil
        end
      end
      guiSettings.displayed_trains = {}
    end,
}
on_gui_click.toggleTrainInfo = function(guiSettings, element, player)
  if guiSettings.fatControllerGui.trainInfo == nil then
    element.caption = {"text-trains"}
    --return refreshGui
    return true
  else
    guiSettings.fatControllerGui.trainInfo.destroy()
    GUI.reset_displayed_trains(guiSettings,player)
    element.caption = {"text-trains-collapsed"}
    return false
  end
end

on_gui_click.returnToPlayer = function(guiSettings, element, player)
  if global.character[element.player_index] ~= nil then
    if player.vehicle ~= nil then
      player.vehicle.passenger = nil
    end
    swapPlayer(player, global.character[element.player_index])
    global.character[element.player_index] = nil
    element.destroy()
    stop_following(guiSettings, player)
  end
end

on_gui_click.page_back = function(guiSettings, element, player)
  if guiSettings.page > 1 then
    guiSettings.page = guiSettings.page - 1
    return true
  end
end

on_gui_click.page_forward = function(guiSettings, element, player)
  if guiSettings.page < guiSettings.pageCount then
    guiSettings.page = guiSettings.page + 1
    return true
  end
end

on_gui_click.page_number = function(guiSettings, element, player)
  GUI.togglePageSelectWindow(player.gui.center, guiSettings)
end

on_gui_click.pageSelectOK = function(guiSettings, element, player)
  local gui = player.gui.center.pageSelect
  if gui ~= nil then
    local newInt = tonumber(gui.pageSelectValue.text)
    if newInt then
      if newInt < 1 then
        newInt = 1
      elseif newInt > 50 then
        newInt = 50
      end
      guiSettings.displayCount = newInt
      guiSettings.pageCount = getPageCount(guiSettings, player)
      guiSettings.page = 1
    else
      player.print({"msg-notanumber"})
    end
    gui.destroy()
    return true
  end
end

on_gui_click.toggleStationFilter = function(guiSettings, element, player)
  local trains = global.trainsByForce[player.force.name]
  GUI.toggleStationFilterWindow(player.gui.center, guiSettings, player)
end

on_gui_click.stationFilterClear = function(guiSettings, element, player)
  local refresh = false
  if guiSettings.activeFilterList or guiSettings.filter_alarms then
    guiSettings.activeFilterList = nil
    guiSettings.filter_alarms = false
    refresh = true
  end
  if player.gui.center.stationFilterWindow ~= nil then
    player.gui.center.stationFilterWindow.destroy()
  end
  guiSettings.filtered_trains = false
  guiSettings.pageCount = getPageCount(guiSettings, player)
  return refresh
end

on_gui_click.clearStationFilter = function(guiSettings, element, player)
  return on_gui_click.stationFilterClear(guiSettings, element, player)
end

on_gui_click.stationFilterOK = function(guiSettings, element, player)
  local gui = player.gui.center.stationFilterWindow
  if gui ~= nil and gui.checkboxGroup ~= nil then
    local newFilter = {}
    local listEmpty = true
    for station,value in pairs(global.station_count[player.force.name]) do
      local checkboxA = gui.checkboxGroup[station .. "_stationFilter"]
      if checkboxA ~= nil and checkboxA.state then
        listEmpty = false
        newFilter[station] = true
      end
    end
    if not listEmpty then
      guiSettings.activeFilterList = newFilter
    else
      guiSettings.activeFilterList = nil
    end
    gui.destroy()
    guiSettings.page = 1
    return true
  end
end

on_gui_click.filter_page_forward = function(guiSettings, element, player)
  if guiSettings.filter_page < get_filter_PageCount(player.force) then
    guiSettings.filter_page = guiSettings.filter_page + 1
    GUI.toggleStationFilterWindow(player.gui.center, guiSettings, player)
    GUI.toggleStationFilterWindow(player.gui.center, guiSettings, player)
  end
end

on_gui_click.filter_page_back = function(guiSettings, element, player)
  if guiSettings.filter_page > 1 then
    guiSettings.filter_page = guiSettings.filter_page - 1
    GUI.toggleStationFilterWindow(player.gui.center, guiSettings, player)
    GUI.toggleStationFilterWindow(player.gui.center, guiSettings, player)
  end
end

on_gui_click.alarmOK = function(guiSettings, element, player)
  local gui = player.gui.center
  local station = sanitizeNumber(gui.alarmWindow.flowStation.alarmTimeToStationDuration.text,defaults.stationDuration)*3600
  local signal = sanitizeNumber(gui.alarmWindow.flowSignal.alarmTimeAtSignalDuration.text,defaults.signalDuration)*3600
  global.force_settings[player.force.name] = {signalDuration=signal,stationDuration=station}
  --debugDump(global.force_settings[player.force.name],true)
  GUI.toggleAlarmWindow(player.gui.center, player.index)
end

on_gui_click.alarmButton = function(guiSettings, element, player)
  GUI.toggleAlarmWindow(player.gui.center, player.index)
end

on_gui_click.alarmTimeToStation = function(guiSettings, element, player)
  guiSettings.alarm.timeToStation = element.state
end

on_gui_click.alarmTimeAtSignal = function(guiSettings, element, player)
  guiSettings.alarm.timeAtSignal = element.state
end

on_gui_click.alarmNoPath = function(guiSettings, element, player)
  guiSettings.alarm.noPath = element.state
end

on_gui_click.alarmNoFuel = function(guiSettings, element, player)
  guiSettings.alarm.noFuel = element.state
end

on_gui_click.toggleButton = function(guiSettings, element, player)
  --run/stop the trains
  local trains = guiSettings.activeFilterList and guiSettings.filtered_trains or global.trainsByForce[player.force.name]
  local requested_state = not guiSettings.stopButton_state
  for i, trainInfo in pairs(trains) do
    if trainInfo.train.valid then
      trainInfo.train.manual_mode = requested_state
    end
  end
  guiSettings.stopButton_state = requested_state
  return true
end

on_gui_click.toggleManualMode = function(guiSettings, element, player)
  local trains = global.trainsByForce[player.force.name]
  local option1 = element.name:match("Info(%w+)_")
  option1 = tonumber(option1)
  --debugDump(option1,true)
  local trainInfo = trains[option1]
  if trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid then
    trainInfo.train.manual_mode = not trainInfo.train.manual_mode
    GUI.update_single_traininfo(trainInfo)
  end
end

on_gui_click.toggleFollowMode = function(guiSettings, element, player)
  local trains = global.trainsByForce[player.force.name]
  local option1 = element.name:match("Info(%w+)_")
  option1 = tonumber(option1)
  local trainInfo = trains[option1]
  --local trainInfo = getTrainInfoFromElementName(trains, element.name)
  if not trainInfo or not trainInfo.train or not trainInfo.train.valid then
    return
  end
  local carriage = trainInfo.train.speed >= 0 and trainInfo.train.locomotives.front_movers[1] or trainInfo.train.locomotives.back_movers[1]
  if not carriage then
    carriage = trainInfo.train.carriages[1]
  end

  -- Player is controlling his own character
  if global.character[element.player_index] == nil then
    if carriage.passenger ~= nil then
      player.print({"msg-intrain"})
      return
    end
    global.character[element.player_index] = player.character
    swapPlayer(player,newFatControllerEntity(player))
    start_following(carriage, guiSettings,element,player)
    return
  end
  --return to player
  if guiSettings.followEntity and guiSettings.followEntity.train == trainInfo.train then
    swapPlayer(player, global.character[element.player_index])
    global.character[element.player_index] = nil
    stop_following(guiSettings, player)
    return
  end
  -- switch to another train
  if guiSettings.followEntity then
    if carriage.passenger ~= nil then
      player.print({"msg-intrain"})
      return
    end
    stop_following(guiSettings, player)
    start_following(carriage,guiSettings,element,player)
  end
end

on_gui_click.unsetAlarm = function(guiSettings, element, player)
  local trains = global.trainsByForce[player.force.name]
  local option1 = element.name:match("Info(%w+)_")
  option1 = tonumber(option1)
  local trainInfo = trains[option1]
  if trainInfo and trainInfo.train and trainInfo.train.valid then
    trainInfo.alarm.active = false
    trainInfo.alarm.type = false
    GUI.update_single_traininfo(trainInfo)
  end
end

on_gui_click.stationFilter = function(guiSettings, element, player)
  local stationName = string.gsub(element.name, "_stationFilter", "")
  if element.state then
    if guiSettings.activeFilterList == nil then
      guiSettings.activeFilterList = {}
    end

    guiSettings.activeFilterList[stationName] = true
  elseif guiSettings.activeFilterList ~= nil then
    guiSettings.activeFilterList[stationName] = nil
    if tableIsEmpty(guiSettings.activeFilterList) then
      guiSettings.activeFilterList = nil
    end
  end
  guiSettings.filtered_trains = TrainList.get_filtered_trains(player.force, guiSettings)
  guiSettings.pageCount = getPageCount(guiSettings, player)
  guiSettings.page = 1
  return true
end

on_gui_click.filterAlarms = function(guiSettings, element, player)
  guiSettings.filter_alarms = not guiSettings.filter_alarms
  element.style = guiSettings.filter_alarms and "fatcontroller_selected_button" or "fatcontroller_button_style"
  guiSettings.filtered_trains = TrainList.get_filtered_trains(player.force, guiSettings)
  guiSettings.pageCount = getPageCount(guiSettings, player)
  guiSettings.page = 1
  return true
end

on_gui_click.findCharacter = function(guiSettings, element, player)
  local status, err = pcall(function()
    if player.connected then
      if player.character.name == "fatcontroller" then
        if global.character[player.index] and global.character[player.index].name ~= "fatcontroller" then
          swapPlayer(game.players[player.index], global.character[player.index])
          global.character[player.index] = nil
          if guiSettings.fatControllerButtons ~= nil and guiSettings.fatControllerButtons.returnToPlayer ~= nil then
            guiSettings.fatControllerButtons.returnToPlayer.destroy()
          end
          guiSettings.followEntity = nil
          if guiSettings.followGui and guiSettings.followGui.valid then
            guiSettings.followGui.caption = "c"
            guiSettings.followGui.style = "fatcontroller_button_style"
            guiSettings.followGui = nil
          end
          TrainList.reset_manual(global.gui[player.index].vehicle)
          global.gui[player.index].vehicle = false
        else

        end
      end
    end
  end)
  if err then debugDump(err,true) end
end
