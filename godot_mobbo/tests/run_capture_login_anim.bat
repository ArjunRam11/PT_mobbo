@echo off
rem Records the main-screen animation and builds tests\screenshots\login_animation.gif
cd /d "%~dp0.."
set MOBBO_DATA_DIR=%~dp0test_data
set GODOT=D:\Godot_v4.6.2-stable_win64_console.exe
"%GODOT%" --path . --windowed --resolution 1280x720 res://tests/capture_login_anim.tscn
python tools\make_gif.py tests\screenshots\login_anim tests\screenshots\login_animation.gif 10
