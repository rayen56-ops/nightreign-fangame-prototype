@echo off
setlocal
cd /d "%~dp0"
set "GODOT=runtime\Godot.exe"
if exist "%GODOT%" goto have_godot
where godot >nul 2>nul && set "GODOT=godot" && goto have_godot
where godot4 >nul 2>nul && set "GODOT=godot4" && goto have_godot
echo Godot 4.6 was not found. Install Godot 4.6 or place the executable at runtime\Godot.exe.
exit /b 1
:have_godot
"%GODOT%" --headless --editor --import --path . --quit
"%GODOT%" --path . res://tests/phase01.tscn --log-file docs/qa-runtime.log
echo Test result: %errorlevel%
pause
