@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\weekly_report.ps1"
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%
