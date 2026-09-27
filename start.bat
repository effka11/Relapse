@echo off
setlocal EnableDelayedExpansion
title Relapse GMod Dedicated Server
cd /d "D:\Relapse\server"

rem First map is a random installed entry from GM.MapVotePool.
set n=0
for /f "tokens=3 delims== " %%A in ('findstr /c:"{ Map = " "garrysmod\gamemodes\zombiesurvival\gamemode\sh_mapvote.lua"') do (
	if exist "garrysmod\maps\%%~A.bsp" (
		set /a n+=1
		set "map!n!=%%~A"
	)
)
if !n! lss 1 (
	echo Pool maps are not on disk. Starting zs_oxygen_b4.
	set "MAP=zs_oxygen_b4"
) else (
	set /a pick=!random! %% !n! + 1
	call set "MAP=%%map!pick!%%"
)
echo Starting map: !MAP!

srcds.exe -console -condebug -game garrysmod -port 27016 -tickrate 33 -maxplayers 90 +maxplayers 90 +gamemode zombiesurvival +map !MAP! +sv_lan 1 +sv_hibernate_drop_bots 0 +sv_hibernate_think 1 +sv_minupdaterate 33 +sv_maxupdaterate 33 +sv_mincmdrate 33 +sv_maxcmdrate 33
