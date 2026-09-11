@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0admin_dashboard\scripts\stop-dashboard.ps1"
if errorlevel 1 pause
