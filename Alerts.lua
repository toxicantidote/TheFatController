--- Alerts
-- @module Alerts

--- Alerts
-- @type Alerts
Alerts = {}
Alerts.set_alert = function(trainInfo, type, time)
  trainInfo.alarm.active = true
  trainInfo.alarm.type = type
  trainInfo.alarm.message = time and ({"msg-alarm-"..type, time}) or {"msg-alarm-"..type}
  Alerts.update_filters()
  if type ~= "noFuel" or trainInfo.alarm.last_message+600 < game.tick then
    Alerts.alert_force(trainInfo.force, trainInfo)
  end
end

Alerts.check_alerts = function(trainInfo)
  local force = trainInfo.force
  local update = false
  if trainInfo.alarm.arrived_at_signal then
    local signalDuration = global.force_settings[force.name].signalDuration
    if trainInfo.last_state == defines.trainstate.wait_signal and trainInfo.alarm.arrived_at_signal == game.tick - signalDuration then
      Alerts.set_alert(trainInfo,"timeAtSignal",signalDuration/3600)
      update = true
    end
  end
  if trainInfo.alarm.left_station then
    local stationDuration = global.force_settings[force.name].stationDuration
    if trainInfo.alarm.left_station+stationDuration <= game.tick then
      Alerts.set_alert(trainInfo,"timeToStation",stationDuration/3600)
      update = true
    end
  end
  return update
end

Alerts.check_noFuel = function(trainInfo)
  local noFuel = false
  local locos = trainInfo.train.locomotives
  for _,carriage in pairs(locos.front_movers) do
    if carriage.get_inventory(1).is_empty() then
      noFuel = true
      break
    end
  end
  if not noFuel then
    for _,carriage in pairs(locos.back_movers) do
      if carriage.get_inventory(1).is_empty() then
        noFuel = true
        break
      end
    end
  end
  if noFuel then
    Alerts.set_alert(trainInfo,"noFuel")
  else
    if trainInfo.alarm.active and trainInfo.alarm.type == "noFuel" then
      trainInfo.alarm.active = false
      trainInfo.alarm.type = false
      Alerts.update_filters()
    end
  end
end

Alerts.reset_alarm = function(trainInfo)
  trainInfo.alarm.active = false
  trainInfo.alarm.type = false
  trainInfo.alarm.left_station = false
  trainInfo.alarm.arrived_at_signal = false
  trainInfo.alarm.last_message = 0
  TickTable.remove_by_train("updateAlarms", trainInfo.train)
  Alerts.update_filters()
end

Alerts.update_filters = function()
  for _, player in pairs(game.players) do
    local guiSettings = global.gui[player.index]
    if guiSettings.filter_alarms then
      guiSettings.filtered_trains = TrainList.get_filtered_trains(player.force, guiSettings)
      guiSettings.pageCount = getPageCount(guiSettings, player)
      guiSettings.page = 1
      if guiSettings.fatControllerGui.trainInfo then
        GUI.newTrainInfoWindow(guiSettings, player)
        GUI.refreshTrainInfoGui(guiSettings, player)
      end
    end
  end
end

Alerts.alert_force = function(force, trainInfo)
  local alarm_type = trainInfo.alarm.type
  for _, player in pairs(force.players) do
    local guiSettings = global.gui[player.index]
    if guiSettings and guiSettings.alarm[alarm_type] then
      player.print(trainInfo.alarm.message)
    end
  end
  trainInfo.alarm.last_message = game.tick
end