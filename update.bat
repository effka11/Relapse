@echo off
title Relapse GMod Server Update
cd /d "D:\Relapse\steamcmd"
steamcmd.exe +force_install_dir "D:\Relapse\server" +login anonymous +app_update 4020 validate +quit
pause
