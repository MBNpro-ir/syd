@echo off
title Simple YouTube Downloader (SYD) - Auto Launcher
color 0A
cls

echo.
echo ========================================
echo     Simple YouTube Downloader (SYD)
echo            by MBNPRO
echo ========================================
echo.
echo Starting SYD (Auto-downloading latest version)...
echo.

if not exist "SYD" mkdir "SYD"

set SCRIPT_URL="https://github.com/MBNpro-ir/syd/releases/latest/download/syd.ps1"
set LOCAL_SCRIPT_NAME="SYD\syd_latest.ps1"

echo Downloading the latest version of Simple YouTube Downloader (syd.ps1)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri %SCRIPT_URL% -OutFile %LOCAL_SCRIPT_NAME% -UseBasicParsing } catch { Write-Error 'Download failed. Please check your internet connection or the URL.'; exit 1 }"

if not exist %LOCAL_SCRIPT_NAME% (
    echo Download failed. The script %LOCAL_SCRIPT_NAME% was not found.
    echo Please check your internet connection and ensure the URL is correct:
    echo %SCRIPT_URL%
    pause
    exit /b 1
)

echo Download complete. Launching syd.ps1...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File %LOCAL_SCRIPT_NAME%

echo.
echo Script execution finished.
echo Thank you for using Simple YouTube Downloader (SYD)!
echo Visit: https://github.com/MBNpro-ir/syd
echo.
pause
exit