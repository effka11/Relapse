@echo off
setlocal EnableDelayedExpansion
title Relapse GMod Dedicated Server
set "LOADROOT=%~dp0loading"
set "LOADPORT=27080"
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

rem Loading screen (фы.cpr). Clients fetch it over HTTP before the map download.
netstat -ano | findstr ":%LOADPORT%" | findstr "LISTENING" >nul
if errorlevel 1 (
	start "Relapse loading" /MIN python "%LOADROOT%\serve.py" %LOADPORT%
)
rem The game client refuses loading pages whose host is 192.168, 10, 127 or 172.16.
set "LOADIP="
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /c:"IPv4"') do (
	for /f "tokens=* delims= " %%B in ("%%A") do set "CAND=%%B"
	echo !CAND! | findstr /b /c:"192.168." /c:"10." /c:"127." /c:"172.16." /c:"0." >nul
	if errorlevel 1 set "LOADIP=!CAND!"
)
if not defined LOADIP set "LOADIP=127.0.0.1"
echo Loading screen: http://!LOADIP!:%LOADPORT%/loading.html?12
echo sv_loadingurl "http://!LOADIP!:%LOADPORT%/loading.html?12"> "garrysmod\cfg\relapse_loading.cfg"

srcds.exe -console -condebug -game garrysmod -port 27016 -tickrate 33 -maxplayers 90 +maxplayers 90 +gamemode zombiesurvival +map !MAP! +sv_lan 1 +sv_hibernate_drop_bots 0 +sv_hibernate_think 1 +sv_minupdaterate 33 +sv_maxupdaterate 33 +sv_mincmdrate 33 +sv_maxcmdrate 33 +sv_loadingurl "http://!LOADIP!:%LOADPORT%/loading.html?12"
