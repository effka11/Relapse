@echo off
title Relapse GMod Dedicated Server
cd /d "D:\Relapse\server"

srcds.exe -console -condebug -game garrysmod -port 27016 -tickrate 66 -maxplayers 90 +maxplayers 90 +gamemode zombiesurvival +map zs_hades3 +sv_lan 1 +sv_hibernate_drop_bots 0 +sv_hibernate_think 1
