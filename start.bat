@echo off
title Relapse GMod Dedicated Server
cd /d "D:\Relapse\server"

srcds.exe -console -condebug -game garrysmod -port 27016 -tickrate 66 +maxplayers 16 +gamemode zombiesurvival +map gm_construct +sv_lan 1
