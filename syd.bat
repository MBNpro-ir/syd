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
echo Starting SYD (Smart Update System)...
echo.

REM Create SYD folder if it doesn't exist
if not exist "SYD" mkdir "SYD"

REM Set URLs and file paths
set SCRIPT_URL="https://github.com/MBNpro-ir/syd/releases/latest/download/syd.ps1"
set LOCAL_SCRIPT_NAME="SYD\syd_latest.ps1"
set LOGO_URL="https://github.com/MBNpro-ir/syd/raw/main/logo.ico"
set LOCAL_LOGO_NAME="SYD\logo.ico"
set VERSION_FILE="SYD\version_info.txt"

echo Checking for updates...

REM Smart update check using PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { try { $needsUpdate = $false; $needsShortcut = $false; $scriptDir = '%~dp0'; $logoPath = Join-Path $scriptDir '%LOCAL_LOGO_NAME%'; $shortcutPath = Join-Path $env:USERPROFILE 'Desktop\SYD - YouTube Downloader.lnk'; Write-Host 'Checking script version...' -ForegroundColor Yellow; try { $headers = Invoke-WebRequest -Uri '%SCRIPT_URL%' -Method Head -UseBasicParsing -TimeoutSec 10; $remoteETag = $headers.Headers['ETag'] -replace '\"\"', ''; $remoteSize = $headers.Headers['Content-Length']; $versionFile = Join-Path $scriptDir 'SYD\version_cache.txt'; if (Test-Path '%LOCAL_SCRIPT_NAME%') { $localFile = Get-Item '%LOCAL_SCRIPT_NAME%'; $localSize = $localFile.Length.ToString(); if (Test-Path $versionFile) { $cachedInfo = Get-Content $versionFile -Raw | ConvertFrom-Json; $cachedETag = $cachedInfo.ETag; $cachedSize = $cachedInfo.Size; } else { $cachedETag = ''; $cachedSize = ''; }; if (($remoteETag -ne $cachedETag) -or ($remoteSize -ne $cachedSize) -or ($remoteSize -ne $localSize)) { $needsUpdate = $true; Write-Host 'Script update available!' -ForegroundColor Green } else { Write-Host 'Script is up to date' -ForegroundColor Green } } else { $needsUpdate = $true; Write-Host 'Script not found, will download' -ForegroundColor Yellow } } catch { $needsUpdate = $true; Write-Host 'Cannot check version, will download latest' -ForegroundColor Yellow }; if (-not (Test-Path $shortcutPath)) { $needsShortcut = $true; Write-Host 'Desktop shortcut missing, will create' -ForegroundColor Yellow } elseif (-not (Test-Path $logoPath)) { $needsShortcut = $true; Write-Host 'Logo missing, will download and update shortcut' -ForegroundColor Yellow }; if ($needsUpdate) { Write-Host 'Downloading latest script...' -ForegroundColor Yellow; try { Invoke-WebRequest -Uri '%SCRIPT_URL%' -OutFile '%LOCAL_SCRIPT_NAME%' -UseBasicParsing -TimeoutSec 30; Write-Host 'Script downloaded successfully!' -ForegroundColor Green; $downloadedFile = Get-Item '%LOCAL_SCRIPT_NAME%'; $versionInfo = @{ ETag = $remoteETag; Size = $remoteSize; DownloadDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }; $versionInfo | ConvertTo-Json | Out-File -FilePath $versionFile -Encoding UTF8 } catch { Write-Error 'Script download failed!'; exit 1 } } else { Write-Host 'Using existing script' -ForegroundColor Green }; if ($needsShortcut) { Write-Host 'Setting up desktop shortcut...' -ForegroundColor Yellow; try { Invoke-WebRequest -Uri '%LOGO_URL%' -OutFile $logoPath -UseBasicParsing -TimeoutSec 10; Write-Host 'Logo downloaded successfully!' -ForegroundColor Green } catch { Write-Host 'Could not download logo, using default icon' -ForegroundColor Yellow }; try { $WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut($shortcutPath); $Shortcut.TargetPath = Join-Path $scriptDir 'syd.bat'; $Shortcut.WorkingDirectory = $scriptDir; $Shortcut.Description = 'Simple YouTube Downloader by MBNPRO'; if (Test-Path $logoPath) { $Shortcut.IconLocation = $logoPath } else { $Shortcut.IconLocation = 'shell32.dll,13' }; $Shortcut.Save(); Write-Host 'Desktop shortcut created successfully!' -ForegroundColor Green } catch { Write-Host 'Could not create desktop shortcut' -ForegroundColor Yellow } } else { Write-Host 'Desktop shortcut is up to date' -ForegroundColor Green } } catch { Write-Host 'Update check failed, proceeding with existing files...' -ForegroundColor Red } }"

REM Check if script file exists after update process
if not exist %LOCAL_SCRIPT_NAME% (
    echo Critical Error: Script file not found after update check.
    echo Please check your internet connection and try again.
    pause
    exit /b 1
)

echo.
echo Launching SYD...
echo.

REM Launch the PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File %LOCAL_SCRIPT_NAME%

echo.
echo Script execution finished.
echo Thank you for using Simple YouTube Downloader (SYD)!
echo Visit: https://github.com/MBNpro-ir/syd
echo.
pause
exit