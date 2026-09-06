@echo off
setlocal
cd /d "%~dp0"
title USB User Backup and Restore

where powershell >nul 2>&1
if errorlevel 1 (
    echo PowerShell is required.
    pause
    exit /b 1
)

if "%~1"=="" (
    start "" powershell.exe -STA -WindowStyle Hidden -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0UserBackup.ps1" -Mode Gui
    exit /b 0
)

powershell.exe -STA -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0UserBackup.ps1" %*
set ERR=%ERRORLEVEL%
echo.
if not "%ERR%"=="0" (
    echo Script exited with code %ERR%.
)
pause
endlocal
