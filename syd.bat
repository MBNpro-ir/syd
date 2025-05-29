@echo off
set SCRIPT_URL="https://github.com/MBNpro-ir/syd/releases/latest/download/syd.ps1"
set LOCAL_SCRIPT_NAME="syd_latest.ps1"

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
echo Script execution finished. Press any key to close this window.
pause