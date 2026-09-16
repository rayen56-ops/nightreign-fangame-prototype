@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tests\run_t0_qa.ps1"
exit /b %errorlevel%
