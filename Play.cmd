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
if not exist ".godot\global_script_class_cache.cfg" (
  echo Preparing game assets for first launch...
  "%GODOT%" --headless --editor --import --path . --quit --log-file "docs\first-launch.log"
  if errorlevel 1 exit /b 1
)
start "" "%GODOT%" --path . %*
