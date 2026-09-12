@echo off
setlocal EnableDelayedExpansion
rem Relapse AI: build navmeshes for a list of maps on an empty dedicated server.
rem Usage: nav_build.bat [map1 map2 ...]   (defaults to zs_hades3)
rem The gamemode (relapse_ai_nav_autogen, default 1) generates the navmesh when the
rem server starts empty on a map without one; the engine writes garrysmod\maps\<map>.nav
rem and reloads the map, then this script stops srcds and moves on.
rem Note: +relapse_ai_* on the srcds command line is ignored (the ConVars are created
rem later by Lua) - use cfg\server.cfg for them.

set "SERVER=D:\Relapse\server"
set "PORT=27016"
set "MAXWAIT_MIN=120"

set "MAPS=%*"
if "%MAPS%"=="" set "MAPS=zs_hades3"

tasklist /FI "IMAGENAME eq srcds.exe" 2>nul | find /I "srcds.exe" >nul
if not errorlevel 1 (
	echo [nav_build] srcds.exe is already running - stop the server first.
	exit /b 1
)

for %%M in (%MAPS%) do call :build %%M
echo [nav_build] done.
exit /b 0

:build
set "MAP=%~1"
set "NAV=%SERVER%\garrysmod\maps\%MAP%.nav"
if exist "%NAV%" (
	echo [nav_build] %MAP%.nav already exists, skipping
	exit /b 0
)
if not exist "%SERVER%\garrysmod\maps\%MAP%.bsp" (
	echo [nav_build] %MAP%.bsp not found in %SERVER%\garrysmod\maps, skipping
	exit /b 0
)

echo [nav_build] generating navmesh for %MAP% (zs_hades3 takes about a minute; big maps take longer)...
pushd "%SERVER%"
start "relapse_nav_%MAP%" /B srcds.exe -console -condebug -game garrysmod -port %PORT% -tickrate 66 -maxplayers 8 +maxplayers 8 +gamemode zombiesurvival +sv_lan 1 +sv_hibernate_think 1 +map %MAP%
popd

set /a waited=0
:wait
timeout /t 15 /nobreak >nul
set /a waited+=1
if exist "%NAV%" goto :found
if !waited! GEQ %MAXWAIT_MIN%*4 (
	echo [nav_build] timeout waiting for %MAP%.nav
	goto :stop
)
goto :wait

:found
echo [nav_build] %MAP%.nav written, letting the engine finish saving and reloading...
timeout /t 20 /nobreak >nul

:stop
taskkill /IM srcds.exe /F >nul 2>&1
timeout /t 5 /nobreak >nul
exit /b 0
