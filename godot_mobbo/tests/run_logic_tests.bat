@echo off
rem Game-logic regression tests (headless, no boards needed).
rem Test recordings -> tests\test_data\ ; exit code = number of failures.
cd /d "%~dp0.."
set MOBBO_DATA_DIR=%~dp0test_data
set GODOT=D:\Godot_v4.6.2-stable_win64_console.exe
"%GODOT%" --headless --path . res://tests/logic_tests.tscn
exit /b %ERRORLEVEL%
