@echo off
rem Lune (SpriteDemo) - Rojo server. Port 34872 (set in default.project.json).
rem Connects only to the Studio place 96192775933291 (servePlaceIds).
cd /d "%~dp0"
title Rojo - Lune (SpriteDemo) - port 34872
rojo.exe serve
pause
