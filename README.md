TheFatController
===========
The Fat Controller allows you to track trains, see their next stop, if they are currently moving and the item in their inventory with the highest count, you are also able to remotely control trains and set their schedule.

If you uninstall this mod, make sure you are out of remote control mode first unless you want to be stuck as a ghost, being a ghost is pretty cool.

Why the name?: [The Fat Controller](http://en.wikipedia.org/wiki/The_Fat_Controller)

How to use
---

Once you have researched Rail Signals a new button will show up. Pressing the button will expand the list.  
![Main UI](https://raw.githubusercontent.com/Choumiko/TheFatController/master/readme_content/TFC_main.png "Main UI")

Instantly you can see whether it is in manual mode and if the train moving, if it is running on a schedule you will see the next stop instead.  
Once the train is stopped the inventory count will update, this will display the name of the item with the highest count and "..." if there are other items in the train.  
The > or || buttons will start and stop the trains schedule and the c (control button) will put you in remote control mode.
The s button lets you filter the displayed trains by the stations in their schedule or by active alarms. The x button clears the filter.
The ! button lets you change the alarms you will be notified of. 


![Remote mode](https://raw.githubusercontent.com/Choumiko/TheFatController/master/readme_content/TFC_remote.png "Remote mode")

In remote control mode your camera will follow the train instead of the player. You should be able to click on the train and set the schedule. Clicking one of the highlighted buttons will return you to the player.

Be warned, if the player is not safe he can die, you can also run him over with the train you are remotely controlling. [i]You have been warned

Videos: [Factorio Mod Spotlight - The Fat Controller 0.0.11](https://youtu.be/zyecAmcbxtM)

#Changelog
3.0.0

 - Updated for Factorio 0.16
 - Temporarily disabled remote controlling trains, needs a Factorio fix first
    
2.0.11

 - fixed error renaming trains
 - fixed no fuel message for electric trains from [Electric Train](https://mods.factorio.com/mods/magu5026/ElectricTrain) and [RailPowerSystem](https://mods.factorio.com/mods/Hermios/RailPowerSystem)

2.0.10

 - fixed station filter showing invalid station names when using copy+paste to rename stations

2.0.9

 - fixed error when trying to switch to a train on a different surface
 - updated czech translation

2.0.8

 - fixed trains waiting at a station not updating the cargo display
 - stop player movement when starting to follow a train

2.0.7

 - fixed error when updating the mod
 - updated russian translation

2.0.6

 - fixed performance when filtering by Alarm with a lot of trains

2.0.5

 - fixed error when trains get their schedule deleted by another mod
 
2.0.4

 - added display of liquids in fluid wagons

2.0.3

 - increased size of the alarm icons
 - potential fix for an error when leaving a train
 - removed support for [Railtanker](https://mods.factorio.com/mods/Choumiko/RailTanker)

2.0.2

 - disabled the ability to follow a train when inside a vehicle, investigating if it's a Factorio bug or not
 - added console command to try and return control to the player: /fat_fix_character

2.0.0

 - version for Factorio 0.15.x

1.0.3

 - update cargo display when leaving a station
 - fixed missing stations in the filter window
 - added a button to the alarm settings to refresh the stations in the filter window
 - added czech translation for tooltips (thanks to EnrichSilen) 
  
1.0.2

 - added tooltips to almost all buttons

 [Full Changelog](https://mods.factorio.com/mods/Choumiko/TheFatController/discussion/11372)
