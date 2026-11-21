@echo off
rem Visual smoke test of the game screens (no boards needed).
rem Screenshots -> tests\screenshots\ ; test recordings -> tests\test_data\
cd /d "%~dp0.."
set MOBBO_DATA_DIR=%~dp0test_data
set GODOT=D:\Godot_v4.6.2-stable_win64_console.exe
"%GODOT%" --path . --windowed --resolution 1280x720 res://tests/ui_screenshots.tscn
