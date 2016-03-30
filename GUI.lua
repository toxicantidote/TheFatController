function endsWith(String,End)
  return End == '' or string.sub(String,-string.len(End))==End
end

GUI = {

    swapCaption = function(guiElement, captionA, captionB)
      if guiElement ~= nil and captionA ~= nil and captionB ~= nil then
        if guiElement.caption == captionA then
          guiElement.caption = captionB
        elseif guiElement.caption == captionB then
          guiElement.caption = captionA
        end
      end
    end,

    refreshAllTrainInfoGuis = function(trainsByForce, guiSettings, players, destroy)
      for i,player in pairs(players) do
        --local trainInfo = guiSettings[i].fatControllerGui.trainInfo
        if guiSettings[i] ~= nil and guiSettings[i].fatControllerGui.trainInfo ~= nil then
          if destroy then
            guiSettings[i].fatControllerGui.trainInfo.destroy()
            GUI.newTrainInfoWindow(guiSettings[i])
          end
          GUI.refreshTrainInfoGui(trainsByForce[player.force.name], guiSettings[i], player)
        end
      end
    end,

    init_gui = function(player)
      debugLog("Init: " .. player.name .. " - " .. player.force.name)
      if player.gui.top.fatControllerButtons ~= nil then
        return
      end

      local guiSettings = global.guiSettings[player.index]
      local forceName = player.force.name
      guiSettings.stationFilterList = buildStationFilterList(global.trainsByForce[player.force.name])

      debugLog("create guis")
      if player.gui.left.fatController == nil then
        guiSettings.fatControllerGui = player.gui.left.add({ type="flow", name="fatController", direction="vertical"})--, style="fatcontroller_thin_flow"}) --caption="Fat Controller",
      else
        guiSettings.fatControllerGui = player.gui.left.fatController
      end
      if player.gui.top.fatControllerButtons == nil then
        guiSettings.fatControllerButtons = player.gui.top.add({ type="flow", name="fatControllerButtons", direction="horizontal", style="fatcontroller_thin_flow"})
      else
        guiSettings.fatControllerButtons = player.gui.top.fatControllerButtons
      end
      if guiSettings.fatControllerButtons.toggleTrainInfo == nil then
        guiSettings.fatControllerButtons.add({type="button", name="toggleTrainInfo", caption = {"text-trains-collapsed"}, style="fatcontroller_button_style"})
      end

      if guiSettings.fatControllerGui.trainInfo ~= nil then
        GUI.newTrainInfoWindow(guiSettings)
        updateTrains(global.trainsByForce[forceName])
      end

      guiSettings.pageCount = getPageCount(global.trainsByForce[forceName], guiSettings)

      filterTrainInfoList(global.trainsByForce[forceName], guiSettings.activeFilterList)

      updateTrains(global.trainsByForce[forceName])
      GUI.refreshTrainInfoGui(global.trainsByForce[forceName], guiSettings, player)

      return guiSettings
    end,


    onguiclick = function(event)
      local status, err = pcall(function()
        local refreshGui = false
        local rematchStationList = false
        local guiSettings = global.guiSettings[event.element.player_index]
        local player = game.players[event.element.player_index]
        if not player.connected then return end
        local trains = global.trainsByForce[player.force.name]
        debugLog("CLICK! " .. event.element.name .. game.tick)

        if guiSettings.alarm == nil then
          guiSettings.alarm = {}
        end

        if on_gui_click[event.element.name] then
          refreshGui, rematchStationList = GUI.on_gui_click[event.element.name](guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_toggleManualMode") then
          refreshGui, rematchStationList = GUI.on_gui_click.toggleManualMode(guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_toggleFollowMode") then
          refreshGui, rematchStationList = GUI.on_gui_click.toggleFollowMode(guiSettings, event.element, player)
        elseif endsWith(event.element.name,"_stationFilter") then
          refreshGui, rematchStationList = GUI.on_gui_click.stationFilter(guiSettings, event.element, player)
        end

        if rematchStationList then
          filterTrainInfoList(trains, guiSettings.activeFilterList)
          guiSettings.pageCount = getPageCount(trains, guiSettings)
        end

        if refreshGui then
          GUI.newTrainInfoWindow(guiSettings)
          GUI.refreshTrainInfoGui(trains, guiSettings, player)
        end
      end)
      if err then debugDump(err,true) end
    end,

    newTrainInfoWindow = function(guiSettings)

      if guiSettings == nil then
        guiSettings = util.table.deepcopy({ displayCount = 9, page = 1})
      end
      local gui = guiSettings.fatControllerGui
      if gui ~= nil and gui.trainInfo ~= nil then
        gui.trainInfo.destroy()
      end

      local newGui

      if gui ~= nil and gui.trainInfo ~= nil then
        newGui = gui.trainInfo
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

      -- if guiSettings.page > 1 then
      -- newGui.trainInfoControls.pageButtons.page_back.style = "fatcontroller_button_style"
      -- else
      -- newGui.trainInfoControls.pageButtons.page_back.style = "fatcontroller_disabled_button"
      -- end

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

      -- if guiSettings.page < guiSettings.pageCount then
      -- newGui.trainInfoControls.pageButtons.page_forward.style = "fatcontroller_button_style"
      -- else
      -- newGui.trainInfoControls.pageButtons.page_forward.style = "fatcontroller_disabled_button"
      -- end

      if newGui.trainInfoControls.filterButtons == nil then
        newGui.trainInfoControls.add({type = "flow", name="filterButtons",  direction="horizontal", style="fatcontroller_button_flow"})
      end

      if newGui.trainInfoControls.filterButtons.toggleStationFilter == nil then

        if guiSettings.activeFilterList ~= nil then
          newGui.trainInfoControls.filterButtons.add({type="button", name="toggleStationFilter", caption="s", style="fatcontroller_selected_button"})
        else
          newGui.trainInfoControls.filterButtons.add({type="button", name="toggleStationFilter", caption="s", style="fatcontroller_button_style"})
        end
      end

      if newGui.trainInfoControls.filterButtons.clearStationFilter == nil then
        --if guiSettings.activeFilterList ~= nil then
        --newGui.trainInfoControls.filterButtons.add({type="button", name="clearStationFilter", caption="x", style="fatcontroller_selected_button"})
        --else
        newGui.trainInfoControls.filterButtons.add({type="button", name="clearStationFilter", caption="x", style="fatcontroller_button_style"})
        --end
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

    refreshTrainInfoGui = function(trains, guiSettings, player)
      if not player.connected then return end
      local character = player.character
      local gui = guiSettings.fatControllerGui.trainInfo
      guiSettings.pageCount = getPageCount(trains, guiSettings)
      if guiSettings.page > guiSettings.pageCount then guiSettings.page = guiSettings.pageCount end
      if gui ~= nil and trains ~= nil then
        local removeTrainInfo = {}

        local pageStart = ((guiSettings.page - 1) * guiSettings.displayCount) + 1
        debugLog("Page:" .. pageStart)

        local display = 0
        local filteredCount = 0

        for i, trainInfo in pairs(trains) do
          local newGuiName = nil
          if trainInfo.train and trainInfo.train.valid then
            if display < guiSettings.displayCount then
              if guiSettings.activeFilterList == nil or trainInfo.matchesStationFilter then
                filteredCount = filteredCount + 1

                newGuiName = "Info" .. filteredCount
                if filteredCount >= pageStart then
                  --removeGuiFromCount = removeGuiFromCount + 1
                  display = display + 1
                  if trainInfo.updated or gui[newGuiName] == nil then --trainInfo.guiName ~= newGuiName or
                    trainInfo.guiName = newGuiName

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
                      if is_waiting_forever(trainInfo.train) then caption = "ll" end
                      trainGui.buttons[trainInfo.guiName.."_toggleManualMode"].caption = caption
                    end

                    if trainInfo.manualMode then
                      --debugLog("Set >")
                      trainGui.buttons[trainInfo.guiName .. "_toggleManualMode"].caption = ">"
                    else
                      --debugLog("Set ll")
                      trainGui.buttons[trainInfo.guiName .. "_toggleManualMode"].caption = "ll"
                    end


                    if trainGui.buttons[trainInfo.guiName .. "_toggleFollowMode"] == nil then
                      trainGui.buttons.add({type="button", name=trainInfo.guiName .. "_toggleFollowMode", caption={"text-controlbutton"}, style="fatcontroller_button_style"})
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

                    local topString = ""
                    local station = trainInfo.currentStation
                    local waiting_forever = is_waiting_forever(trainInfo.train)
                    if station == nil then station = "" end
                    if trainInfo.lastState ~= nil then
                      if trainInfo.lastState == 1  or trainInfo.lastState == 3 then
                        topString = "No Path "-- .. trainInfo.lastState
                      elseif trainInfo.lastState == 2 then
                        topString = "Stopped"
                      elseif trainInfo.lastState == 5 then
                        topString = "Signal || " .. station
                      elseif (trainInfo.lastState == 8  or trainInfo.lastState == 9   or trainInfo.lastState == 10) and not waiting_forever then
                        topString = "Manual"
                        if trainInfo.speed == 0 then
                          topString = topString .. ": " .. "Stopped" -- REPLACE WITH TRANSLAION
                        else
                          topString = topString .. ": " .. "Moving" -- REPLACE WITH TRANSLAION
                        end
                      elseif trainInfo.lastState == 7 or waiting_forever then
                        topString = "Station || " .. station
                      else
                        topString = "Moving -> " .. station
                      end
                    end

                    local bottomString = ""

                    if trainInfo.inventory ~= nil then
                      bottomString = trainInfo.inventory
                    else
                      bottomString = ""
                    end

                    if guiSettings.alarm ~= nil and trainInfo.alarm then
                      local alarmType = trainInfo.alarmType or ""
                      --topString = "!"..alarmType .. topString
                      topString = "!"..alarmType .. topString
                    end

                    trainGui.info.topInfo.caption = topString
                    trainGui.info.bottomInfo.caption = bottomString
                    if waiting_forever then
                      trainGui.buttons[trainInfo.guiName.."_toggleManualMode"].caption = "ll"
                    end
                  end

                  if character ~= nil and character.name == "fatcontroller" and containsEntity(trainInfo.locomotives, character.vehicle) then
                    gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].style = "fatcontroller_selected_button"
                    gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].caption = "X"
                  else
                    gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].style = "fatcontroller_button_style"
                    gui[newGuiName].buttons[newGuiName .. "_toggleFollowMode"].caption = "c"
                  end

                end
              end
            end
            trainInfo.guiName = newGuiName
          end
        end
      end
    end,

    toggleStationFilterWindow = function(gui, guiSettings)
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
          local pageCount = get_filter_PageCount(guiSettings)
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


          window.add({type="table", name="checkboxGroup", colspan=3})

          local i=0
          local upper = guiSettings.filter_page*global.PAGE_SIZE
          local lower = guiSettings.filter_page*global.PAGE_SIZE-global.PAGE_SIZE
          for name, value in pairsByKeys(guiSettings.stationFilterList) do
            if i>=lower and i<upper then
              if guiSettings.activeFilterList ~= nil and guiSettings.activeFilterList[name] then
                window.checkboxGroup.add({type="checkbox", name=name .. "_stationFilter", caption=name, state=true}) --style="filter_group_button_style"})
              else
                window.checkboxGroup.add({type="checkbox", name=name .. "_stationFilter", caption=name, state=false}) --style="filter_group_button_style"})
              end
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
      local guiSettings = global.guiSettings[player_index]
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

          stationDuration.text = global.force_settings[game.players[player_index].force.name].stationDuration/3600
          signalDuration.text = global.force_settings[game.players[player_index].force.name].signalDuration/3600
        else
          gui.alarmWindow.destroy()
        end
      end
    end,
}

local on_gui_click = {
  toggleTrainInfo = function(guiSettings, element, player)
    if guiSettings.fatControllerGui.trainInfo == nil then
      element.caption = {"text-trains"}
      --return refreshGui
      return true
    else
      guiSettings.fatControllerGui.trainInfo.destroy()
      element.caption = {"text-trains-collapsed"}
      return false
    end
  end,

  returnToPlayer = function(guiSettings, element, player)
    if global.character[element.player_index] ~= nil then
      if player.vehicle ~= nil then
        player.vehicle.passenger = nil
      end
      swapPlayer(player, global.character[element.player_index])
      global.character[element.player_index] = nil
      element.destroy()
      guiSettings.followEntity = nil
    end
  end,

  page_back = function(guiSettings, element, player)
    if guiSettings.page > 1 then
      guiSettings.page = guiSettings.page - 1
      return true
    end
  end,

  page_forward = function(guiSettings, element, player)
    local trains = global.trainsByForce[player.force.name]
    if guiSettings.page < getPageCount(trains, guiSettings) then
      guiSettings.page = guiSettings.page + 1
      return true
    end
  end,

  page_number = function(guiSettings, element, player)
    GUI.togglePageSelectWindow(player.gui.center, guiSettings)
  end,

  pageSelectOK = function(guiSettings, element, player)
    local gui = player.gui.center.pageSelect
    local trains = global.trainsByForce[player.force.name]
    if gui ~= nil then
      local newInt = tonumber(gui.pageSelectValue.text)
      if newInt then
        if newInt < 1 then
          newInt = 1
        elseif newInt > 50 then
          newInt = 50
        end
        guiSettings.displayCount = newInt
        guiSettings.pageCount = getPageCount(trains, guiSettings)
        guiSettings.page = 1
        return true
      else
        player.print({"msg-notanumber"})
      end
      gui.destroy()
    end
  end,

  toggleStationFilter = function(guiSettings, element, player)
    local trains = global.trainsByForce[player.force.name]
    guiSettings.stationFilterList = buildStationFilterList(trains)
    GUI.toggleStationFilterWindow(player.gui.center, guiSettings)
  end,

  stationFilterClear = function(guiSettings, element, player)
    local refresh, rematch = false,false
    if guiSettings.activeFilterList ~= nil then
      guiSettings.activeFilterList = nil

      rematch = true
      refresh = true
    end
    if player.gui.center.stationFilterWindow ~= nil then
      player.gui.center.stationFilterWindow.destroy()
    end
    return refresh,rematch
  end,

  clearStationFilter = function(guiSettings, element, player)
    return on_gui_click.stationFilterClear()
  end,

  stationFilterOK = function(guiSettings, element, player)
    local gui = player.gui.center.stationFilterWindow
    if gui ~= nil and gui.checkboxGroup ~= nil then
      local newFilter = {}
      local listEmpty = true
      for station,value in pairs(guiSettings.stationFilterList) do
        local checkboxA = gui.checkboxGroup[station .. "_stationFilter"]
        if checkboxA ~= nil and checkboxA.state then
          listEmpty = false
          --debugLog(station)
          newFilter[station] = true
        end
      end
      if not listEmpty then
        guiSettings.activeFilterList = newFilter

        --glo.filteredTrains = buildFilteredTrainInfoList(global.trains, global.guiSettings.activeFilterList)
      else
        guiSettings.activeFilterList = nil
      end

      gui.destroy()
      guiSettings.page = 1
      return true,true
    end
  end,

  filter_page_forward = function(guiSettings, element, player)
    if guiSettings.filter_page < get_filter_PageCount(guiSettings) then
      guiSettings.filter_page = guiSettings.filter_page + 1
      GUI.toggleStationFilterWindow(player.gui.center, guiSettings)
      GUI.toggleStationFilterWindow(player.gui.center, guiSettings)
    end
  end,

  filter_page_back = function(guiSettings, element, player)
    if guiSettings.filter_page > 1 then
      guiSettings.filter_page = guiSettings.filter_page - 1
      GUI.toggleStationFilterWindow(player.gui.center, guiSettings)
      GUI.toggleStationFilterWindow(player.gui.center, guiSettings)
    end
  end,

  alarmOK = function(guiSettings, element, player)
    local gui = player.gui.center
    local station = sanitizeNumber(gui.alarmWindow.flowStation.alarmTimeToStationDuration.text,defaults.stationDuration)*3600
    local signal = sanitizeNumber(gui.alarmWindow.flowSignal.alarmTimeAtSignalDuration.text,defaults.signalDuration)*3600
    global.force_settings[player.force.name] = {signalDuration=signal,stationDuration=station}
    --debugDump(global.force_settings[player.force.name],true)
    GUI.toggleAlarmWindow(player.gui.center, player.index)
  end,

  alarmButton = function(guiSettings, element, player)
    GUI.toggleAlarmWindow(player.gui.center, player.index)
  end,

  alarmTimeToStation = function(guiSettings, element, player)
    guiSettings.alarm.timeToStation = element.state
  end,

  alarmTimeAtSignal = function(guiSettings, element, player)
    guiSettings.alarm.timeAtSignal = element.state
  end,

  alarmNoPath = function(guiSettings, element, player)
    guiSettings.alarm.noPath = element.state
  end,

  alarmNoFuel = function(guiSettings, element, player)
    guiSettings.alarm.noFuel = element.state
  end,

  toggleButton = function(guiSettings, element, player)
    --run/stop the trains
    local requested_state = not guiSettings.stopButton_state
    local smart_trains_installed = remote.interfaces.st and remote.interfaces.st.set_train_mode
    if guiSettings.activeFilterList then
      for i, trainInfo in pairs(global.trainsByForce[player.force.name]) do
        if trainInfo.matchesStationFilter and trainInfo.train.valid then
          if smart_trains_installed and requested_state then
            remote.call("st", "set_train_mode", trainInfo.train, requested_state)
          end
          trainInfo.train.manual_mode = requested_state
        end
      end
    else
      for i, trainInfo in pairs(global.trainsByForce[player.force.name]) do
        if trainInfo.train.valid then
          if smart_trains_installed and requested_state then
            remote.call("st", "set_train_mode", trainInfo.train, requested_state)
          end
          trainInfo.train.manual_mode = requested_state
        end
      end
    end
    guiSettings.stopButton_state = requested_state
    return true
  end,

  toggleManualMode = function(guiSettings, element, player)
    local trainInfo = getTrainInfoFromElementName(trains, event.element.name)
    if trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid then
      local smart_trains_installed = remote.interfaces.st and remote.interfaces.st.set_train_mode
      if not smart_trains_installed or (smart_trains_installed and not is_waiting_forever(trainInfo.train)) then
        trainInfo.train.manual_mode = not trainInfo.train.manual_mode
        GUI.swapCaption(event.element, "ll", ">")
      else
        if is_waiting_forever(trainInfo.train) then
          --stop train (it's waiting forever -> considered running)
          remote.call("st", "set_train_mode", trainInfo.train, true)
        end
      end
    end
  end,

  toggleFollowMode = function(guiSettings, element, player)
    local trainInfo = getTrainInfoFromElementName(trains, event.element.name)
    if trainInfo ~= nil and trainInfo.train ~= nil and trainInfo.train.valid then
      local carriage = trainInfo.train.speed >= 0 and trainInfo.train.locomotives.front_movers[1] or trainInfo.train.locomotives.back_movers[1]
      if global.character[event.element.player_index] == nil then --Move to train
        if carriage.passenger ~= nil then
          player.print({"msg-intrain"})
      else
        global.character[event.element.player_index] = player.character
        guiSettings.followEntity = carriage -- HERE

        --fatControllerEntity =
        swapPlayer(player,newFatControllerEntity(player))
        --event.element.style = "fatcontroller_selected_button"
        event.element.caption = "X"
        carriage.passenger = player.character
      end
      elseif guiSettings.followEntity ~= nil and trainInfo.train ~= nil and trainInfo.train.valid then
        if player.vehicle ~= nil then
          player.vehicle.passenger = nil
        end
        if guiSettings.followEntity.train == trainInfo.train then --Go back to player
          swapPlayer(player, global.character[event.element.player_index])
          --event.element.style = "fatcontroller_button_style"
          event.element.caption = "c"
          if guiSettings.fatControllerButtons ~= nil and guiSettings.fatControllerButtons.returnToPlayer ~= nil then
            guiSettings.fatControllerButtons.returnToPlayer.destroy()
          end
          global.character[event.element.player_index] = nil
          guiSettings.followEntity = nil
        else -- Go to different train

          guiSettings.followEntity = carriage -- AND HERE
          --event.element.style = "fatcontroller_selected_button"
          event.element.caption = "X"

          carriage.passenger = player.character
        end
      end

    end
  end,

  stationFilter = function(guiSettings, element, player)
    local stationName = string.gsub(event.element.name, "_stationFilter", "")
    if event.element.state then
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
    --debugLog(event.element.name)
    guiSettings.page = 1
    return true, true
  end,
}
