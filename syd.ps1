param (
    [Alias('h')]
    [switch]$Help
)

# --- Script Wide Settings ---
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load required .NET assemblies
Add-Type -AssemblyName System.Web

$scriptDir = $PSScriptRoot
$settingsPath = Join-Path $scriptDir "settings.json"
$settings = $null
$DebugLogPath = Join-Path $scriptDir "debug.txt"

$originalBackground = $Host.UI.RawUI.BackgroundColor
$originalForeground = $Host.UI.RawUI.ForegroundColor

# --- Enhanced Error Handling Functions ---

function Get-DetailedErrorMessage {
    param (
        [string]$ErrorMessage,
        [string]$ExitCode = ""
    )
    
    $detailedMessage = ""
    $solution = @()
    
    switch -Regex ($ErrorMessage) {
        "HTTP Error 403.*Forbidden" {
            $detailedMessage = "ACCESS DENIED - The video server rejected the download request"
            $solution = @(
                "• Try using cookies from your browser",
                "• Check if video is age-restricted or region-blocked", 
                "• Video might be private or members-only",
                "• Try using a VPN if region-blocked"
            )
        }
        "HTTP Error 429.*Too Many Requests" {
            $detailedMessage = "RATE LIMITED - Too many requests sent to server"
            $solution = @(
                "• Wait 15-30 minutes before trying again",
                "• Use a different IP address or VPN",
                "• Try downloading at a different time"
            )
        }
        "HTTP Error 404.*Not Found" {
            $detailedMessage = "VIDEO NOT FOUND - The video no longer exists or URL is incorrect"
            $solution = @(
                "• Check if the video URL is correct",
                "• Video might have been deleted or made private",
                "• Try accessing the video in browser first"
            )
        }
        "SSL.*CERTIFICATE_VERIFY_FAILED" {
            $detailedMessage = "SSL CERTIFICATE ERROR - Cannot verify website security certificate"
            $solution = @(
                "• Your system clock might be incorrect",
                "• Antivirus software might be interfering",
                "• Update your system certificates"
            )
        }
        "sign in to confirm your age" {
            $detailedMessage = "AGE-RESTRICTED CONTENT - Video requires age verification"
            $solution = @(
                "• Use cookies from a logged-in browser session",
                "• Log in to YouTube in your browser first",
                "• Export cookies.txt file from your browser"
            )
        }
        "URLError.*timed out|timeout" {
            $detailedMessage = "NETWORK TIMEOUT - Connection to server timed out"
            $solution = @(
                "• Check your internet connection",
                "• Try using a VPN or proxy",
                "• Try again later when network is stable"
            )
        }
        "Unknown encoder" {
            $detailedMessage = "MISSING CODEC - FFmpeg doesn't support the requested encoder"
            $solution = @(
                "• Install a complete ffmpeg build with all codecs",
                "• Download ffmpeg from official sources",
                "• Use a different output format"
            )
        }
        "Permission denied|Access denied" {
            $detailedMessage = "ACCESS DENIED - Insufficient permissions to write files"
            $solution = @(
                "• Run as administrator",
                "• Check folder permissions",
                "• Choose a different download location"
            )
        }
        "No space left on device|Disk full" {
            $detailedMessage = "DISK FULL - Insufficient storage space"
            $solution = @(
                "• Free up disk space",
                "• Choose a different download location",
                "• Download smaller quality video"
            )
        }
        "FileNotFoundError.*ffmpeg" {
            $detailedMessage = "FFMPEG NOT FOUND - FFmpeg executable is missing"
            $solution = @(
                "• Install ffmpeg from official website",
                "• Add ffmpeg to system PATH",
                "• Place ffmpeg.exe in script directory"
            )
        }
        "JSON.*decode.*error|Invalid.*JSON" {
            $detailedMessage = "DATA PARSING ERROR - Cannot parse video information"
            $solution = @(
                "• Try clearing cache and retry",
                "• Update yt-dlp to latest version",
                "• Video site might have changed format"
            )
        }
        default {
            $detailedMessage = "UNKNOWN ERROR - An unexpected error occurred"
            $solution = @(
                "• Check debug.txt for detailed error information",
                "• Try updating yt-dlp and ffmpeg to latest versions",
                "• Try with a different video URL"
            )
        }
    }
    
    return @{
        DetailedMessage = $detailedMessage
        Solutions = $solution
        ExitCode = $ExitCode
    }
}

function Show-EnhancedError {
    param (
        [string]$TechnicalError,
        [string]$ExitCode = "",
        [string]$Context = ""
    )
    
    $errorInfo = Get-DetailedErrorMessage -ErrorMessage $TechnicalError -ExitCode $ExitCode
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                    ERROR DETECTED                              ║" -ForegroundColor Red  
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "🔍 ERROR TYPE:" -ForegroundColor Yellow
    Write-Host "   $($errorInfo.DetailedMessage)" -ForegroundColor Red
    Write-Host ""
    
    if ($Context) {
        Write-Host "📍 CONTEXT:" -ForegroundColor Yellow
        Write-Host "   $Context" -ForegroundColor White
        Write-Host ""
    }
    
    if ($ExitCode) {
        Write-Host "🔢 EXIT CODE:" -ForegroundColor Yellow
        Write-Host "   $ExitCode" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "💡 POSSIBLE SOLUTIONS:" -ForegroundColor Green
    foreach ($solution in $errorInfo.Solutions) {
        Write-Host "   $solution" -ForegroundColor White
    }
    Write-Host ""
    
    Write-Host "📋 TECHNICAL DETAILS:" -ForegroundColor Yellow
    Write-Host "   $TechnicalError" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "🔗 NEED HELP?" -ForegroundColor Cyan
    Write-Host "   Send debug.txt and description to: https://t.me/mbnproo" -ForegroundColor White
    Write-Host ""
    
    Write-ErrorLog "Enhanced Error: $($errorInfo.DetailedMessage) | Technical: $TechnicalError | Exit Code: $ExitCode"
}

function Get-ValidatedUserInput {
    param (
        [string]$Prompt,
        [string]$InputType = "text", # text, yesno, number, url, choice
        [array]$ValidChoices = @(),
        [int]$MinValue = 0,
        [int]$MaxValue = 0,
        [int]$MaxAttempts = 3
    )
    
    $attempts = 0
    
    while ($attempts -lt $MaxAttempts) {
        $attempts++
        
        if ($attempts -gt 1) {
            Write-Host ""
            Write-Host "⚠️  Invalid input. Please try again. (Attempt $attempts of $MaxAttempts)" -ForegroundColor Yellow
        }
        
        Write-Host $Prompt -NoNewline -ForegroundColor Green
        $userInput = Read-Host " "
        
        # Validate based on input type
        switch ($InputType) {
            "yesno" {
                if ($userInput -match "^[yYnN]$" -or $userInput.ToLower() -in @("yes", "no", "y", "n")) {
                    return $userInput.ToLower()[0]
                }
                Write-Host "Please enter Y (yes) or N (no)" -ForegroundColor Red
            }
            
            "number" {
                if ($userInput -match "^\d+$") {
                    $number = [int]$userInput
                    if ($MaxValue -gt 0 -and ($number -lt $MinValue -or $number -gt $MaxValue)) {
                        Write-Host "Please enter a number between $MinValue and $MaxValue" -ForegroundColor Red
                    } else {
                        return $number
                    }
                } else {
                    Write-Host "Please enter a valid number" -ForegroundColor Red
                }
            }
            
            "url" {
                if ($userInput -match "^https?://.*youtube\.com/watch\?.*v=.*" -or 
                    $userInput -match "^https?://youtu\.be/.*" -or
                    $userInput -match "^https?://.*youtube\.com/.*" -or
                    $userInput -in @("help", "-h", "exit", "clear-cache")) {
                    return $userInput
                }
                Write-Host "Please enter a valid YouTube URL or command (help, exit, clear-cache)" -ForegroundColor Red
            }
            
            "choice" {
                if ($userInput -in $ValidChoices) {
                    return $userInput
                }
                Write-Host "Please choose from: $($ValidChoices -join ', ')" -ForegroundColor Red
            }
            
            "text" {
                if (![string]::IsNullOrWhiteSpace($userInput)) {
                    return $userInput
                }
                Write-Host "Please enter a valid response" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "❌ Maximum attempts reached. Using default or exiting..." -ForegroundColor Red
    return $null
}

# --- Function Definitions ---

function Load-Settings {
    $defaultSettings = Get-DefaultSettings
    
    if (Test-Path $settingsPath) {
        try {
            $fileSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            
            # Merge file settings with default settings
            $global:settings = @{
                general = if ($fileSettings.general) { $fileSettings.general } else { $defaultSettings.general }
                proxy = if ($fileSettings.proxy) { $fileSettings.proxy } else { $defaultSettings.proxy }
                cookies = if ($fileSettings.cookies) { $fileSettings.cookies } else { $defaultSettings.cookies }
                youtube_login = if ($fileSettings.youtube_login) { $fileSettings.youtube_login } else { $defaultSettings.youtube_login }
                download = if ($fileSettings.download) { $fileSettings.download } else { $defaultSettings.download }
                advanced = if ($fileSettings.advanced) { $fileSettings.advanced } else { $defaultSettings.advanced }
            }
            
            Write-Host "Settings loaded from $settingsPath" -ForegroundColor Green
            Write-ErrorLog "Settings loaded successfully from $settingsPath"
        } catch {
            Write-Warning "Failed to load settings from $settingsPath. Using default settings."
            Write-ErrorLog "Failed to load settings: $($_.Exception.Message)"
            $global:settings = $defaultSettings
        }
    } else {
        Write-Warning "Settings file not found. Creating new settings file..."
        Write-ErrorLog "Settings file not found, creating new one"
        
        # Create settings file
        if (Create-SettingsFile -Path $settingsPath) {
            Write-Host "Created new settings file with default values." -ForegroundColor Green
        } else {
            Write-Warning "Could not create settings file. Using default settings in memory."
        }
        
        $global:settings = $defaultSettings
    }
}

function Get-DefaultSettings {
    return @{
        general = @{
            request_timeout_seconds = 20
            max_retries = 3
            show_processing_messages = $true
            use_database_cache = $true
            database_file = "video_cache.json"
        }
        proxy = @{
            use_system_proxy = $true
            custom_proxy_enabled = $false
            custom_proxy_host = ""
            custom_proxy_port = ""
            custom_proxy_username = ""
            custom_proxy_password = ""
        }
        cookies = @{
            use_cookies = $true
            cookie_file_path = "cookies.txt"
            cookie_file_directory = ""
        }
        youtube_login = @{
            enable_auto_login = $true
            chrome_profile_path = ""
            login_timeout_seconds = 60
        }
        download = @{
            temp_directory = "Temp"
            output_directory = "Downloaded"
            video_subdirectory = "Video"
            audio_subdirectory = "Audio"
            covers_subdirectory = "Covers"
        }
        advanced = @{
            enable_debug_logging = $true
            log_file_path = "debug.txt"
            cleanup_temp_files = $true
            max_description_lines = 5
        }

    }
}

function Create-SettingsFile {
    param ([string]$Path = $settingsPath)
    
    try {
        $defaultSettings = Get-DefaultSettings
        # Save settings file without messages
        $settingsToSave = @{
            general = $defaultSettings.general
            proxy = $defaultSettings.proxy
            cookies = $defaultSettings.cookies
            youtube_login = $defaultSettings.youtube_login
            download = $defaultSettings.download
            advanced = $defaultSettings.advanced
        }
        
        $settingsToSave | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
        Write-Host "Settings file created successfully at: $Path" -ForegroundColor Green
        Write-ErrorLog "Settings file created at: $Path"
        return $true
    } catch {
        Write-Warning "Failed to create settings file: $($_.Exception.Message)"
        Write-ErrorLog "Failed to create settings file: $($_.Exception.Message)"
        return $false
    }
}

function Get-SystemProxy {
    try {
        $proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
        if ($proxySettings -and $proxySettings.ProxyEnable -eq 1 -and $proxySettings.ProxyServer) {
            Write-Host "System proxy detected: $($proxySettings.ProxyServer)" -ForegroundColor Yellow
            Write-ErrorLog "System proxy detected: $($proxySettings.ProxyServer)"
            return $proxySettings.ProxyServer
        }
    } catch {
        Write-ErrorLog "Failed to get system proxy settings: $($_.Exception.Message)"
    }
    return $null
}

function Set-ProxyConfiguration {
    $systemProxy = $null
    if ([bool]$settings.proxy.use_system_proxy) {
        $systemProxy = Get-SystemProxy
    }
    
    if ($systemProxy) {
        $env:HTTP_PROXY = "http://$systemProxy"
        $env:HTTPS_PROXY = "http://$systemProxy"
        Write-Host "Using system proxy: $systemProxy" -ForegroundColor Green
        Write-ErrorLog "Proxy configuration set to system proxy: $systemProxy"
    } elseif ([bool]$settings.proxy.custom_proxy_enabled -and $settings.proxy.custom_proxy_host -and $settings.proxy.custom_proxy_port) {
        $customProxy = "$($settings.proxy.custom_proxy_host):$($settings.proxy.custom_proxy_port)"
        $env:HTTP_PROXY = "http://$customProxy"
        $env:HTTPS_PROXY = "http://$customProxy"
        Write-Host "Using custom proxy: $customProxy" -ForegroundColor Green
        Write-ErrorLog "Proxy configuration set to custom proxy: $customProxy"
    } else {
        Write-Host "No proxy configuration detected or enabled" -ForegroundColor Gray
        Write-ErrorLog "No proxy configuration applied"
    }
}

function Initialize-Database {
    $dbPath = Join-Path $scriptDir $settings.general.database_file
    if (-not (Test-Path $dbPath)) {
        try {
            $emptyDb = @{ videos = @() }
            $emptyDb | ConvertTo-Json -Depth 10 | Out-File -FilePath $dbPath -Encoding UTF8
            Write-Host "Database initialized at $dbPath" -ForegroundColor Green
            Write-ErrorLog "Database initialized at $dbPath"
        } catch {
            Write-Warning "Failed to initialize database: $($_.Exception.Message)"
            Write-ErrorLog "Failed to initialize database: $($_.Exception.Message)"
        }
    }
}

function Clear-VideoCache {
    param ([switch]$Force)
    
    $dbPath = Join-Path $scriptDir $settings.general.database_file
    if (-not (Test-Path $dbPath)) {
        Write-Host ""
        Write-Host "⚠️  No cache file found." -ForegroundColor Yellow
        return
    }
    
    if (-not $Force) {
        $confirm = Get-ValidatedUserInput -Prompt "⚠️ Clear all cached video information? (y/n):" -InputType "yesno" -MaxAttempts 3
        if ($confirm -eq 'n' -or $null -eq $confirm) {
            Write-Host ""
            Write-Host "❌ Cache clear cancelled." -ForegroundColor Red
            return
        }
    }
    
    try {
        $db = @{ videos = @() }
        $db | ConvertTo-Json -Depth 10 | Out-File -FilePath $dbPath -Encoding UTF8
        Write-Host ""
        Write-Host "✅ Video cache cleared successfully!" -ForegroundColor Green
        Write-ErrorLog "Video cache cleared by user"
    } catch {
        Write-Host ""
        Write-Host "❌ Failed to clear cache: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Failed to clear cache: $($_.Exception.Message)"
    }
}

function Get-VideoFromCache {
    param ([string]$Url)
    
    if (-not [bool]$settings.general.use_database_cache) {
        return $null
    }
    
    $dbPath = Join-Path $scriptDir $settings.general.database_file
    if (-not (Test-Path $dbPath)) {
        return $null
    }
    
    try {
        $db = Get-Content $dbPath -Raw | ConvertFrom-Json
        $cachedEntry = $db.videos | Where-Object { $_.url -eq $Url }
        if ($cachedEntry) {
            # Validate cached entry has required fields
            if ($cachedEntry.info -and $cachedEntry.info.title -and $cachedEntry.info.formats) {
                Write-Host "Video information found in cache" -ForegroundColor Green
                Write-ErrorLog "Video retrieved from cache for URL: $Url"
                return $cachedEntry
            } else {
                Write-Warning "Cached entry is corrupted. Will re-fetch video information."
                Write-ErrorLog "Corrupted cache entry for URL: $Url"
                # Remove corrupted entry
                Remove-VideoFromCache -Url $Url
                return $null
            }
        }
    } catch {
        Write-ErrorLog "Failed to retrieve from cache: $($_.Exception.Message)"
        Write-Warning "Cache file might be corrupted. Consider deleting $dbPath"
    }
    
    return $null
}

function Remove-VideoFromCache {
    param ([string]$Url)
    
    $dbPath = Join-Path $scriptDir $settings.general.database_file
    if (-not (Test-Path $dbPath)) {
        return
    }
    
    try {
        $db = Get-Content $dbPath -Raw | ConvertFrom-Json
        $db.videos = @($db.videos | Where-Object { $_.url -ne $Url })
        $db | ConvertTo-Json -Depth 10 | Out-File -FilePath $dbPath -Encoding UTF8
        Write-ErrorLog "Removed corrupted cache entry for URL: $Url"
    } catch {
        Write-ErrorLog "Failed to remove cache entry: $($_.Exception.Message)"
    }
}

function Save-VideoToCache {
    param (
        [string]$Url,
        [psobject]$VideoInfo
    )
    
    if (-not [bool]$settings.general.use_database_cache) {
        return
    }
    
    $dbPath = Join-Path $scriptDir $settings.general.database_file
    
    try {
        $db = @{ videos = @() }
        if (Test-Path $dbPath) {
            $db = Get-Content $dbPath -Raw | ConvertFrom-Json
        }
        
        # Remove any existing entry for this URL
        $db.videos = @($db.videos | Where-Object { $_.url -ne $Url })
        
        # Add new entry
        $newEntry = @{
            url = $Url
            info = $VideoInfo
            cached_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $db.videos += $newEntry
        
        $db | ConvertTo-Json -Depth 10 | Out-File -FilePath $dbPath -Encoding UTF8
        Write-Host "Video information saved to cache" -ForegroundColor Green
        Write-ErrorLog "Video cached for URL: $Url"
    } catch {
        Write-Warning "Failed to save to cache: $($_.Exception.Message)"
        Write-ErrorLog "Failed to save to cache: $($_.Exception.Message)"
    }
}

function Get-CookieFilePath {
    if (-not [bool]$settings.cookies.use_cookies) {
        return $null
    }
    
    $cookieFile = $settings.cookies.cookie_file_path
    if ($settings.cookies.cookie_file_directory) {
        $cookieFile = Join-Path $settings.cookies.cookie_file_directory $cookieFile
    } else {
        $cookieFile = Join-Path $scriptDir $cookieFile
    }
    
    if (Test-Path $cookieFile) {
        Write-Host "Using cookie file: $cookieFile" -ForegroundColor Green
        Write-ErrorLog "Cookie file found and will be used: $cookieFile"
        return $cookieFile
    } else {
        Write-Warning "Cookie file not found at: $cookieFile"
        Write-ErrorLog "Cookie file not found at: $cookieFile"
        return $null
    }
}

function Show-ProcessingMessage {
    param ([string]$Message = "Processing, please wait...")
    
    if ([bool]$settings.general.show_processing_messages) {
        Write-Host $Message -ForegroundColor Yellow
        Write-ErrorLog "Processing message displayed: $Message"
    }
}

function Show-CustomDownloadProgress {
    param (
        [string]$Activity = "Downloading",
        [double]$Percentage = 0,
        [string]$TotalSize = "",
        [string]$Speed = "",
        [string]$ETA = "",
        [string]$CurrentSize = "",
        [string]$FileName = "",
        [string]$Stage = "download"  # download, merge, process
    )
    
    # Clear current line
    $clearLine = "`r" + (" " * [Math]::Min($Host.UI.RawUI.WindowSize.Width, 120)) + "`r"
    Write-Host $clearLine -NoNewline
    
    # Build progress bar
    $barWidth = 30
    $filledBars = [Math]::Floor($Percentage / 100 * $barWidth)
    $emptyBars = $barWidth - $filledBars
    
    # Use different characters for different stages
    $fillChar = switch ($Stage) {
        "download" { "█" }
        "merge" { "▓" }
        "process" { "▒" }
        default { "█" }
    }
    
    $progressBar = "[" + ($fillChar * $filledBars) + ("░" * $emptyBars) + "]"
    
    # Build status line
    $statusParts = @()
    
    # Add activity icon
    $activityIcon = switch ($Activity) {
        "Downloading" { "⬇" }
        "Merging" { "🔀" }
        "Processing" { "⚙" }
        "Converting" { "🔄" }
        "Extracting" { "📦" }
        default { "•" }
    }
    
    $statusParts += $activityIcon
    
    if ($FileName) {
        # Truncate filename if too long
        $maxFileNameLength = 35
        if ($FileName.Length -gt $maxFileNameLength) {
            $FileName = $FileName.Substring(0, $maxFileNameLength - 3) + "..."
        }
        $statusParts += $FileName
    }
    
    $statusParts += $progressBar
    $statusParts += "$([Math]::Round($Percentage, 1))%"
    
    if ($CurrentSize -and $TotalSize) {
        $statusParts += "$CurrentSize/$TotalSize"
    } elseif ($TotalSize) {
        $statusParts += $TotalSize
    }
    
    if ($Speed) {
        $statusParts += "@ $Speed"
    }
    
    if ($ETA -and $ETA -ne "Unknown") {
        $statusParts += "ETA: $ETA"
    }
    
    $statusLine = $statusParts -join " "
    
    # Color based on percentage and stage
    $color = if ($Percentage -ge 100) { "Green" } 
             elseif ($Stage -eq "merge") { "Magenta" }
             elseif ($Stage -eq "process") { "Cyan" }
             elseif ($Percentage -ge 75) { "Yellow" } 
             elseif ($Percentage -ge 50) { "Cyan" } 
             else { "White" }
    
    Write-Host $statusLine -ForegroundColor $color -NoNewline
}

function Write-ErrorLog {
    param ([string]$message)
    
    # Use settings for debug logging if available, otherwise use default
    $enableLogging = if ($settings -and $settings.advanced.enable_debug_logging) { [bool]$settings.advanced.enable_debug_logging } else { $true }
    if (-not $enableLogging) {
        return
    }
    
    $logPath = if ($settings -and $settings.advanced.log_file_path) { 
        Join-Path $scriptDir $settings.advanced.log_file_path 
    } else { 
        $DebugLogPath 
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    try {
        Add-Content -Path $logPath -Value $logMessage -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to debug log: $($_.Exception.Message)"
    }
}

function Get-LocalVersion {
    param (
        [string]$ExecutablePath,
        [string]$VersionArg = "--version"
    )
    
    if (-not (Test-Path $ExecutablePath)) {
        return $null
    }
    
    try {
        $versionOutput = & $ExecutablePath $VersionArg 2>&1 | Select-Object -First 1
        if ($versionOutput -match '(\d+\.[\d.]+)') {
            return $matches[1]
        }
        return "unknown"
    } catch {
        Write-ErrorLog "Failed to get version for $ExecutablePath : $($_.Exception.Message)"
        return "unknown"
    }
}

function Get-LatestYtDlpVersion {
    try {
        $apiUrl = "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        return $response.tag_name
    } catch {
        Write-ErrorLog "Failed to get latest yt-dlp version: $($_.Exception.Message)"
        return $null
    }
}

function Get-LatestFfmpegVersion {
    try {
        $apiUrl = "https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        # Extract version from asset name
        foreach ($asset in $response.assets) {
            if ($asset.name -match 'ffmpeg-(.+?)-win64-gpl\.zip') {
                return $matches[1]
            }
        }
        return $response.tag_name
    } catch {
        Write-ErrorLog "Failed to get latest ffmpeg version: $($_.Exception.Message)"
        return $null
    }
}

function Update-YtDlp {
    param ([string]$YtDlpPath)
    
    Write-Host "Checking yt-dlp version..." -ForegroundColor Yellow
    $localVersion = Get-LocalVersion -ExecutablePath $YtDlpPath
    $latestVersion = Get-LatestYtDlpVersion
    
    if ($null -eq $localVersion) {
        Write-Host "yt-dlp not found. Installing..." -ForegroundColor Yellow
        $needsUpdate = $true
    } elseif ($null -eq $latestVersion) {
        Write-Host "Could not check latest yt-dlp version. Using existing version." -ForegroundColor Yellow
        return
    } elseif ($localVersion -eq "unknown") {
        Write-Host "Could not determine local yt-dlp version. Re-downloading..." -ForegroundColor Yellow
        $needsUpdate = $true
    } else {
        Write-Host "Local yt-dlp version: $localVersion" -ForegroundColor Cyan
        Write-Host "Latest yt-dlp version: $latestVersion" -ForegroundColor Cyan
        
        if ($localVersion -ne $latestVersion) {
            Write-Host "New version available! Updating..." -ForegroundColor Green
            $needsUpdate = $true
        } else {
            Write-Host "yt-dlp is up to date." -ForegroundColor Green
            return
        }
    }
    
    if ($needsUpdate) {
        # Backup old version if exists
        if (Test-Path $YtDlpPath) {
            $backupPath = "$YtDlpPath.old"
            try {
                Move-Item -Path $YtDlpPath -Destination $backupPath -Force -ErrorAction Stop
                Write-Host "Backed up old version to $backupPath" -ForegroundColor Gray
            } catch {
                Write-Warning "Failed to backup old yt-dlp: $($_.Exception.Message)"
            }
        }
        
        # Download new version
        $ytDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
        try {
            Write-Host "Downloading yt-dlp from: $ytDlpUrl" -Verbose
            Invoke-WebRequest -Uri $ytDlpUrl -OutFile $YtDlpPath -ErrorAction Stop
            Write-Host "yt-dlp updated successfully to version $latestVersion" -ForegroundColor Green
            Write-ErrorLog "yt-dlp updated to version $latestVersion"
            
            # Remove backup if successful
            if (Test-Path "$YtDlpPath.old") {
                Remove-Item -Path "$YtDlpPath.old" -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # Restore backup if download failed
            if (Test-Path "$YtDlpPath.old") {
                Move-Item -Path "$YtDlpPath.old" -Destination $YtDlpPath -Force -ErrorAction SilentlyContinue
            }
            Resolve-ScriptError -UserMessage "Failed to download yt-dlp. Check your internet connection." `
                               -InternalLogMessage "Invoke-WebRequest failed for yt-dlp. URL: $ytDlpUrl. Exception: $($_.Exception.Message)" `
                               -IsCritical $true
        }
    }
}

function Update-Ffmpeg {
    param ([string]$FfmpegPath)
    
    Write-Host "Checking ffmpeg version..." -ForegroundColor Yellow
    $localVersion = Get-LocalVersion -ExecutablePath $FfmpegPath -VersionArg "-version"
    $latestVersion = Get-LatestFfmpegVersion
    
    if ($null -eq $localVersion) {
        Write-Host "ffmpeg not found. Installing..." -ForegroundColor Yellow
        $needsUpdate = $true
    } elseif ($null -eq $latestVersion) {
        Write-Host "Could not check latest ffmpeg version. Using existing version." -ForegroundColor Yellow
        return
    } else {
        Write-Host "Local ffmpeg version info: $localVersion" -ForegroundColor Cyan
        Write-Host "Latest ffmpeg build: $latestVersion" -ForegroundColor Cyan
        
        # For ffmpeg, we'll check if local file is older than 30 days
        if (Test-Path $FfmpegPath) {
            $fileAge = (Get-Date) - (Get-Item $FfmpegPath).LastWriteTime
            if ($fileAge.Days -gt 30) {
                Write-Host "ffmpeg is more than 30 days old. Updating..." -ForegroundColor Yellow
                $needsUpdate = $true
            } else {
                Write-Host "ffmpeg is relatively recent (less than 30 days old)." -ForegroundColor Green
                return
            }
        }
    }
    
    if ($needsUpdate) {
        # Backup old version if exists
        if (Test-Path $FfmpegPath) {
            $backupPath = "$FfmpegPath.old"
            try {
                Move-Item -Path $FfmpegPath -Destination $backupPath -Force -ErrorAction Stop
                Write-Host "Backed up old version to $backupPath" -ForegroundColor Gray
            } catch {
                Write-Warning "Failed to backup old ffmpeg: $($_.Exception.Message)"
            }
        }
        
        # Download new version
        $ffmpegZipUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        $tempZipPath = Join-Path $env:TEMP "ffmpeg_syd_temp.zip"
        $tempExtractPath = Join-Path $env:TEMP "ffmpeg_syd_extract"
        
        if (Test-Path $tempExtractPath) { Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
        
        try {
            Write-Host "Downloading ffmpeg.zip from: $ffmpegZipUrl" -Verbose
            Invoke-WebRequest -Uri $ffmpegZipUrl -OutFile $tempZipPath -ErrorAction Stop
            Write-Host "ffmpeg.zip downloaded. Extracting..." -ForegroundColor Yellow
            Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force -ErrorAction Stop
            
            $ffmpegExeFile = Get-ChildItem -Path $tempExtractPath -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
            if ($ffmpegExeFile) {
                Copy-Item -Path $ffmpegExeFile.FullName -Destination $FfmpegPath -Force -ErrorAction Stop
                Write-Host "ffmpeg updated successfully!" -ForegroundColor Green
                Write-ErrorLog "ffmpeg updated to latest version"
                
                # Remove backup if successful
                if (Test-Path "$FfmpegPath.old") {
                    Remove-Item -Path "$FfmpegPath.old" -Force -ErrorAction SilentlyContinue
                }
            } else {
                throw "ffmpeg.exe not found within the downloaded files."
            }
        } catch {
            # Restore backup if download failed
            if (Test-Path "$FfmpegPath.old") {
                Move-Item -Path "$FfmpegPath.old" -Destination $FfmpegPath -Force -ErrorAction SilentlyContinue
            }
            Resolve-ScriptError -UserMessage "Failed during ffmpeg download or setup." `
                               -InternalLogMessage "Error during ffmpeg setup. URL: $ffmpegZipUrl. Exception: $($_.Exception.Message)" `
                               -IsCritical $true
        } finally {
            if (Test-Path $tempZipPath) { Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempExtractPath) { Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

function Invoke-YouTubeLogin {
    param ([string]$Url)
    
    if (-not [bool]$settings.youtube_login.enable_auto_login) {
        return $false
    }
    
    Write-Host "`nAttempting to sign in to YouTube account..." -ForegroundColor Yellow
    Write-ErrorLog "Attempting YouTube login for URL: $Url"
    
    try {
        # Check if Chrome is available
        $chromePath = Get-Command "chrome" -ErrorAction SilentlyContinue
        if (-not $chromePath) {
            $chromePath = Get-Command "C:\Program Files\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue
        }
        if (-not $chromePath) {
            $chromePath = Get-Command "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue
        }
        
        if (-not $chromePath) {
            Write-Host "Google Chrome not found. Cannot perform automatic login." -ForegroundColor Red
            Write-ErrorLog "Chrome not found for YouTube login"
            return $false
        }
        
        Write-Host "Opening Chrome for YouTube login..." -ForegroundColor Yellow
        Write-Host "Please sign in to your YouTube account in the opened browser." -ForegroundColor Green
        Write-Host "After signing in, close the browser window to continue." -ForegroundColor Green
        
        $chromeArgs = @(
            "--new-window",
            "--disable-web-security",
            "--disable-features=VizDisplayCompositor",
            "https://accounts.google.com/signin"
        )
        
        if ($settings.youtube_login.chrome_profile_path) {
            $chromeArgs += "--user-data-dir=$($settings.youtube_login.chrome_profile_path)"
        }
        
        $chromeProcess = Start-Process -FilePath $chromePath.Source -ArgumentList $chromeArgs -PassThru
        
        # Wait for user to complete login
        $timeout = $settings.youtube_login.login_timeout_seconds
        $waited = 0
        while (-not $chromeProcess.HasExited -and $waited -lt $timeout) {
            Start-Sleep -Seconds 1
            $waited++
            if ($waited % 10 -eq 0) {
                Write-Host "Waiting for login completion... ($waited/$timeout seconds)" -ForegroundColor Yellow
            }
        }
        
        if (-not $chromeProcess.HasExited) {
            Write-Host "Login timeout reached. Please close the browser manually." -ForegroundColor Yellow
            $chromeProcess.Kill()
        }
        
        Write-Host "Login process completed." -ForegroundColor Green
        Write-ErrorLog "YouTube login process completed"
        return $true
        
    } catch {
        Write-Host "Failed to perform YouTube login: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "YouTube login failed: $($_.Exception.Message)"
        return $false
    }
}

function Add-EnhancedHeaders {
    param (
        [System.Collections.Generic.List[string]]$ArgumentsList
    )
    
    # Add enhanced headers to avoid 403 errors
    $ArgumentsList.Add("--no-check-certificate")
    $ArgumentsList.Add("--user-agent")
    $ArgumentsList.Add("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    $ArgumentsList.Add("--add-header")
    $ArgumentsList.Add("Accept-Language:en-US,en;q=0.9")
    $ArgumentsList.Add("--add-header")
    $ArgumentsList.Add("Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    $ArgumentsList.Add("--add-header")
    $ArgumentsList.Add("Sec-Fetch-Mode:navigate")
}

function New-DownloadArguments {
    param (
        [string]$FfmpegPath,
        [string]$OutputTemplate,
        [string]$Format,
        [string]$Url,
        [string]$Type = "video",  # "video", "audio", "audio_specific"
        [int]$Bitrate = 0,
        [bool]$UseCookies = $false,
        [string]$CookieFilePath = ""
    )
    
    $args = New-Object System.Collections.Generic.List[string]
    $args.Add("--no-warnings")
    Add-EnhancedHeaders -ArgumentsList $args
    
    # Add proxy if configured
    if ($env:HTTP_PROXY) {
        $args.Add("--proxy"); $args.Add($env:HTTP_PROXY)
    }
    
    # Add cookies if available
    if ($UseCookies -and $CookieFilePath -and (Test-Path $CookieFilePath)) {
        $args.Add("--cookies"); $args.Add($CookieFilePath)
    }
    
    $args.Add("--ffmpeg-location"); $args.Add($FfmpegPath)
    $args.Add("-o"); $args.Add($OutputTemplate)
    $args.Add("-f"); $args.Add($Format)
    
    switch ($Type) {
        "video" {
            $args.Add("--merge-output-format"); $args.Add("mp4")
            $args.Add("--write-subs")
            $args.Add("--sub-lang"); $args.Add("fa,en")
            $args.Add("--embed-subs")
            $args.Add("--convert-subs"); $args.Add("srt")
        }
        "audio" {
            $args.Add("--extract-audio")
            $args.Add("--audio-format"); $args.Add("mp3")
            if ($Bitrate -gt 0) {
                $args.Add("--audio-quality"); $args.Add("$($Bitrate)K")
            }
        }
        "audio_specific" {
            $args.Add("--extract-audio")
            $args.Add("--audio-format"); $args.Add("mp3")
        }
    }
    
    $args.Add($Url)
    return $args
}

function Get-VideoInfoWithTimeout {
    param (
        [string]$Url,
        [string]$YtDlpPath,
        [int]$TimeoutSeconds = 20,
        [switch]$UseCookies = $false,
        [string]$CookieFilePath = ""
    )
    
    Write-ErrorLog "Attempting to get video info with timeout: $TimeoutSeconds seconds"
    
    $job = Start-Job -ScriptBlock {
        param($url, $ytDlpPath, $useCookies, $cookieFilePath)
        
        $args = @(
            "--dump-json", 
            "--no-warnings", 
            "--no-check-certificate",
            "--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "--add-header", "Accept-Language:en-US,en;q=0.9",
            "--add-header", "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "--add-header", "Sec-Fetch-Mode:navigate"
        )
        
        # Add proxy if configured
        if ($env:HTTP_PROXY) {
            $args += "--proxy"
            $args += $env:HTTP_PROXY
        }
        
        if ($useCookies -and $cookieFilePath -and (Test-Path $cookieFilePath)) {
            $args += "--cookies"
            $args += $cookieFilePath
        }
        $args += $url
        
        try {
            $output = & $ytDlpPath @args 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0) {
                return @{
                    Success = $true
                    Output = $output
                    ExitCode = $exitCode
                }
            } else {
                return @{
                    Success = $false
                    Error = ($output -join "`n")
                    ExitCode = $exitCode
                }
            }
        } catch {
            return @{
                Success = $false
                Error = "Exception: $($_.Exception.Message)"
                ExitCode = -1
            }
        }
    } -ArgumentList $Url, $YtDlpPath, $UseCookies, $CookieFilePath
    
    try {
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job
            Write-ErrorLog "Video info job completed within timeout. Success: $($result.Success), ExitCode: $($result.ExitCode)"
            return $result
        } else {
            Write-ErrorLog "Video info retrieval timed out after $TimeoutSeconds seconds"
            Remove-Job -Job $job -Force
            return @{
                Success = $false
                Error = "Request timed out after $TimeoutSeconds seconds"
                ExitCode = -2
            }
        }
    } catch {
        Write-ErrorLog "Error in Get-VideoInfoWithTimeout: $($_.Exception.Message)"
        try { Remove-Job -Job $job -Force } catch { }
        return @{
            Success = $false
            Error = "Timeout handling error: $($_.Exception.Message)"
            ExitCode = -3
        }
    }
}

function Show-ErrorHandlingOptions {
    param (
        [string]$Url,
        [string]$ErrorMessage
    )
    
    Write-Host "`n-------------------- ERROR HANDLING OPTIONS --------------------" -ForegroundColor Red
    Write-Host "Failed to retrieve video information: $ErrorMessage" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available options:" -ForegroundColor Yellow
    Write-Host "1. Try with cookies (if configured)" -ForegroundColor White
    Write-Host "2. Sign in to YouTube account" -ForegroundColor White
    Write-Host "3. Retry with current settings" -ForegroundColor White
    Write-Host "4. Enter a different URL" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    Write-Host "--------------------------------------------------------------" -ForegroundColor Red
    
    $choice = Get-ValidatedUserInput -Prompt "Please select an option:" -InputType "number" -MinValue 1 -MaxValue 5 -MaxAttempts 3
    
    switch ($choice) {
        "1" {
            if ([bool]$settings.cookies.use_cookies) {
                Write-Host "Attempting to use cookies..." -ForegroundColor Yellow
                return "cookies"
            } else {
                Write-Host "Cookie support is disabled. Please enable it in settings.json" -ForegroundColor Red
                Write-Host "Set 'use_cookies' to true and configure 'cookie_file_path'" -ForegroundColor Yellow
                return "configure_cookies"
            }
        }
        "2" {
            Write-Host "Attempting YouTube login..." -ForegroundColor Yellow
            return "login"
        }
        "3" {
            Write-Host "Retrying with current settings..." -ForegroundColor Yellow
            return "retry"
        }
        "4" {
            Write-Host "Please enter a different URL..." -ForegroundColor Yellow
            return "new_url"
        }
        "5" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            return "exit"
        }
        default {
            if ($null -eq $choice) {
                Write-Host "No valid option selected. Using retry as default." -ForegroundColor Yellow
                return "retry"
            }
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            return Show-ErrorHandlingOptions -Url $Url -ErrorMessage $ErrorMessage
        }
    }
}

function Resolve-ScriptError {
    param (
        [string]$UserMessage,
        [string]$InternalLogMessage,
        [switch]$IsCritical = $false
    )
    
    # Use enhanced error display
    Show-EnhancedError -TechnicalError $InternalLogMessage -Context $UserMessage

    if ($IsCritical) {
        Write-Host "The script will now exit due to a critical error." -ForegroundColor Red
        $Host.UI.RawUI.BackgroundColor = $originalBackground
        $Host.UI.RawUI.ForegroundColor = $originalForeground
        Clear-Host
        exit 1
    }
}

function Show-ScriptHelp {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      YouTube Downloader Pro - Complete Guide                  ║" -ForegroundColor Cyan
    Write-Host "║                                 Created by MBNPRO                             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📖 TABLE OF CONTENTS" -ForegroundColor Yellow
    Write-Host "───────────────────" -ForegroundColor Gray
    Write-Host "  1. Quick Start" -ForegroundColor White
    Write-Host "  2. Available Commands" -ForegroundColor White
    Write-Host "  3. Features Overview" -ForegroundColor White
    Write-Host "  4. Download Options" -ForegroundColor White
    Write-Host "  5. Configuration Guide" -ForegroundColor White
    Write-Host "  6. Troubleshooting" -ForegroundColor White
    Write-Host "  7. Settings.json Reference" -ForegroundColor White
    Write-Host ""
    
    Write-Host "⚡ 1. QUICK START" -ForegroundColor Green
    Write-Host "─────────────────" -ForegroundColor Gray
    Write-Host "  Simply run: " -NoNewline; Write-Host ".\syd_latest.ps1" -ForegroundColor Yellow
    Write-Host "  Then paste any YouTube URL when prompted!" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🎯 2. AVAILABLE COMMANDS" -ForegroundColor Green
    Write-Host "────────────────────────" -ForegroundColor Gray
    Write-Host "  During URL prompt, you can use these commands:" -ForegroundColor White
    Write-Host ""
    Write-Host "  📹 YouTube URL    : " -NoNewline; Write-Host "Paste any YouTube video link" -ForegroundColor Gray
    Write-Host "  📖 help, -h       : " -NoNewline; Write-Host "Show this comprehensive help guide" -ForegroundColor Gray
    Write-Host "  🚪 exit           : " -NoNewline; Write-Host "Exit the program gracefully" -ForegroundColor Gray
    Write-Host "  🗑️  clear-cache    : " -NoNewline; Write-Host "Clear cached video information" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Command line options:" -ForegroundColor White
    Write-Host "  .\syd_latest.ps1 -Help    : " -NoNewline; Write-Host "Show help and exit" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "✨ 3. FEATURES OVERVIEW" -ForegroundColor Green
    Write-Host "───────────────────────" -ForegroundColor Gray
    Write-Host "  🎥 VIDEO DOWNLOADS" -ForegroundColor Cyan
    Write-Host "     • Download videos in ANY available quality (144p to 8K)" -ForegroundColor White
    Write-Host "     • Automatic merging of best video + audio streams" -ForegroundColor White
    Write-Host "     • Subtitle support (English, Farsi, and more)" -ForegroundColor White
    Write-Host "     • Smart format conversion to MP4" -ForegroundColor White
    Write-Host ""
    Write-Host "  🎵 AUDIO EXTRACTION" -ForegroundColor Cyan
    Write-Host "     • Extract audio from any video" -ForegroundColor White
    Write-Host "     • Convert to MP3 with custom bitrates (128/256/320 kbps)" -ForegroundColor White
    Write-Host "     • Preserve original audio quality" -ForegroundColor White
    Write-Host ""
    Write-Host "  🖼️  THUMBNAIL DOWNLOADS" -ForegroundColor Cyan
    Write-Host "     • Download video thumbnails in highest quality" -ForegroundColor White
    Write-Host "     • Multiple download methods for reliability" -ForegroundColor White
    Write-Host ""
    Write-Host "  🚀 PERFORMANCE & RELIABILITY" -ForegroundColor Cyan
    Write-Host "     • Smart caching system for instant video info retrieval" -ForegroundColor White
    Write-Host "     • Automatic retry on failures" -ForegroundColor White
    Write-Host "     • Beautiful progress display with speed and ETA" -ForegroundColor White
    Write-Host "     • Proxy support (system and custom)" -ForegroundColor White
    Write-Host "     • Cookie authentication for private/age-restricted videos" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📥 4. DOWNLOAD OPTIONS" -ForegroundColor Green
    Write-Host "──────────────────────" -ForegroundColor Gray
    Write-Host "  When you enter a YouTube URL, you'll see:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1️⃣  BEST QUALITY (Recommended)" -ForegroundColor Yellow
    Write-Host "     Automatically selects and merges best video + audio" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2️⃣  SPECIFIC VIDEO FORMATS" -ForegroundColor Yellow
    Write-Host "     Choose exact resolution and codec (H.264, VP9, AV1)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3️⃣  AUDIO ONLY OPTIONS" -ForegroundColor Yellow
    Write-Host "     • MP3 320kbps - Studio quality" -ForegroundColor Gray
    Write-Host "     • MP3 256kbps - Premium quality" -ForegroundColor Gray
    Write-Host "     • MP3 128kbps - Standard quality" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4️⃣  THUMBNAIL DOWNLOAD" -ForegroundColor Yellow
    Write-Host "     Save the video's cover image" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "⚙️  5. CONFIGURATION GUIDE" -ForegroundColor Green
    Write-Host "──────────────────────────" -ForegroundColor Gray
    Write-Host "  All settings are stored in: " -NoNewline; Write-Host "settings.json" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  📁 File Locations:" -ForegroundColor Cyan
    Write-Host "     • Downloads  : Downloaded\Video, Downloaded\Audio, Downloaded\Covers" -ForegroundColor White
    Write-Host "     • Temp files : Temp\" -ForegroundColor White
    Write-Host "     • Cache      : video_cache.json" -ForegroundColor White
    Write-Host "     • Cookies    : cookies.txt" -ForegroundColor White
    Write-Host "     • Debug log  : debug.txt" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🔧 6. TROUBLESHOOTING" -ForegroundColor Green
    Write-Host "─────────────────────" -ForegroundColor Gray
    Write-Host "  ❌ Download fails?" -ForegroundColor Red
    Write-Host "     • Check your internet connection" -ForegroundColor White
    Write-Host "     • Try using cookies (see settings.json)" -ForegroundColor White
    Write-Host "     • Enable proxy if behind firewall" -ForegroundColor White
    Write-Host "     • Clear cache with 'clear-cache' command" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔒 Age-restricted or private video?" -ForegroundColor Red
    Write-Host "     • Configure cookies.txt from your browser" -ForegroundColor White
    Write-Host "     • Use YouTube login option when prompted" -ForegroundColor White
    Write-Host ""
    Write-Host "  🐛 Other issues?" -ForegroundColor Red
    Write-Host "     • Check debug.txt for detailed error logs" -ForegroundColor White
    Write-Host "     • Update yt-dlp and ffmpeg (automatic on start)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📋 7. SETTINGS.JSON REFERENCE" -ForegroundColor Green
    Write-Host "─────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  🔹 general:" -ForegroundColor Cyan
    Write-Host "     • request_timeout_seconds : Network timeout (default: 20)" -ForegroundColor White
    Write-Host "     • max_retries            : Retry attempts (default: 3)" -ForegroundColor White
    Write-Host "     • use_database_cache     : Enable caching (default: true)" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔹 proxy:" -ForegroundColor Cyan
    Write-Host "     • use_system_proxy   : Use Windows proxy (default: true)" -ForegroundColor White
    Write-Host "     • custom_proxy_host  : Custom proxy IP" -ForegroundColor White
    Write-Host "     • custom_proxy_port  : Custom proxy port" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔹 cookies:" -ForegroundColor Cyan
    Write-Host "     • use_cookies       : Enable cookie auth (default: true)" -ForegroundColor White
    Write-Host "     • cookie_file_path  : Cookie file name (default: cookies.txt)" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔹 download:" -ForegroundColor Cyan
    Write-Host "     • temp_directory    : Temporary files location" -ForegroundColor White
    Write-Host "     • output_directory  : Final download location" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔹 advanced:" -ForegroundColor Cyan
    Write-Host "     • enable_debug_logging : Save detailed logs (default: true)" -ForegroundColor White
    Write-Host "     • cleanup_temp_files   : Auto-clean temp files (default: true)" -ForegroundColor White
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                         Press any key to continue...                          ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

function Initialize-Directory {
    param ([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Host "Created directory: $Path" -ForegroundColor Cyan
            Write-ErrorLog "Successfully created directory: $Path"
        } catch {
            Resolve-ScriptError -UserMessage "Failed to create a necessary directory: $Path. Please check permissions." `
                               -InternalLogMessage "New-Item failed for directory '$Path'. Exception: $($_.Exception.Message)" `
                               -IsCritical $true
        }
    }
}

function Convert-FileNameToComparable {
    param (
        [string]$FileName,
        [int]$MaxLength = 200
    )
    
    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return "untitled"
    }
    
    # Normalize Unicode characters
    $converted = $FileName.Normalize([System.Text.NormalizationForm]::FormC)
    
    # Replace common Unicode lookalikes with ASCII equivalents
    $converted = $converted.Replace('：', '-').Replace('｜', '-').Replace('？', '').Replace('＜', '(').Replace('＞', ')').Replace('＂', "'").Replace('＊', '-').Replace('＼', '-').Replace('／', '-')
    
    # Replace additional problematic characters
    $converted = $converted.Replace(':', '-').Replace('|', '-').Replace('?', '').Replace('<', '(').Replace('>', ')').Replace('"', "'").Replace('*', '-').Replace('\', '-').Replace('/', '-')
    $converted = $converted.Replace('[', '(').Replace(']', ')').Replace('{', '(').Replace('}', ')')
    
    # Remove or replace other invalid filename characters
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() + [System.IO.Path]::GetInvalidPathChars()
    $invalidCharsRegexPattern = ($invalidChars | ForEach-Object {[System.Text.RegularExpressions.Regex]::Escape($_)}) -join '|'
    
    if ($invalidCharsRegexPattern) {
        $converted = $converted -replace $invalidCharsRegexPattern, '_'
    }
    
    # Remove control characters and other problematic Unicode ranges
    $converted = $converted -replace '[\x00-\x1F\x7F]', ''  # Control characters
    $converted = $converted -replace '[\x80-\x9F]', ''     # Extended control characters
    
    # Clean up multiple spaces/underscores/dashes
    $converted = $converted -replace '\s+', ' '            # Multiple spaces to single space
    $converted = $converted -replace '_{2,}', '_'          # Multiple underscores to single
    $converted = $converted -replace '-{2,}', '-'          # Multiple dashes to single
    $converted = $converted -replace '[_\s\-]+$', ''       # Trailing underscores, spaces, dashes
    $converted = $converted -replace '^[_\s\-]+', ''       # Leading underscores, spaces, dashes
    
    # Trim whitespace
    $converted = $converted.Trim()
    
    # Ensure we have something
    if ([string]::IsNullOrWhiteSpace($converted)) {
        $converted = "video_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    }
    
    # Limit length
    if ($converted.Length -gt $MaxLength) {
        $converted = $converted.Substring(0, $MaxLength).TrimEnd(' ', '-', '_')
    }
    
    # Ensure it doesn't end with a period (Windows issue)
    $converted = $converted.TrimEnd('.')
    
    # Final check - if empty, provide fallback
    if ([string]::IsNullOrWhiteSpace($converted)) {
        $converted = "untitled_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    }
    
    return $converted
}

function Format-Bytes {
    param ($bytes)
    if ($null -eq $bytes -or $bytes -lt 0) { return "N/A" }
    if ($bytes -eq 0) { return "0 B" }
    $suffixes = "B", "KB", "MB", "GB", "TB", "PB"
    $order = 0
    [double]$bytesDouble = $bytes
    while ($bytesDouble -ge 1024 -and $order -lt ($suffixes.Length - 1)) {
        $bytesDouble /= 1024
        $order++
    }
    return "{0:N2} {1}" -f $bytesDouble, $suffixes[$order]
}

function Get-FormatDetails {
    param ([psobject]$Format)
    
    $details = @{
        FormatId = $Format.format_id
        Extension = $Format.ext
        Resolution = ""
        VideoCodec = ""
        AudioCodec = ""
        FileSize = ""
        Bitrate = ""
        FPS = ""
        Note = ""
        Type = ""
    }
    
    # Determine type
    if ($Format.vcodec -ne 'none' -and $Format.acodec -ne 'none') {
        $details.Type = "video+audio"
    } elseif ($Format.vcodec -ne 'none') {
        $details.Type = "video"
    } elseif ($Format.acodec -ne 'none') {
        $details.Type = "audio"
    } else {
        $details.Type = "unknown"
    }
    
    # Resolution
    if ($Format.width -and $Format.height) {
        $details.Resolution = "$($Format.width)x$($Format.height)"
    } elseif ($Format.height) {
        $details.Resolution = "$($Format.height)p"
    }
    
    # Video codec
    if ($Format.vcodec -and $Format.vcodec -ne 'none') {
        $details.VideoCodec = $Format.vcodec
    }
    
    # Audio codec
    if ($Format.acodec -and $Format.acodec -ne 'none') {
        $details.AudioCodec = $Format.acodec
    }
    
    # File size
    if ($Format.filesize) {
        $details.FileSize = Format-Bytes $Format.filesize
    } elseif ($Format.filesize_approx) {
        $details.FileSize = "~$(Format-Bytes $Format.filesize_approx)"
    }
    
    # Bitrate
    if ($Format.tbr) {
        $details.Bitrate = "$([int]$Format.tbr)k"
    } elseif ($Format.vbr -and $Format.abr) {
        $details.Bitrate = "$([int]($Format.vbr + $Format.abr))k"
    } elseif ($Format.vbr) {
        $details.Bitrate = "$([int]$Format.vbr)k"
    } elseif ($Format.abr) {
        $details.Bitrate = "$([int]$Format.abr)k"
    }
    
    # FPS
    if ($Format.fps) {
        $details.FPS = "$($Format.fps)fps"
    }
    
    # Note
    if ($Format.format_note -and $Format.format_note -ne "default") {
        $details.Note = $Format.format_note
    }
    
    return $details
}

function Show-FormatsMenu {
    param (
        [Parameter(Mandatory=$true)]
        [array]$Formats,
        [Parameter(Mandatory=$true)]
        [string]$VideoTitle
    )
    
    Write-Host ""
    Write-Host "📊 " -NoNewline -ForegroundColor Yellow
    Write-Host "Analyzing available formats..." -ForegroundColor White
    
    # Separate formats by type
    $videoFormats = @()
    $audioFormats = @()
    $combinedFormats = @()
    
    foreach ($format in $Formats) {
        $details = Get-FormatDetails -Format $format
        
        $formatObj = [PSCustomObject]@{
            Format = $format
            Details = $details
        }
        
        switch ($details.Type) {
            "video+audio" { $combinedFormats += $formatObj }
            "video" { $videoFormats += $formatObj }
            "audio" { $audioFormats += $formatObj }
        }
    }
    
    # Sort formats
    $combinedFormats = $combinedFormats | Sort-Object -Property {$_.Format.height}, {$_.Format.tbr} -Descending
    $videoFormats = $videoFormats | Sort-Object -Property {$_.Details.VideoCodec}, {$_.Format.height}, {$_.Format.tbr} -Descending
    $audioFormats = $audioFormats | Sort-Object -Property {$_.Details.AudioCodec}, {$_.Format.abr} -Descending
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                           AVAILABLE DOWNLOAD OPTIONS                          ║" -ForegroundColor Cyan
    Write-Host "╠═══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║ " -NoNewline -ForegroundColor Cyan
    Write-Host "Video: " -NoNewline -ForegroundColor Yellow
    $titleDisplay = $VideoTitle
    if ($titleDisplay.Length -gt 65) { $titleDisplay = $titleDisplay.Substring(0, 62) + "..." }
    Write-Host $titleDisplay.PadRight(71) -NoNewline -ForegroundColor White
    Write-Host " ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $menuOptions = @()
    $optionNumber = 1
    
    # --- Best quality option (merge best video + best audio) ---
    Write-Host ""
    Write-Host "⭐ QUICK OPTIONS" -ForegroundColor Yellow
    Write-Host "────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "$([string]($optionNumber++)).".PadRight(4) -NoNewline -ForegroundColor Cyan
    Write-Host "🏆 " -NoNewline
    Write-Host "Best Quality " -NoNewline -ForegroundColor Green
    Write-Host "(Recommended - Merges best video + best audio)" -ForegroundColor Gray
    $menuOptions += @{
        Number = $optionNumber - 1
        Type = "best"
        Description = "Download best available quality"
    }
    
    # --- Combined formats (video+audio) ---
    if ($combinedFormats.Count -gt 0) {
        Write-Host "`n--- Pre-Combined Formats (Video + Audio) ---" -ForegroundColor Green
        $headerCombined = "{0,-9} | {1,-4} | {2,-10} | {3,-15} | {4,-15} | {5,-11} | {6,-8} | {7}" -f "Format ID", "Ext", "Resolution", "Video Codec", "Audio Codec", "Size", "Bitrate", "Note"
        Write-Host (" " * 4) $headerCombined -ForegroundColor Yellow
        Write-Host (" " * 4) ("-" * $headerCombined.Length) -ForegroundColor Gray
        
        foreach ($fmt in $combinedFormats) {
            $d = $fmt.Details
            $line = "{0,-9} | {1,-4} | {2,-10} | {3,-15} | {4,-15} | {5,-11} | {6,-8} | {7}" -f $d.FormatId, $d.Extension, $d.Resolution, $d.VideoCodec, $d.AudioCodec, $d.FileSize, $d.Bitrate, $d.Note
            $displayNum = "{0,2}." -f $optionNumber
            Write-Host " $displayNum $line" -ForegroundColor White
            
            $menuOptions += @{ Number = $optionNumber; Type = "combined"; Format = $fmt.Format; Description = "Download combined $($d.Resolution)" }
            $optionNumber++
        }
    }
    
    # --- Video-Only Formats (Grouped by Codec) ---
    if ($videoFormats.Count -gt 0) {
        Write-Host "`n--- Video-Only Formats (will be merged with best audio) ---" -ForegroundColor Green
        $videoCodecGroups = $videoFormats | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Details.VideoCodec) } | Group-Object -Property {$_.Details.VideoCodec}
        
        foreach ($group in $videoCodecGroups) {
            Write-Host "`n  Codec: $($group.Name)" -ForegroundColor Yellow
            $headerVideo = "{0,-9} | {1,-4} | {2,-10} | {3,-15} | {4,-11} | {5,-8} | {6,-8} | {7}" -f "Format ID", "Ext", "Resolution", "Video Codec", "Size", "Bitrate", "FPS", "Note"
            Write-Host (" " * 4) $headerVideo -ForegroundColor Yellow
            Write-Host (" " * 4) ("-" * $headerVideo.Length) -ForegroundColor Gray

            foreach ($fmt in $group.Group) {
                $d = $fmt.Details
                $line = "{0,-9} | {1,-4} | {2,-10} | {3,-15} | {4,-11} | {5,-8} | {6,-8} | {7}" -f $d.FormatId, $d.Extension, $d.Resolution, $d.VideoCodec, $d.FileSize, $d.Bitrate, $d.FPS, $d.Note
                $displayNum = "{0,2}." -f $optionNumber
                Write-Host " $displayNum $line" -ForegroundColor White

                $menuOptions += @{ Number = $optionNumber; Type = "specific_video"; Format = $fmt.Format; Description = "Download $($d.Resolution) video" }
                $optionNumber++
            }
        }
    }

    # --- Audio Only Options ---
    Write-Host "`n--- Audio-Only Formats ---" -ForegroundColor Green

    # --- MP3 Conversion Options ---
    Write-Host "`n  🎧 MP3 CONVERSION OPTIONS" -ForegroundColor Magenta
    Write-Host "  ─────────────────────────" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  " -NoNewline
    Write-Host "$([string]($optionNumber++)).".PadRight(4) -NoNewline -ForegroundColor Cyan
    Write-Host "💎 " -NoNewline
    Write-Host "MP3 - 320 kbps " -NoNewline -ForegroundColor White
    Write-Host "(Studio Quality)" -ForegroundColor Green
    $menuOptions += @{ Number = $optionNumber - 1; Type = "mp3_conversion"; Bitrate = 320; Description = "Convert to MP3 at 320k" }
    
    Write-Host "  " -NoNewline
    Write-Host "$([string]($optionNumber++)).".PadRight(4) -NoNewline -ForegroundColor Cyan
    Write-Host "✨ " -NoNewline
    Write-Host "MP3 - 256 kbps " -NoNewline -ForegroundColor White
    Write-Host "(Premium Quality)" -ForegroundColor Yellow
    $menuOptions += @{ Number = $optionNumber - 1; Type = "mp3_conversion"; Bitrate = 256; Description = "Convert to MP3 at 256k" }
    
    Write-Host "  " -NoNewline
    Write-Host "$([string]($optionNumber++)).".PadRight(4) -NoNewline -ForegroundColor Cyan
    Write-Host "🎵 " -NoNewline
    Write-Host "MP3 - 128 kbps " -NoNewline -ForegroundColor White
    Write-Host "(Standard Quality)" -ForegroundColor Gray
    $menuOptions += @{ Number = $optionNumber - 1; Type = "mp3_conversion"; Bitrate = 128; Description = "Convert to MP3 at 128k" }

    # --- Specific Original Audio Formats ---
    if ($audioFormats.Count -gt 0) {
        Write-Host "`n  --- Original Audio Formats (will be converted to MP3) ---" -ForegroundColor Yellow
        $audioCodecGroups = $audioFormats | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Details.AudioCodec) } | Group-Object -Property {$_.Details.AudioCodec}

        foreach ($group in $audioCodecGroups) {
            Write-Host "`n    Codec: $($group.Name)" -ForegroundColor Yellow
            $headerAudio = "{0,-9} | {1,-4} | {2,-15} | {3,-11} | {4,-8} | {5}" -f "Format ID", "Ext", "Audio Codec", "Size", "Bitrate", "Note"
            Write-Host (" " * 6) $headerAudio -ForegroundColor Yellow
            Write-Host (" " * 6) ("-" * $headerAudio.Length) -ForegroundColor Gray

            foreach ($fmt in $group.Group) {
                $d = $fmt.Details
                $line = "{0,-9} | {1,-4} | {2,-15} | {3,-11} | {4,-8} | {5}" -f $d.FormatId, $d.Extension, $d.AudioCodec, $d.FileSize, $d.Bitrate, $d.Note
                $displayNum = "{0,2}." -f $optionNumber
                Write-Host "   $displayNum $line" -ForegroundColor White

                $menuOptions += @{ Number = $optionNumber; Type = "specific_audio"; Format = $fmt.Format; Description = "Download $($d.AudioCodec) audio" }
                $optionNumber++
            }
        }
    }

    # --- Other Options ---
    Write-Host ""
    Write-Host "🎨 OTHER OPTIONS" -ForegroundColor Yellow
    Write-Host "────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "$([string]($optionNumber++)).".PadRight(4) -NoNewline -ForegroundColor Cyan
    Write-Host "🖼️  " -NoNewline
    Write-Host "Download Video Thumbnail " -NoNewline -ForegroundColor White
    Write-Host "(Cover Image)" -ForegroundColor Gray
    $menuOptions += @{
        Number = $optionNumber - 1
        Type = "cover"
        Description = "Download video thumbnail"
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    return $menuOptions
}

function Show-DownloadProgress {
    param (
        [string]$Activity,
        [double]$Percentage = -1,
        [string]$TotalSize = "",
        [string]$Speed = "",
        [string]$ETA = ""
    )

    $barWidth = [int]($Host.UI.RawUI.WindowSize.Width * 0.4) # 40% of window width
    if ($barWidth -lt 20) { $barWidth = 20 }
    if ($barWidth -gt 50) { $barWidth = 50 }
    
    $line = "`r" 

    if ($Percentage -ge 0) {
        $completedWidth = [int]($barWidth * $Percentage / 100)
        $remainingWidth = $barWidth - $completedWidth
        $progressBar = ("█" * $completedWidth) + ("░" * $remainingWidth)
        $percentText = "{0,5:N1}%" -f $Percentage
        $speedText = if ($Speed) { "{0,12}" -f $Speed } else { " " * 12 }
        $etaText = if ($ETA) { "ETA: {0,-8}" -f $ETA } else { " " * 13 }
        $sizeText = if ($TotalSize) { "{0,10}" -f $TotalSize } else { " " * 10 }
        
        $line += "{0,-12} [{1}] {2} {3} {4} {5}" -f $Activity, $progressBar, $percentText, $sizeText, $speedText, $etaText
    } else {
        $line += "{0,-20}..." -f $Activity
    }

    $line = $line.PadRight($Host.UI.RawUI.WindowSize.Width - 1)
    Write-Host -NoNewline $line -ForegroundColor Green
}

function Invoke-YtDlpSimple {
    param (
        [string]$YtDlpPath,
        [System.Collections.Generic.List[string]]$YtDlpArguments
    )

    if ($null -eq $YtDlpArguments) {
        Write-ErrorLog "Invoke-YtDlpSimple called with null arguments."
        return @{ ExitCode = -1; Output = @(); Error = @("Internal Script Error: Download arguments were not provided.") }
    }
    
    # Verify yt-dlp exists
    if (-not (Test-Path $YtDlpPath)) {
        Write-ErrorLog "yt-dlp.exe not found at: $YtDlpPath"
        return @{ ExitCode = -1; Output = @(); Error = @("yt-dlp.exe not found at: $YtDlpPath") }
    }

    $outputLines = [System.Collections.Generic.List[string]]::new()
    $errorLines = [System.Collections.Generic.List[string]]::new()

    try {
        Write-Host "Initializing download..." -ForegroundColor Yellow
        Write-ErrorLog "Executing command: $YtDlpPath $($YtDlpArguments -join ' ')"
        Write-ErrorLog "Working Directory: $(Split-Path $YtDlpPath -Parent)"
        Write-ErrorLog "File exists: $(Test-Path $YtDlpPath)"
        
        # Use the simplest method - direct execution with & operator
        $currentLocation = Get-Location
        Set-Location (Split-Path $YtDlpPath -Parent)
        
        try {
            # Variables for progress tracking
            $currentFileName = ""
            $lastProgress = -1
            $currentStage = "download"
            
            # Execute yt-dlp directly and capture output line by line
            & $YtDlpPath $YtDlpArguments 2>&1 | ForEach-Object {
                $line = $_
                
                if ($line -is [System.Management.Automation.ErrorRecord]) {
                    $errorLines.Add($line.ToString())
                    # Don't show error lines in real-time unless critical
                    if ($line.ToString() -match "ERROR|CRITICAL") {
                        Write-Host $line -ForegroundColor Red
                    }
                } else {
                    $outputLines.Add($line.ToString())
                    
                    # Parse different types of output
                    # Extract filename
                    if ($line -match 'Destination:\s+(.+)') {
                        $currentFileName = [System.IO.Path]::GetFileName($matches[1])
                    }
                    
                    # Parse download progress
                    $dlRegex = '\[download\]\s+(?<percent>[\d\.]+)%\s+of\s+(?:~\s*)?(?<size>[\d\.]+)(?<unit>\w+)(?:\s+at\s+(?<speed>[\d\.]+\w+/s))?(?:\s+ETA\s+(?<eta>[\d:]+))?'
                    $dlMatch = [regex]::Match($line, $dlRegex)
                    
                    if ($dlMatch.Success) {
                        $percent = [double]$dlMatch.Groups['percent'].Value
                        $size = $dlMatch.Groups['size'].Value + $dlMatch.Groups['unit'].Value
                        $speed = $dlMatch.Groups['speed'].Value
                        $eta = $dlMatch.Groups['eta'].Value
                        
                        # Only update if progress changed significantly
                        if ([Math]::Abs($percent - $lastProgress) -ge 0.2 -or $percent -eq 100) {
                            Show-CustomDownloadProgress -Activity "Downloading" `
                                                      -Percentage $percent `
                                                      -TotalSize $size `
                                                      -Speed $speed `
                                                      -ETA $eta `
                                                      -FileName $currentFileName `
                                                      -Stage "download"
                            $lastProgress = $percent
                        }
                    }
                    # Parse merging
                    elseif ($line -match '\[Merger\]') {
                        $currentStage = "merge"
                        Show-CustomDownloadProgress -Activity "Merging" `
                                                  -Percentage 95 `
                                                  -FileName $currentFileName `
                                                  -Stage "merge"
                    }
                    # Parse audio extraction
                    elseif ($line -match '\[ExtractAudio\]') {
                        $currentStage = "process"
                        Show-CustomDownloadProgress -Activity "Extracting" `
                                                  -Percentage 90 `
                                                  -FileName $currentFileName `
                                                  -Stage "process"
                    }
                    # Parse conversion
                    elseif ($line -match '\[ffmpeg\]\s+Converting') {
                        Show-CustomDownloadProgress -Activity "Converting" `
                                                  -Percentage 92 `
                                                  -FileName $currentFileName `
                                                  -Stage "process"
                    }
                    # Parse subtitle embedding
                    elseif ($line -match '\[EmbedSubtitle\]') {
                        Show-CustomDownloadProgress -Activity "Processing" `
                                                  -Percentage 98 `
                                                  -FileName $currentFileName `
                                                  -Stage "process"
                    }
                    # Parse post-processing
                    elseif ($line -match '\[PostProcessor\]') {
                        Show-CustomDownloadProgress -Activity "Finalizing" `
                                                  -Percentage 99 `
                                                  -FileName $currentFileName `
                                                  -Stage "process"
                    }
                    # Show other important messages
                    elseif ($line -match '\[(youtube|info|warning)\]' -or 
                            $line -match 'Deleting original file' -or
                            $line -match 'has already been downloaded') {
                        # Don't show these lines to keep output clean
                    }
                }
            }
            
            $exitCode = $LASTEXITCODE
            
            # Clear progress line and show completion
            Write-Host "`r" + (" " * [Math]::Min($Host.UI.RawUI.WindowSize.Width, 120)) + "`r" -NoNewline
            
            if ($exitCode -eq 0) {
                Write-Host "✓ Download completed successfully!" -ForegroundColor Green
            } else {
                Write-Host "✗ Download completed with errors (Exit code: $exitCode)" -ForegroundColor Yellow
            }
            Write-Host ""
            
            return @{ 
                ExitCode = $exitCode
                Output = $outputLines.ToArray()
                Error = $errorLines.ToArray()
            }
        }
        finally {
            Set-Location $currentLocation
        }
    }
    catch {
        $errorMessage = "Failed to start yt-dlp process: $($_.Exception.Message)"
        Write-ErrorLog $errorMessage
        $errorLines.Add($errorMessage)
        
        # Clear any progress line
        Write-Host "`r" + (" " * [Math]::Min($Host.UI.RawUI.WindowSize.Width, 120)) + "`r" -NoNewline
        Write-Host "✗ Download failed!" -ForegroundColor Red
        Write-Host ""
        
        return @{ 
            ExitCode = -1
            Output = $outputLines.ToArray()
            Error = $errorLines.ToArray()
        }
    }
}

function Invoke-YtDlpWithProgress {
    param (
        [string]$YtDlpPath,
        [System.Collections.Generic.List[string]]$YtDlpArguments
    )

    if ($null -eq $YtDlpArguments) {
        Write-ErrorLog "Invoke-YtDlpWithProgress called with null arguments."
        return @{ ExitCode = -1; Output = @(); Error = @("Internal Script Error: Download arguments were not provided.") }
    }
    
    # Verify yt-dlp exists
    if (-not (Test-Path $YtDlpPath)) {
        Write-ErrorLog "yt-dlp.exe not found at: $YtDlpPath"
        return @{ ExitCode = -1; Output = @(); Error = @("yt-dlp.exe not found at: $YtDlpPath") }
    }

    $process = $null
    $outputLines = [System.Collections.Generic.List[string]]::new()
    $errorLines = [System.Collections.Generic.List[string]]::new()

    try {
        $process = New-Object System.Diagnostics.Process
        if ($null -eq $process) {
            throw "Failed to create Process object"
        }

        $process.StartInfo.FileName = $YtDlpPath
        $process.StartInfo.Arguments = $YtDlpArguments -join ' '
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $process.StartInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $process.StartInfo.WorkingDirectory = Split-Path $YtDlpPath -Parent

        # Add event handlers with proper error handling
        $outputAction = {
            if (-not [string]::IsNullOrWhiteSpace($_.Data)) {
                $line = $_.Data
                $outputLines.Add($line)

                $dlRegex = '\[download\]\s+(?<percent>[\d\.]+)%\s+of\s+(?:~)?(?<size>[\d\.]+\w+)(?:\s+at\s+(?<speed>[\d\.]+\w+\/s))?(?:\s+ETA\s+(?<eta>[\d:]+))?'
                $dlMatch = [regex]::Match($line, $dlRegex)

                $procRegex = '\[(?<process>\w+)\]'
                $procMatch = [regex]::Match($line, $procRegex)

                if ($dlMatch.Success) {
                    Show-DownloadProgress -Activity "Downloading" `
                                          -Percentage ([double]$dlMatch.Groups['percent'].Value) `
                                          -TotalSize $dlMatch.Groups['size'].Value `
                                          -Speed $dlMatch.Groups['speed'].Value `
                                          -ETA $dlMatch.Groups['eta'].Value
                } elseif ($procMatch.Success -and $procMatch.Groups['process'].Value -ne 'youtube') {
                    $processName = $procMatch.Groups['process'].Value
                    Show-DownloadProgress -Activity "$($processName)..."
                }
            }
        }

        $errorAction = {
            if (-not [string]::IsNullOrWhiteSpace($_.Data)) {
                $errorLines.Add($_.Data)
            }
        }

        # Register event handlers using simpler approach
        Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputAction | Out-Null
        Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorAction | Out-Null

        Write-Host "Starting yt-dlp process..." -ForegroundColor Yellow
        
        # Start the process with better error handling
        $started = $false
        try {
            $started = $process.Start()
        } catch {
            throw "Failed to start process: $_"
        }
        
        if (-not $started) {
            throw "Process.Start() returned false. The process could not be started."
        }
        
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        $process.WaitForExit()

        Write-Host ("`r".PadRight($Host.UI.RawUI.WindowSize.Width)) -NoNewline
        Write-Host "`rDownload task finished." -ForegroundColor Green
        Write-Host ""

        return @{ 
            ExitCode = $process.ExitCode
            Output = $outputLines.ToArray()
            Error = $errorLines.ToArray()
        }

    } catch {
        $errorMessage = "Failed to start yt-dlp process: $($_.Exception.Message)"
        Write-ErrorLog $errorMessage
        $errorLines.Add($errorMessage)
        
        return @{ 
            ExitCode = -1
            Output = $outputLines.ToArray()
            Error = $errorLines.ToArray()
        }
    } finally {
        # Clean up event handlers
        Get-EventSubscriber | Where-Object SourceObject -eq $process | Unregister-Event -Force
        
        if ($process) {
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
                $process.Dispose()
            } catch {
                Write-ErrorLog "Error disposing process: $($_.Exception.Message)"
            }
        }
    }
}

function Show-VideoDetails {
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$VideoInfo
    )

    Write-Host ""
    Write-Host "╭───────────────────────────────────────────────────────────────────────────────╮" -ForegroundColor Cyan
    Write-Host "│                             VIDEO INFORMATION                                 │" -ForegroundColor Cyan
    Write-Host "╰───────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor Cyan
    Write-Host ""
    
    if ($VideoInfo.title) { 
        Write-Host " 📌 Title         : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.title)" -ForegroundColor White 
    }
    
    if ($VideoInfo.webpage_url) { 
        Write-Host " 🔗 URL           : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.webpage_url)" -ForegroundColor DarkGray 
    }
    
    if ($VideoInfo.uploader) { 
        Write-Host " 👤 Uploader      : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.uploader)" -ForegroundColor White 
    }
    
    if ($VideoInfo.channel -and $VideoInfo.channel -ne $VideoInfo.uploader) { 
        Write-Host " 📺 Channel       : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.channel)" -ForegroundColor White 
    }
    
    if ($VideoInfo.upload_date) {
        try {
            $year = $VideoInfo.upload_date.Substring(0,4)
            $month = $VideoInfo.upload_date.Substring(4,2)
            $day = $VideoInfo.upload_date.Substring(6,2)
            $uploadDateObject = Get-Date -Year $year -Month $month -Day $day
            Write-Host " 📅 Upload Date   : " -NoNewline -ForegroundColor Yellow
            Write-Host "$($uploadDateObject.ToString("yyyy-MM-dd (dddd)"))" -ForegroundColor White
        } catch {
            Write-Host " 📅 Upload Date   : " -NoNewline -ForegroundColor Yellow
            Write-Host "$($VideoInfo.upload_date)" -ForegroundColor Yellow
        }
    }
    
    if ($VideoInfo.duration_string) { 
        Write-Host " ⏱️ Duration      : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.duration_string)" -ForegroundColor White 
    }
    elseif ($VideoInfo.duration) { 
        Write-Host " ⏱️ Duration      : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.duration) seconds" -ForegroundColor White 
    }

    if ($null -ne $VideoInfo.view_count) { 
        Write-Host " 👁️ Views         : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.view_count.ToString("N0"))" -ForegroundColor Green 
    }
    
    if ($null -ne $VideoInfo.like_count) { 
        Write-Host " 👍 Likes         : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.like_count.ToString("N0"))" -ForegroundColor Green 
    }
    else {
        Write-Host " 👍 Likes         : " -NoNewline -ForegroundColor Yellow
        Write-Host "N/A" -ForegroundColor Gray
    }
    
    if ($VideoInfo.live_status) { 
        Write-Host " 🔴 Live Status   : " -NoNewline -ForegroundColor Yellow
        $statusColor = if ($VideoInfo.live_status -eq "is_live") { "Red" } 
                      elseif ($VideoInfo.live_status -eq "was_live") { "DarkRed" } 
                      else { "White" }
        Write-Host "$($VideoInfo.live_status)" -ForegroundColor $statusColor 
    }
    
    if ($null -ne $VideoInfo.age_limit -and $VideoInfo.age_limit -gt 0) { 
        Write-Host " 🔞 Age Limit     : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.age_limit)+" -ForegroundColor Red 
    }

    if ($VideoInfo.categories -and $VideoInfo.categories.Count -gt 0) { 
        Write-Host " 🏷️ Categories    : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($VideoInfo.categories -join ', ')" -ForegroundColor White 
    }

    if ($VideoInfo.tags -and $VideoInfo.tags.Count -gt 0) {
        $tagsString = $VideoInfo.tags -join ', '
        if ($tagsString.Length -gt 100) { $tagsString = $tagsString.Substring(0, 100) + "..." }
        Write-Host " 🔖 Tags          : " -NoNewline -ForegroundColor Yellow
        Write-Host "$tagsString" -ForegroundColor DarkGray
    }
    
    if ($VideoInfo.description) {
        Write-Host ""
        Write-Host " 📝 Description:" -ForegroundColor Yellow
        Write-Host " ───────────────" -ForegroundColor Gray
        $descriptionLines = $VideoInfo.description -split '\r?\n'
        $maxDescLines = $settings.advanced.max_description_lines
        for ($i = 0; $i -lt [System.Math]::Min($descriptionLines.Count, $maxDescLines); $i++) {
            if ($descriptionLines[$i].Trim().Length -gt 0) {
                $line = $descriptionLines[$i]
                if ($line.Length -gt 76) { $line = $line.Substring(0, 76) + "..." }
                Write-Host "    $line" -ForegroundColor White
            }
        }
        if ($descriptionLines.Count -gt $maxDescLines) {
            Write-Host "    [...]" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "" 
}


if ($Help) {
    Show-ScriptHelp
    exit 0
}

# Load settings with error handling
try {
    Load-Settings
} catch {
    Show-EnhancedError -TechnicalError $_.Exception.Message -Context "Failed to load settings configuration"
    Write-Host "Using default settings due to configuration error." -ForegroundColor Yellow
}

# Set up proxy configuration
Set-ProxyConfiguration

# Initialize database
Initialize-Database

$ytDlpPath = Join-Path $scriptDir "yt-dlp.exe"
$ffmpegPath = Join-Path $scriptDir "ffmpeg.exe"

# Check and update yt-dlp
Update-YtDlp -YtDlpPath $ytDlpPath

# Check and update ffmpeg
Update-Ffmpeg -FfmpegPath $ffmpegPath

if ($env:PATH -notlike "*;$($scriptDir);*") {
    $env:PATH = "$($scriptDir);$($env:PATH)"
    Write-ErrorLog "Added script directory to session PATH: $scriptDir"
}

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

# Display welcome banner
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                               ║" -ForegroundColor Cyan
Write-Host "║                      YouTube Downloader Pro by MBNPRO                         ║" -ForegroundColor Yellow
Write-Host "║                                                                               ║" -ForegroundColor Cyan
Write-Host "║            The Ultimate YouTube Video, Audio & Thumbnail Downloader           ║" -ForegroundColor White
Write-Host "║                                                                               ║" -ForegroundColor Cyan
Write-Host "║                        Version 2.0 - Enhanced Edition                         ║" -ForegroundColor Gray
Write-Host "║                                                                               ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Quick start guide
Write-Host "⚡ QUICK START GUIDE" -ForegroundColor Green
Write-Host "═══════════════════" -ForegroundColor Gray
Write-Host ""
Write-Host "  1️⃣  Paste YouTube video URL and press Enter" -ForegroundColor White
Write-Host "  2️⃣  Choose download format from the displayed options" -ForegroundColor White
Write-Host "  3️⃣  Wait for download to complete" -ForegroundColor White
Write-Host "  4️⃣  Find your file in the Downloaded folder" -ForegroundColor White
Write-Host ""

# Available commands
Write-Host "📋 AVAILABLE COMMANDS" -ForegroundColor Yellow
Write-Host "════════════════════" -ForegroundColor Gray
Write-Host ""
Write-Host "  📖 " -NoNewline; Write-Host "help, -h     " -NoNewline -ForegroundColor Cyan; Write-Host ": Show detailed help and guide" -ForegroundColor Gray
Write-Host "  🚪 " -NoNewline; Write-Host "exit         " -NoNewline -ForegroundColor Cyan; Write-Host ": Exit the program" -ForegroundColor Gray
Write-Host "  🗑️  " -NoNewline; Write-Host "clear-cache  " -NoNewline -ForegroundColor Cyan; Write-Host ": Clear video information cache" -ForegroundColor Gray
Write-Host ""

# Status bar
Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "💡 Tip: Configure settings.json for proxy, cookies, and advanced options" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# Use settings for directory paths
$tempDir = Join-Path $scriptDir $settings.download.temp_directory
$downloadedDir = Join-Path $scriptDir $settings.download.output_directory
$videoOutputDir = Join-Path $downloadedDir $settings.download.video_subdirectory
$audioOutputDir = Join-Path $downloadedDir $settings.download.audio_subdirectory
$coversOutputDir = Join-Path $downloadedDir $settings.download.covers_subdirectory

Initialize-Directory $tempDir
Initialize-Directory $downloadedDir
Initialize-Directory $videoOutputDir
Initialize-Directory $audioOutputDir
Initialize-Directory $coversOutputDir

$continueWithNewLink = 'y' 

do { 
    Write-Host "╭──────────────────────────────╮" -ForegroundColor Cyan
    Write-Host "│     🎯 MAIN MENU 🎯      │" -ForegroundColor Cyan
    Write-Host "╰──────────────────────────────╯" -ForegroundColor Cyan
    Write-Host ""
    $userInputUrl = Get-ValidatedUserInput -Prompt "📥 Enter YouTube URL (or command):" -InputType "url" -MaxAttempts 5
    
    if ($null -eq $userInputUrl) {
        Write-Host "No valid input received. Exiting..." -ForegroundColor Red
        $continueWithNewLink = 'n'
        continue
    }

    if ($userInputUrl -eq 'exit') {
        $continueWithNewLink = 'n'
        continue
    }

    if ($userInputUrl -match '^\-h$' -or $userInputUrl -match '^\-{1,2}help$' -or $userInputUrl -eq 'help') {
        Show-ScriptHelp
        continue
    }
    
    if ($userInputUrl -eq 'clear-cache') {
        Clear-VideoCache
        continue
    }
    
    $currentUrl = $userInputUrl 
    Write-ErrorLog "Attempting to process URL: $currentUrl"
    
    # Always initialize cookie variables for each URL processing
    $cookieFilePath = Get-CookieFilePath
    $useCookies = [bool]$settings.cookies.use_cookies -and ($null -ne $cookieFilePath)
    
    # Check cache first
    $cachedVideoInfo = Get-VideoFromCache -Url $currentUrl
    if ($cachedVideoInfo) {
        Write-Host ""
        Write-Host "💾 Using cached video information for faster processing!" -ForegroundColor Green
        $videoInfo = $cachedVideoInfo.info
        Show-VideoDetails -VideoInfo $videoInfo
    } else {
        # Show processing message
        Write-Host ""
        Write-Host "🔍 Fetching video information, please wait..." -ForegroundColor Yellow
        
        # Initialize variables for retry logic
        $videoInfo = $null
        $maxRetries = [int]$settings.general.max_retries
        $retryCount = 0
        $useLogin = $false
        
        while ($retryCount -lt $maxRetries -and $null -eq $videoInfo) {
            $retryCount++
            if ($retryCount -gt 1) {
                Write-Host ""
                Write-Host "🔄 Retry attempt $retryCount of $maxRetries..." -ForegroundColor Yellow
            }
            
            # Attempt to get video info with timeout
            $result = Get-VideoInfoWithTimeout -Url $currentUrl -YtDlpPath $ytDlpPath -TimeoutSeconds $settings.general.request_timeout_seconds -UseCookies $useCookies -CookieFilePath $cookieFilePath
            
            if ($result.Success -and $result.ExitCode -eq 0) {
                # Success - parse the JSON
                try {
                    $videoInfo = ($result.Output -join [System.Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
                    Write-Host "Video information retrieved successfully!" -ForegroundColor Green
                    Write-ErrorLog "Successfully obtained and parsed JSON for $currentUrl"
                    
                    # Save to cache
                    Save-VideoToCache -Url $currentUrl -VideoInfo $videoInfo
                    
                    # Display video details
                    Show-VideoDetails -VideoInfo $videoInfo
                    break
                } catch {
                    $logMsg = "Failed to parse JSON for '$currentUrl'. JSON String: $($result.Output -join [System.Environment]::NewLine). Exception: $($_.Exception.Message)"
                    Write-ErrorLog $logMsg
                    
                    if ($retryCount -eq $maxRetries) {
                        Resolve-ScriptError -UserMessage "Received invalid video information from yt-dlp. The video might be unsupported or an internal error occurred." `
                                           -InternalLogMessage $logMsg
                        break
                    }
                }
            } else {
                # Failed - handle error
                $errorMessage = if ($result.Error) { $result.Error } else { "Unknown error occurred" }
                Write-ErrorLog "Failed to get video info for '$currentUrl'. Error: $errorMessage. Exit Code: $($result.ExitCode)"
                
                if ($retryCount -eq $maxRetries) {
                    # Show error handling options
                    $userChoice = Show-ErrorHandlingOptions -Url $currentUrl -ErrorMessage $errorMessage
                    
                    switch ($userChoice) {
                        "cookies" {
                            if ($cookieFilePath) {
                                $useCookies = $true
                                $retryCount = 0  # Reset retry count for cookie attempt
                                Write-Host "Retrying with cookie authentication..." -ForegroundColor Yellow
                            } else {
                                Write-Host "Cookie file not found. Please check settings.json configuration." -ForegroundColor Red
                                break
                            }
                        }
                        "login" {
                            $loginSuccess = Invoke-YouTubeLogin -Url $currentUrl
                            if ($loginSuccess) {
                                $retryCount = 0  # Reset retry count for login attempt
                                Write-Host "Retrying after login..." -ForegroundColor Yellow
                            } else {
                                Write-Host "Login failed. Please try manually or check settings." -ForegroundColor Red
                                break
                            }
                        }
                        "retry" {
                            $retryCount = 0  # Reset retry count for manual retry
                            Write-Host "Retrying with current settings..." -ForegroundColor Yellow
                        }
                        "new_url" {
                            break  # Exit inner loop to get new URL
                        }
                        "exit" {
                            $continueWithNewLink = 'n'
                            break
                        }
                        "configure_cookies" {
                            Write-Host "Please configure cookies in settings.json and restart the script." -ForegroundColor Yellow
                            break
                        }
                        default {
                            break
                        }
                    }
                    
                    if ($userChoice -in @("new_url", "exit", "configure_cookies")) {
                        break
                    }
                }
            }
        }
        
        # If we still don't have video info, continue to next iteration
        if ($null -eq $videoInfo) {
            continue
        }
    }

    $downloadAnotherFormatForSameUrl = 'y' 
    do { 

        $formats = $videoInfo.formats
        
        # Show the new detailed formats menu
        $menuOptions = Show-FormatsMenu -Formats $formats -VideoTitle $videoInfo.title
        
        $maxOption = $menuOptions.Count
        Write-Host ""
        $userSelectionInput = Get-ValidatedUserInput -Prompt "👉 Select an option:" -InputType "number" -MinValue 1 -MaxValue $maxOption -MaxAttempts 3
        Write-Host ""

        if ($null -eq $userSelectionInput) {
            Write-Host "No valid selection made. Returning to main menu..." -ForegroundColor Red
            break
        }
        
        $selectedOption = $menuOptions | Where-Object { $_.Number -eq $userSelectionInput }
        
        if (-not $selectedOption) {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            continue
        } 
            $ytdlpOutputTemplate = Join-Path -Path $scriptDir -ChildPath "Temp\%(title)s.%(ext)s" 
            $isVideoDownload = $false # Default to false
            $ytDlpArgsForDownload = $null
            $formatStringForDownload = "" # For filename prediction

            # Handle different selection types
            switch ($selectedOption.Type) {
                "cover" {
                    Write-Host "Preparing to download video cover..." -ForegroundColor Green
                    if ($videoInfo.thumbnail -or ($videoInfo.thumbnails -and $videoInfo.thumbnails.Count -gt 0)) {
                        $thumbnailUrl = $videoInfo.thumbnail 
                        
                        if ($videoInfo.thumbnails -and $videoInfo.thumbnails.Count -gt 0) {
                            $bestThumbnail = $videoInfo.thumbnails | Where-Object {$_.url} | Sort-Object -Property width, height -Descending | Select-Object -First 1
                            if ($bestThumbnail -and $bestThumbnail.url) {
                                $thumbnailUrl = $bestThumbnail.url
                                Write-ErrorLog "Selected best thumbnail URL: $thumbnailUrl (Resolution: $($bestThumbnail.width)x$($bestThumbnail.height))"
                            } else { Write-ErrorLog "Could not find a better thumbnail, using default: $thumbnailUrl" }
                        } else { Write-ErrorLog "No thumbnails array, using default thumbnail: $thumbnailUrl" }

                        if (-not $thumbnailUrl) {
                            Resolve-ScriptError -UserMessage "No valid thumbnail URL could be determined." -InternalLogMessage "Thumbnail URL null/empty."
                            continue 
                        }

                        $coverExtension = ([System.IO.Path]::GetExtension($thumbnailUrl)).Split('?')[0] 
                        if (-not $coverExtension -or $coverExtension.Length -gt 5 -or $coverExtension.Length -lt 2) { $coverExtension = ".jpg" } 

                        $baseCoverName = Convert-FileNameToComparable $videoInfo.title
                        $tempCoverFileName = $baseCoverName + $coverExtension
                        $finalCoverFileName = $baseCoverName + $coverExtension 

                        $tempCoverPath = Join-Path $tempDir $tempCoverFileName
                        $finalCoverPath = Join-Path $coversOutputDir $finalCoverFileName
                        
                        $counter = 1
                        while(Test-Path $finalCoverPath) { 
                            $finalCoverFileName = "$($baseCoverName)_$($counter)$($coverExtension)"
                            $finalCoverPath = Join-Path $coversOutputDir $finalCoverFileName
                            $counter++
                        }

                        try {
                            Write-Host "Downloading cover from: $thumbnailUrl" -ForegroundColor Yellow
                            
                            # Enhanced web request with better error handling and proxy support
                            $webRequestParams = @{
                                Uri = $thumbnailUrl
                                OutFile = $tempCoverPath
                                ErrorAction = "Stop"
                                UseBasicParsing = $true
                                TimeoutSec = 30
                                MaximumRetryCount = 3
                                RetryIntervalSec = 2
                            }
                            
                            # Add User-Agent to avoid blocking
                            $webRequestParams.Headers = @{
                                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                            }
                            
                            # Use proxy if configured
                            if ($env:HTTP_PROXY) {
                                $webRequestParams.Proxy = $env:HTTP_PROXY
                            }
                            
                            Invoke-WebRequest @webRequestParams
                            Write-Host "Cover downloaded to Temp: $tempCoverPath" -ForegroundColor Green

                            # Verify file was downloaded
                            if (-not (Test-Path $tempCoverPath) -or (Get-Item $tempCoverPath).Length -eq 0) {
                                throw "Downloaded file is missing or empty"
                            }

                            Move-Item -Path $tempCoverPath -Destination $finalCoverPath -Force -ErrorAction Stop
                            Write-Host "`nCover successfully downloaded and moved to:" -ForegroundColor Green
                            Write-Host "$finalCoverPath" -ForegroundColor Cyan
                            Write-ErrorLog "Successfully downloaded and moved cover '$finalCoverFileName' to '$finalCoverPath'."
                        } catch {
                            $logMsg = "Failed to download/move cover. URL:'$thumbnailUrl'. Temp:'$tempCoverPath'. Final:'$finalCoverPath' Exc: $($_.Exception.Message)"
                            Write-Host "Cover download failed. Trying alternative method..." -ForegroundColor Yellow
                            
                            # Alternative download method using yt-dlp
                            try {
                                Write-Host "Attempting cover download using yt-dlp..." -ForegroundColor Yellow
                                $coverArgs = @(
                                    "--write-thumbnail",
                                    "--skip-download",
                                    "--no-warnings",
                                    "-o", $ytdlpOutputTemplate,
                                    $currentUrl
                                )
                                
                                # Add enhanced headers and proxy
                                $coverArgs += "--no-check-certificate"
                                $coverArgs += "--user-agent"
                                $coverArgs += "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                                
                                if ($useCookies -and $cookieFilePath) {
                                    $coverArgs += "--cookies"
                                    $coverArgs += $cookieFilePath
                                }
                                
                                if ($env:HTTP_PROXY) {
                                    $coverArgs += "--proxy"
                                    $coverArgs += $env:HTTP_PROXY
                                }
                                
                                $coverResult = & $ytDlpPath @coverArgs 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    # Find the downloaded thumbnail file
                                    $thumbnailFiles = Get-ChildItem -Path $tempDir -File | Where-Object { $_.Name -like "*$($baseCoverName)*" -and ($_.Extension -eq ".jpg" -or $_.Extension -eq ".png" -or $_.Extension -eq ".webp") }
                                    if ($thumbnailFiles) {
                                        $downloadedThumb = $thumbnailFiles[0]
                                        $finalCoverPath = Join-Path $coversOutputDir "$($baseCoverName)$($downloadedThumb.Extension)"
                                        Move-Item -Path $downloadedThumb.FullName -Destination $finalCoverPath -Force
                                        Write-Host "`nCover successfully downloaded using yt-dlp:" -ForegroundColor Green
                                        Write-Host "$finalCoverPath" -ForegroundColor Cyan
                                        Write-ErrorLog "Successfully downloaded cover using yt-dlp: $finalCoverPath"
                                    } else {
                                        throw "yt-dlp completed but no thumbnail file found"
                                    }
                                } else {
                                    throw "yt-dlp failed with exit code: $LASTEXITCODE. Output: $($coverResult -join ' ')"
                                }
                            } catch {
                                $fallbackLogMsg = "Both cover download methods failed. Direct: $logMsg. yt-dlp: $($_.Exception.Message)"
                                Resolve-ScriptError -UserMessage "Could not download video cover using any method. Check debug.txt." -InternalLogMessage $fallbackLogMsg
                            }
                        }
                    } else {
                        Write-Warning "No thumbnail URL found in video information."
                        Write-ErrorLog "Attempted cover download, but no thumbnail URL in videoInfo."
                    }
                }
                
                "best" {
                    $formatStringForDownload = "bestvideo+bestaudio/best"
                    Write-Host "Preparing to download best quality (merging best video + best audio)..." -ForegroundColor Green
                    
                    $ytDlpArgsForDownload = New-DownloadArguments -FfmpegPath $ffmpegPath -OutputTemplate $ytdlpOutputTemplate -Format $formatStringForDownload -Url $currentUrl -Type "video" -UseCookies $useCookies -CookieFilePath $cookieFilePath
                    
                    $isVideoDownload = $true
                }

                "combined" {
                    $formatStringForDownload = $selectedOption.Format.format_id
                    Write-Host "Preparing to download combined format $formatStringForDownload..." -ForegroundColor Green
                    
                    $ytDlpArgsForDownload = New-DownloadArguments -FfmpegPath $ffmpegPath -OutputTemplate $ytdlpOutputTemplate -Format $formatStringForDownload -Url $currentUrl -Type "video" -UseCookies $useCookies -CookieFilePath $cookieFilePath

                    $isVideoDownload = $true
                }
                
                "specific_video" {
                    $formatId = $selectedOption.Format.format_id
                    $formatStringForDownload = "$($formatId)+bestaudio/best"
                    Write-Host "Preparing to download video format $formatId (merged with best audio)..." -ForegroundColor Green
                    
                    $ytDlpArgsForDownload = New-DownloadArguments -FfmpegPath $ffmpegPath -OutputTemplate $ytdlpOutputTemplate -Format $formatStringForDownload -Url $currentUrl -Type "video" -UseCookies $useCookies -CookieFilePath $cookieFilePath
                    
                    $isVideoDownload = $true
                }
                
                "mp3_conversion" {
                    $bitrate = $selectedOption.Bitrate
                    $formatStringForDownload = "bestaudio/best"
                    Write-Host "Preparing to download best audio and convert to MP3 at $($bitrate)k..." -ForegroundColor Green
                    
                    $ytDlpArgsForDownload = New-DownloadArguments -FfmpegPath $ffmpegPath -OutputTemplate $ytdlpOutputTemplate -Format $formatStringForDownload -Url $currentUrl -Type "audio" -Bitrate $bitrate -UseCookies $useCookies -CookieFilePath $cookieFilePath
                    
                    $isVideoDownload = $false
                }

                "specific_audio" {
                    $formatId = $selectedOption.Format.format_id
                    $formatStringForDownload = $formatId
                    Write-Host "Preparing to download audio format $formatId and convert to MP3..." -ForegroundColor Green
                    
                    $ytDlpArgsForDownload = New-DownloadArguments -FfmpegPath $ffmpegPath -OutputTemplate $ytdlpOutputTemplate -Format $formatStringForDownload -Url $currentUrl -Type "audio_specific" -UseCookies $useCookies -CookieFilePath $cookieFilePath
                    
                    $isVideoDownload = $false
                }
                
                default {
                    Write-Host "Unknown selection type: $($selectedOption.Type)" -ForegroundColor Red
                    continue
                }
            }
            
                            # Common download execution logic for video/audio (not cover)
            if ($selectedOption.Type -ne "cover") {
                if ($null -eq $ytDlpArgsForDownload) {
                    Resolve-ScriptError -UserMessage "Could not generate download arguments for the selected option." `
                                       -InternalLogMessage "Internal logic error: ytDlpArgsForDownload was null before calling Invoke-YtDlpWithProgress."
                    continue
                }

                # Cookies are now handled directly in New-DownloadArguments function

                Write-ErrorLog "Executing Download: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' ')"
                                    # Try simple method first to diagnose the issue
                    $downloadResult = Invoke-YtDlpSimple -YtDlpPath $ytDlpPath -YtDlpArguments $ytDlpArgsForDownload
                
                $exitCodeDownload = $downloadResult.ExitCode
                $downloadProcessOutputLines = $downloadResult.Output
                
                if ($downloadResult.Error.Count -gt 0) {
                     $errorLogMessage = $downloadResult.Error -join [System.Environment]::NewLine
                     Write-ErrorLog "Errors captured during yt-dlp execution: $errorLogMessage"
                }
                
                if ($exitCodeDownload -eq 0) {
                    Write-ErrorLog "yt-dlp download process completed successfully. Exit Code: $exitCodeDownload."
                    $downloadOutputStringForParsing = $downloadProcessOutputLines -join [System.Environment]::NewLine
                    $downloadedFileInTemp = $null
                    $tempFilesList = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue
                    
                    # Determine expected file extension
                    $expectedFileExtension = if ($isVideoDownload) { ".mp4" } else { ".mp3" }
                    
                    Write-ErrorLog "Attempting to find downloaded file. Method 1: Based on videoInfo.title."
                    if ($videoInfo -and $videoInfo.title) {
                        $normalizedExpectedNameFromTitle = Convert-FileNameToComparable ($videoInfo.title + $expectedFileExtension)
                        Write-ErrorLog "Method 1: Normalized expected name from title: `"$normalizedExpectedNameFromTitle`""
                        if ($tempFilesList) {
                            foreach ($fileInTempDir in $tempFilesList) {
                                if ((Convert-FileNameToComparable $fileInTempDir.Name) -eq $normalizedExpectedNameFromTitle) {
                                    $downloadedFileInTemp = $fileInTempDir.FullName
                                    Write-ErrorLog "Method 1: File found by title-based normalized comparison: $downloadedFileInTemp"
                                    break
                                }
                            }
                        }
                    }
                    
                    if (-not $downloadedFileInTemp) {
                        Write-ErrorLog "Methods 1 failed. Attempting Method 2: Based on parsing output."
                        
                        if ($isVideoDownload) {
                            $patternForMethod2 = [regex]'\[Merger\] Merging formats into "(?<FileNameFromOutput>.*?)"'
                            $matchMethod2 = $patternForMethod2.Match($downloadOutputStringForParsing)
                            if (-not $matchMethod2.Success) {
                                $patternForMethod2 = [regex]'\[ffmpeg\] Destination: (?<FileNameFromOutput>.*?)$'
                                $matchMethod2 = $patternForMethod2.Match($downloadOutputStringForParsing)
                            }
                        } else {
                            $patternForMethod2 = [regex]'\[ExtractAudio\] Destination: (?<FileNameFromOutput>.*?)$'
                            $matchMethod2 = $patternForMethod2.Match($downloadOutputStringForParsing)
                            if (-not $matchMethod2.Success) {
                                $patternForMethod2 = [regex]'\[ffmpeg\] Destination: (?<FileNameFromOutput>.*?)$'
                                $matchMethod2 = $patternForMethod2.Match($downloadOutputStringForParsing)
                            }
                        }
                        
                        if ($matchMethod2.Success) {
                            $filePathFromRegex = $matchMethod2.Groups["FileNameFromOutput"].Value.Trim()
                            Write-ErrorLog "Method 2: Using pattern '$($patternForMethod2.ToString())'. Found path: '$filePathFromRegex'."
                            if (Test-Path $filePathFromRegex) {
                                $downloadedFileInTemp = $filePathFromRegex
                                Write-ErrorLog "Method 2: File confirmed by regex pattern: $downloadedFileInTemp"
                            }
                        }
                    }
                    
                    if ($downloadedFileInTemp -and (Test-Path $downloadedFileInTemp)) {
                        $fileNameOnly = Split-Path $downloadedFileInTemp -Leaf
                        $destinationDir = if ($isVideoDownload) { $videoOutputDir } else { $audioOutputDir }
                        $destinationPath = Join-Path $destinationDir $fileNameOnly
                        
                        Write-ErrorLog "Attempting to move '$fileNameOnly' from '$downloadedFileInTemp' to '$destinationDir'..."
                        try {
                            Move-Item -Path $downloadedFileInTemp -Destination $destinationPath -Force -ErrorAction Stop
                            $fileType = if ($isVideoDownload) { "Video" } else { "Audio" }
                            $fileIcon = if ($isVideoDownload) { "🎥" } else { "🎵" }
                            Write-Host ""
                            Write-Host "✅ SUCCESS!" -ForegroundColor Green
                            Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
                            Write-Host "${fileIcon} ${fileType}: " -NoNewline -ForegroundColor Yellow
                            Write-Host "$fileNameOnly" -ForegroundColor White
                            Write-Host "📁 Location: " -NoNewline -ForegroundColor Yellow
                            Write-Host "$destinationPath" -ForegroundColor Cyan
                            Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
                            Write-ErrorLog "Successfully moved $fileType '$downloadedFileInTemp' to '$destinationPath'."
                            
                            # Handle subtitles for video downloads
                            if ($isVideoDownload) {
                                $baseVideoNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($fileNameOnly)
                                $subtitleFiles = Get-ChildItem -Path $tempDir -Filter "$($baseVideoNameWithoutExt)*.srt" -File -ErrorAction SilentlyContinue
                                if ($subtitleFiles) {
                                    foreach ($subFile in $subtitleFiles) {
                                        $subDestinationPath = Join-Path $videoOutputDir $subFile.Name
                                        try {
                                            Move-Item -Path $subFile.FullName -Destination $subDestinationPath -Force -ErrorAction Stop
                                            Write-Host "Subtitle file '$($subFile.Name)' moved to '$videoOutputDir'" -ForegroundColor Cyan
                                            Write-ErrorLog "Successfully moved subtitle '$($subFile.Name)' to '$subDestinationPath'."
                                        } catch {
                                            $logMsgSub = "Move-Item (Subtitle) failed. Source: '$($subFile.FullName)', Dest: '$subDestinationPath'. Exception: $($_.Exception.ToString())"
                                            Write-ErrorLog $logMsgSub
                                            Write-Warning "Failed to move subtitle file '$($subFile.Name)'. It may still be in '$tempDir'."
                                        }
                                    }
                                }
                            }
                        } catch {
                            $logMsg = "Move-Item failed. Source: '$downloadedFileInTemp', Dest: '$destinationPath'. Exception: $($_.Exception.ToString())"
                            Resolve-ScriptError -UserMessage "Failed to move the downloaded file from Temp to '$destinationDir'. It might be in 'Temp'." `
                                               -InternalLogMessage $logMsg
                        }
                    } else {
                        $logMsg = "yt-dlp download completed (Exit Code $exitCodeDownload), but script couldn't find the final file. Check 'Temp' folder."
                        Resolve-ScriptError -UserMessage "Download seemed to complete, but script couldn't find file in 'Temp' to move. Check 'Temp' folder." `
                                           -InternalLogMessage $logMsg
                        if ($tempFilesList) {
                            Write-Host "Files currently in '$tempDir': $( ($tempFilesList).Name -join ', ' )" -ForegroundColor Yellow
                        }
                    }
                } else {
                    $logMsg = "yt-dlp download failed. Exit Code: $exitCodeDownload. URL: $currentUrl. Output: $($downloadProcessOutputLines -join [System.Environment]::NewLine)"
                    Resolve-ScriptError -UserMessage "Download with yt-dlp failed. Please check the console output above for errors." `
                                       -InternalLogMessage $logMsg
                }
            }



        Write-Host ""
        Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        $userResponseSameUrl = Get-ValidatedUserInput -Prompt "🔄 Download another format for THIS video? (y/n):" -InputType "yesno" -MaxAttempts 3
        if ($userResponseSameUrl -eq 'n' -or $null -eq $userResponseSameUrl) {
            $downloadAnotherFormatForSameUrl = 'n' 
        }

    } while ($downloadAnotherFormatForSameUrl.ToLower() -eq 'y') 

    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    $userContinueChoiceWithNewLink = Get-ValidatedUserInput -Prompt "🆕 Download from a NEW YouTube URL? (y/n):" -InputType "yesno" -MaxAttempts 3
    if ($userContinueChoiceWithNewLink -eq 'n' -or $null -eq $userContinueChoiceWithNewLink) {
        $continueWithNewLink = 'n' 
    }

} while ($continueWithNewLink.ToLower() -eq 'y') 

# Cleanup temporary files if enabled
if ([bool]$settings.advanced.cleanup_temp_files) {
    try {
        $tempFiles = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue
        if ($tempFiles) {
            foreach ($file in $tempFiles) {
                Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Cleaned up temporary files." -ForegroundColor Green
            Write-ErrorLog "Cleaned up $($tempFiles.Count) temporary files"
        }
    } catch {
        Write-ErrorLog "Failed to cleanup temporary files: $($_.Exception.Message)"
    }
}

$Host.UI.RawUI.BackgroundColor = $originalBackground
$Host.UI.RawUI.ForegroundColor = $originalForeground
Clear-Host

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                                ║" -ForegroundColor Cyan
Write-Host "║                              Thank you for using                               ║" -ForegroundColor Yellow
Write-Host "║                       YouTube Downloader Pro by MBNPRO                         ║" -ForegroundColor White
Write-Host "║                                                                                ║" -ForegroundColor Cyan
Write-Host "║                               See you next time!                               ║" -ForegroundColor Green
Write-Host "║                                                                                ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-ErrorLog "Script session ended gracefully."