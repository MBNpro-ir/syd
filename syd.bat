@echo off
title Simple YouTube Downloader (SYD) - Menu
color 0A
cls

:MENU
echo.
echo ========================================
echo     Simple YouTube Downloader (SYD)
echo            by MBNPRO
echo ========================================
echo.
echo Choose an option:
echo.
echo 1. Run SYD (Download latest version and launch)
echo 2. Exit
echo.
set /p choice=Enter your choice (1-2): 

if "%choice%"=="1" goto DOWNLOAD_RUN
if "%choice%"=="2" goto EXIT
echo Invalid choice! Please enter 1 or 2.
pause
goto MENU

:DOWNLOAD_RUN
cls
echo.
echo ========================================
echo     Downloading Latest SYD Version
echo ========================================
echo.
set SCRIPT_URL="https://github.com/MBNpro-ir/syd/releases/latest/download/syd.ps1"
set LOCAL_SCRIPT_NAME="syd_latest.ps1"

echo Downloading the latest version of Simple YouTube Downloader (syd.ps1)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri %SCRIPT_URL% -OutFile %LOCAL_SCRIPT_NAME% -UseBasicParsing } catch { Write-Error 'Download failed. Please check your internet connection or the URL.'; exit 1 }"

if not exist %LOCAL_SCRIPT_NAME% (
    echo Download failed. The script %LOCAL_SCRIPT_NAME% was not found.
    echo Please check your internet connection and ensure the URL is correct:
    echo %SCRIPT_URL%
    pause
    goto MENU
)

echo Download complete. Launching syd.ps1...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File %LOCAL_SCRIPT_NAME%

echo.
echo Script execution finished.
pause
goto MENU

:EXIT
cls
echo.
echo Thank you for using Simple YouTube Downloader (SYD)!
echo Visit: https://github.com/MBNpro-ir/syd
echo.
pause
exit