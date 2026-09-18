@echo off
title Relapse GMod Dedicated Server
cd /d "D:\Relapse\server"

srcds.exe -console -condebug -game garrysmod -port 27016 -tickrate 33 -maxplayers 90 +maxplayers 90 +gamemode zombiesurvival +map zs_oxygen_b4 +sv_lan 1 +sv_hibernate_drop_bots 0 +sv_hibernate_think 1 +sv_minupdaterate 33 +sv_maxupdaterate 33 +sv_mincmdrate 33 +sv_maxcmdrate 33
