param (
    [Alias('h')]
    [switch]$Help
)

# --- Script Wide Settings ---
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = $PSScriptRoot
$DebugLogPath = Join-Path $scriptDir "debug.txt"

$originalBackground = $Host.UI.RawUI.BackgroundColor
$originalForeground = $Host.UI.RawUI.ForegroundColor

# --- Function Definitions ---

function Write-ErrorLog {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    try {
        Add-Content -Path $DebugLogPath -Value $logMessage -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to debug log: $($_.Exception.Message)"
    }
}

function Resolve-ScriptError {
    param (
        [string]$UserMessage,
        [string]$InternalLogMessage,
        [switch]$IsCritical = $false
    )
    Write-Host "`n-------------------- SCRIPT ERROR --------------------" -ForegroundColor Red
    Write-Host $UserMessage -ForegroundColor Red
    Write-Host "`nAn error was logged to: $DebugLogPath" -ForegroundColor Yellow
    Write-Host "Please send this 'debug.txt' file and a description of what you were doing" -ForegroundColor Yellow
    Write-Host "(e.g., the YouTube link used, and the selected quality)" -ForegroundColor Yellow
    Write-Host "to MBNPRO on Telegram: https://t.me/mbnproo" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------" -ForegroundColor Red
    Write-Host ""
    Write-ErrorLog "UserNotified: `"$UserMessage`" --- InternalLog: `"$InternalLogMessage`""

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
    Write-Host "--------------------------- SCRIPT HELP ---------------------------" -ForegroundColor Yellow
    Write-Host " syd.ps1 - YouTube Downloader by MBNPRO" -ForegroundColor Cyan
    Write-Host "---------------------------------------------------------------------"
    Write-Host " Description: Downloads videos (merged with best audio, with subtitles), audio only, or covers from YouTube."
    Write-Host " Usage (interactive): Just run .\syd.ps1 and follow prompts."
    Write-Host " Usage (command line help): .\syd.ps1 -Help (or -h)"
    Write-Host ""
    Write-Host " Main Prompts:" -ForegroundColor Green
    Write-Host "   - Enter YouTube Link: Paste the full YouTube video URL."
    Write-Host "   - 'exit': Type 'exit' at the link prompt to quit the script."
    Write-Host "   - '-h' or 'help': Type at link prompt to see this help again."
    Write-Host ""
    Write-Host " Features:" -ForegroundColor Green
    Write-Host "   - Displays detailed video information before quality selection."
    Write-Host "   - Video Download: Lists all available video resolutions, saved as MP4."
    Write-Host "     - Video merged with best audio."
    Write-Host "     - English and Farsi subtitles downloaded, embedded in video, and saved as separate .srt files (if available)."
    Write-Host "   - Audio Download: Saves best available audio as MP3."
    Write-Host "   - Cover Download: Saves to 'Downloaded\Covers'."
    Write-Host "   - Shows approximate file sizes before download."
    Write-Host "   - Temporary Files: Uses 'Temp' folder during download."
    Write-Host "   - Auto-Install: Downloads yt-dlp and ffmpeg if missing."
    Write-Host "   - Logging: Records errors and actions in 'debug.txt'."
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Yellow
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
    param ([string]$FileName)
    $converted = $FileName.Replace('：', ':').Replace('｜', '|').Replace('？', '?').Replace('＜', '<').Replace('＞', '>').Replace('＂', '"').Replace('＊', '*').Replace('＼', '\').Replace('／', '/')

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() + [System.IO.Path]::GetInvalidPathChars()
    $invalidCharsRegexPattern = ($invalidChars | ForEach-Object {[System.Text.RegularExpressions.Regex]::Escape($_)}) -join '|'

    if ($invalidCharsRegexPattern) {
        $converted = $converted -replace $invalidCharsRegexPattern, '_'
    }
    return $converted
}

function Format-Bytes {
    param ($bytes)
    if ($null -eq $bytes -or $bytes -lt 0) { return "" }
    $suffixes = "Bytes", "KB", "MB", "GB", "TB", "PB"
    $order = 0
    [double]$bytesDouble = $bytes
    while ($bytesDouble -ge 1024 -and $order -lt ($suffixes.Length - 1)) {
        $bytesDouble /= 1024
        $order++
    }
    return "{0:N2} {1}" -f $bytesDouble, $suffixes[$order]
}

function Show-VideoDetails {
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$VideoInfo
    )

    Write-Host "`n--- Video Information ---" -ForegroundColor Green
    if ($VideoInfo.title) { Write-Host " Title          : $($VideoInfo.title)" -ForegroundColor White }
    if ($VideoInfo.webpage_url) { Write-Host " URL            : $($VideoInfo.webpage_url)" -ForegroundColor White }
    if ($VideoInfo.uploader) { Write-Host " Uploader       : $($VideoInfo.uploader)" -ForegroundColor White }
    if ($VideoInfo.uploader_url) { Write-Host " Uploader URL   : $($VideoInfo.uploader_url)" -ForegroundColor White }
    if ($VideoInfo.channel -and $VideoInfo.channel -ne $VideoInfo.uploader) { Write-Host " Channel        : $($VideoInfo.channel)" -ForegroundColor White } 
    if ($VideoInfo.channel_url -and $VideoInfo.channel_url -ne $VideoInfo.uploader_url) { Write-Host " Channel URL    : $($VideoInfo.channel_url)" -ForegroundColor White } 
    
    if ($VideoInfo.upload_date) {
        try {
            # Date is YYYYMMDD
            $year = $VideoInfo.upload_date.Substring(0,4)
            $month = $VideoInfo.upload_date.Substring(4,2)
            $day = $VideoInfo.upload_date.Substring(6,2)
            $uploadDateObject = Get-Date -Year $year -Month $month -Day $day
            Write-Host " Upload Date    : $($uploadDateObject.ToString("yyyy-MM-dd (dddd)"))" -ForegroundColor White
        } catch {
            Write-Host " Upload Date    : $($VideoInfo.upload_date) (raw, format error)" -ForegroundColor Yellow
        }
    }
    if ($VideoInfo.duration_string) { Write-Host " Duration       : $($VideoInfo.duration_string)" -ForegroundColor White }
    elseif ($VideoInfo.duration) { Write-Host " Duration (sec) : $($VideoInfo.duration.ToString("N0"))" -ForegroundColor White }

    if ($null -ne $VideoInfo.view_count) { Write-Host " Views          : $($VideoInfo.view_count.ToString("N0"))" -ForegroundColor White }
    if ($null -ne $VideoInfo.like_count) { Write-Host " Likes          : $($VideoInfo.like_count.ToString("N0"))" -ForegroundColor White }
    else {Write-Host " Likes          : Not available / hidden" -ForegroundColor Gray}
    
    if ($VideoInfo.live_status) { Write-Host " Live Status    : $($VideoInfo.live_status)" -ForegroundColor White }
    if ($null -ne $VideoInfo.average_rating) { Write-Host " Average Rating : $($VideoInfo.average_rating.ToString("F2")) / 5.00" -ForegroundColor White }
    if ($null -ne $VideoInfo.age_limit) { Write-Host " Age Limit      : $($VideoInfo.age_limit)" -ForegroundColor White }

    if ($VideoInfo.categories -and $VideoInfo.categories.Count -gt 0) { Write-Host " Categories     : $($VideoInfo.categories -join ', ')" -ForegroundColor White }
    else {Write-Host " Categories     : None" -ForegroundColor Gray}

    if ($VideoInfo.tags -and $VideoInfo.tags.Count -gt 0) {
        $tagsString = $VideoInfo.tags -join ', '
        if ($tagsString.Length -gt 120) { $tagsString = $tagsString.Substring(0, 120) + "..." } # Truncate long tags string
        Write-Host " Tags           : $tagsString" -ForegroundColor White
    } else {
        Write-Host " Tags           : None" -ForegroundColor Gray
    }
    
    if ($VideoInfo.description) {
        Write-Host " Description    :" -ForegroundColor White
        $descriptionLines = $VideoInfo.description -split '\r?\n'
        $maxDescLines = 5 
        for ($i = 0; $i -lt [System.Math]::Min($descriptionLines.Count, $maxDescLines); $i++) {
            if ($descriptionLines[$i].Trim().Length -gt 0) { # Avoid printing blank lines from description
                 Write-Host "   $($descriptionLines[$i])" -ForegroundColor White
            } else {
                # If we skip a blank line, adjust max lines displayed if needed, or just let it be fewer.
                # For simplicity, just skip printing it.
            }
        }
        if ($descriptionLines.Count -gt $maxDescLines) {
            Write-Host "   ..." -ForegroundColor Gray
        }
    } else {
         Write-Host " Description    : None" -ForegroundColor Gray
    }
    Write-Host "-------------------------" -ForegroundColor Green
    Write-Host "" 
}


if ($Help) {
    Show-ScriptHelp
    exit 0
}

$ytDlpPath = Join-Path $scriptDir "yt-dlp.exe"
$ffmpegPath = Join-Path $scriptDir "ffmpeg.exe"

if (-not (Test-Path $ytDlpPath)) {
    Write-Host "yt-dlp.exe not found. Downloading..." -ForegroundColor Yellow
    $ytDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
    try {
        Write-Host "Downloading from: $ytDlpUrl" -Verbose
        Invoke-WebRequest -Uri $ytDlpUrl -OutFile $ytDlpPath -ErrorAction Stop -Verbose
        Write-Host "yt-dlp downloaded successfully." -ForegroundColor Green
        Write-ErrorLog "yt-dlp.exe downloaded successfully."
    } catch {
        Resolve-ScriptError -UserMessage "Failed to download yt-dlp.exe. Check your internet connection and ensure the URL is accessible: $ytDlpUrl" `
                           -InternalLogMessage "Invoke-WebRequest failed for yt-dlp.exe. URL: $ytDlpUrl. Exception: $($_.Exception.Message)" `
                           -IsCritical $true
    }
}

if (-not (Test-Path $ffmpegPath)) {
    Write-Host "ffmpeg.exe not found. Downloading..." -ForegroundColor Yellow
    $ffmpegZipUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    $tempZipPath = Join-Path $env:TEMP "ffmpeg_syd_temp.zip"
    $tempExtractPath = Join-Path $env:TEMP "ffmpeg_syd_extract"

    if (Test-Path $tempExtractPath) { Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    try {
        Write-Host "Downloading ffmpeg.zip from: $ffmpegZipUrl" -Verbose
        Invoke-WebRequest -Uri $ffmpegZipUrl -OutFile $tempZipPath -ErrorAction Stop -Verbose
        Write-Host "ffmpeg.zip downloaded. Extracting..." -ForegroundColor Yellow
        Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force -ErrorAction Stop
        $ffmpegExeFile = Get-ChildItem -Path $tempExtractPath -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
        if ($ffmpegExeFile) {
            Copy-Item -Path $ffmpegExeFile.FullName -Destination $ffmpegPath -Force -ErrorAction Stop
            Write-Host "ffmpeg.exe installed successfully." -ForegroundColor Green
            Write-ErrorLog "ffmpeg.exe downloaded and installed successfully."
        } else {
            throw "ffmpeg.exe not found within the downloaded and extracted files."
        }
    } catch {
        Resolve-ScriptError -UserMessage "Failed during ffmpeg download or setup. See debug.txt for details." `
                           -InternalLogMessage "Error during ffmpeg setup. URL: $ffmpegZipUrl. Exception: $($_.Exception.Message)" `
                           -IsCritical $true
    } finally {
        if (Test-Path $tempZipPath) { Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtractPath) { Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}


if ($env:PATH -notlike "*;$($scriptDir);*") {
    $env:PATH = "$($scriptDir);$($env:PATH)"
    Write-ErrorLog "Added script directory to session PATH: $scriptDir"
}

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

Write-Host "--------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " Welcome to the YouTube Downloader Script (syd.ps1) by MBNPRO " -ForegroundColor White
Write-Host "--------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Initial Instructions:" -ForegroundColor Green
Write-Host "1. When prompted, enter a valid YouTube video URL."
Write-Host "2. Video details will be shown. Then, choose the desired download quality, audio only, or cover."
Write-Host "3. Files are saved in 'Downloaded\Video', 'Downloaded\Audio' or 'Downloaded\Covers' subfolders."
Write-Host "4. Type 'exit' to quit, or '-h' / 'help' for detailed help at the prompt."
Write-Host "--------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host ""

$tempDir = Join-Path $scriptDir "Temp"
$downloadedDir = Join-Path $scriptDir "Downloaded"
$videoOutputDir = Join-Path $downloadedDir "Video"
$audioOutputDir = Join-Path $downloadedDir "Audio"
$coversOutputDir = Join-Path $downloadedDir "Covers"

Initialize-Directory $tempDir
Initialize-Directory $downloadedDir
Initialize-Directory $videoOutputDir
Initialize-Directory $audioOutputDir
Initialize-Directory $coversOutputDir

$continueWithNewLink = 'y' 

do { 
    Write-Host "=== YouTube Downloader ===" -ForegroundColor Yellow
    $userInputUrl = Read-Host "Enter YouTube video link (or 'exit' to quit, '-h' or 'help' for help)"

    if ($userInputUrl -eq 'exit') {
        $continueWithNewLink = 'n'
        continue
    }

    if ($userInputUrl -match '^\-h$' -or $userInputUrl -match '^\-{1,2}help$' -or $userInputUrl -eq 'help') {
        Show-ScriptHelp
        continue
    }
    
    $currentUrl = $userInputUrl 
    Write-ErrorLog "Attempting to process URL: $currentUrl"

    $jsonOutput = "" 
    try {
        $jsonOutput = & $ytDlpPath --dump-json --no-warnings $currentUrl 2>&1 
        if ($LASTEXITCODE -ne 0) { throw "yt-dlp --dump-json failed. Exit code: $LASTEXITCODE. Output: $($jsonOutput -join [System.Environment]::NewLine)" }
        Write-ErrorLog "Successfully obtained JSON for $currentUrl"
    } catch {
        $logMsg = "Failed to get video info for '$currentUrl'. yt-dlp output/error: $($jsonOutput -join [System.Environment]::NewLine). Exception: $($_.Exception.Message)"
        Resolve-ScriptError -UserMessage "Could not retrieve video information. The link might be invalid, private, or a network issue occurred." `
                           -InternalLogMessage $logMsg
        continue 
    }
    
    $videoInfo = $null
    try {
        $videoInfo = ($jsonOutput -join [System.Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $logMsg = "Failed to parse JSON for '$currentUrl'. JSON String: $($jsonOutput -join [System.Environment]::NewLine). Exception: $($_.Exception.Message)"
        Resolve-ScriptError -UserMessage "Received invalid video information from yt-dlp. The video might be unsupported or an internal error occurred." `
                           -InternalLogMessage $logMsg
        continue 
    }

    Show-VideoDetails -VideoInfo $videoInfo # Display video details

    $downloadAnotherFormatForSameUrl = 'y' 
    do { 

        $formats = $videoInfo.formats
        $availableHeights = $formats | Where-Object { $_.height -ne $null -and $_.vcodec -ne 'none' -and $_.vcodec -ne "av01" } | Select-Object -ExpandProperty height | Sort-Object -Unique -Descending

        $optionsArray = @() 
        $displayOptions = @() 

        $videoOptionsCount = 0
        if ($availableHeights -and $availableHeights.Count -gt 0) {
            foreach ($h in $availableHeights) {
                $optionsArray += "$h" 
                $sampleVideoFormat = $formats | Where-Object { $_.height -eq $h -and $_.vcodec -ne 'none' } | Sort-Object -Property tbr, vbr, fps, filesize_approx, filesize -Descending | Select-Object -First 1
                
                $fileSizeEstimate = ""
                if ($sampleVideoFormat) {
                    if ($sampleVideoFormat.filesize) {
                        $fileSizeEstimate = "[Video only ~$(Format-Bytes $sampleVideoFormat.filesize)]"
                    } elseif ($sampleVideoFormat.filesize_approx) {
                        $fileSizeEstimate = "[Video only ~$(Format-Bytes $sampleVideoFormat.filesize_approx)]"
                    }
                }
                $displayOptions += "$($h)p (MP4 Video + Best Audio + Subtitles) $fileSizeEstimate" 
                $videoOptionsCount++
            }
        }
        
        $optionsArray += "audio"
        $audioOnlyFormats = $formats | Where-Object { $_.acodec -ne 'none' -and $_.vcodec -eq 'none' } | Sort-Object -Property abr, filesize_approx, filesize -Descending
        $bestAudioFormatForMenu = $audioOnlyFormats | Select-Object -First 1
        
        $audioQualityNote = ""
        if ($bestAudioFormatForMenu) {
            if ($bestAudioFormatForMenu.format_note -and $bestAudioFormatForMenu.format_note -ne "medium") {
                $audioQualityNote = "$($bestAudioFormatForMenu.format_note)"
            } 
            if ($bestAudioFormatForMenu.abr) {
                $audioQualityNote += ($audioQualityNote | Where-Object {$_} | Foreach-Object {" "}) + "(~ $($bestAudioFormatForMenu.abr)kbps)"
            }
            $audioQualityNote = $audioQualityNote.Trim()
            if ($audioQualityNote) {$audioQualityNote = " $audioQualityNote"}
        }

        $audioFileSizeEstimate = ""
        if ($bestAudioFormatForMenu) {
            if ($bestAudioFormatForMenu.filesize) {
                $audioFileSizeEstimate = "[~$(Format-Bytes $bestAudioFormatForMenu.filesize)]"
            } elseif ($bestAudioFormatForMenu.filesize_approx) {
                $audioFileSizeEstimate = "[~$(Format-Bytes $bestAudioFormatForMenu.filesize_approx)]"
            }
        }
        $displayOptions += "Audio only (MP3 - Best Available$audioQualityNote) $audioFileSizeEstimate"

        Write-Host "`nAvailable Download Options for '$($videoInfo.title)':" -ForegroundColor Cyan
        Write-Host "---------------------------------------------" -ForegroundColor Gray
        
        $currentOptionNumber = 1
        if ($videoOptionsCount -gt 0) {
            Write-Host "--- Video Qualities (merged with best audio, includes Fa/En subtitles if available) ---" -ForegroundColor Yellow
            for ($i = 0; $i -lt $videoOptionsCount; $i++) {
                Write-Host "  $($currentOptionNumber). $($displayOptions[$i])" -ForegroundColor White
                $currentOptionNumber++
            }
        } else {
            Write-Host "No specific video resolution options found. Audio download is available." -ForegroundColor Yellow
        }

        Write-Host "`n--- Audio Option ---" -ForegroundColor Yellow
        Write-Host "  $($currentOptionNumber). $($displayOptions[$videoOptionsCount])" -ForegroundColor White 
        
        $currentOptionNumber++
        $optionsArray += "cover"
        $displayOptions += "Download Video Cover (Thumbnail)"
        Write-Host "`n--- Other Options ---" -ForegroundColor Yellow
        Write-Host "  $($currentOptionNumber). $($displayOptions[$displayOptions.Count -1])" -ForegroundColor White
        
        Write-Host "---------------------------------------------" -ForegroundColor Gray

        $userSelectionInput = Read-Host "`nSelect an option (1-$($currentOptionNumber)) for '$($videoInfo.title)'"
        Write-Host ""

        if ($userSelectionInput -match '^\d+$' -and [int]$userSelectionInput -ge 1 -and [int]$userSelectionInput -le $currentOptionNumber) {
            $selectedIndex = [int]$userSelectionInput - 1 
            $selectedChoiceIdentifier = $optionsArray[$selectedIndex] 
            $ytdlpOutputTemplate = Join-Path -Path $scriptDir -ChildPath "Temp\%(title)s.%(ext)s" 

            $isAudioOnlySelected = ($selectedChoiceIdentifier -eq "audio")
            $isCoverDownloadSelected = ($selectedChoiceIdentifier -eq "cover")

            if ($isCoverDownloadSelected) {
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
                        Write-Host "Downloading cover from: $thumbnailUrl" -Verbose
                        Invoke-WebRequest -Uri $thumbnailUrl -OutFile $tempCoverPath -ErrorAction Stop -Verbose -UseBasicParsing
                        Write-Host "Cover downloaded to Temp: $tempCoverPath" -ForegroundColor Yellow

                        Move-Item -Path $tempCoverPath -Destination $finalCoverPath -Force -ErrorAction Stop
                        Write-Host "`nCover successfully downloaded and moved to:" -ForegroundColor Green
                        Write-Host "$finalCoverPath" -ForegroundColor Cyan
                        Write-ErrorLog "Successfully downloaded and moved cover '$finalCoverFileName' to '$finalCoverPath'."
                    } catch {
                        $logMsg = "Failed to download/move cover. URL:'$thumbnailUrl'. Temp:'$tempCoverPath'. Final:'$finalCoverPath' Exc: $($_.Exception.Message)"
                        Resolve-ScriptError -UserMessage "Could not download or move video cover. Check debug.txt." -InternalLogMessage $logMsg
                    }
                } else {
                    Write-Warning "No thumbnail URL found in video information."
                    Write-ErrorLog "Attempted cover download, but no thumbnail URL in videoInfo."
                }
            } elseif (-not $isAudioOnlySelected) { 
                $selectedHeight = $selectedChoiceIdentifier 
                $formatStringForDownload = "bestvideo[height<=$selectedHeight][ext=mp4][vcodec!*=av01]+bestaudio[ext=m4a]/bestvideo[height<=$selectedHeight][ext=webm][vcodec!*=av01]+bestaudio[ext=opus]/bestvideo[height<=$selectedHeight][vcodec!*=av01]+bestaudio/best[height<=$selectedHeight][vcodec!*=av01][ext=mp4]/best[height<=$selectedHeight][vcodec!*=av01]"
                Write-Host "Preparing to download video in $($selectedHeight)p (merged with best audio, Fa/En subtitles if available)... This may take a while." -ForegroundColor Green
                
                $ytDlpArgsForDownload = New-Object System.Collections.Generic.List[string]
                $ytDlpArgsForDownload.Add("--no-warnings")
                $ytDlpArgsForDownload.Add("--ffmpeg-location"); $ytDlpArgsForDownload.Add($ffmpegPath)
                $ytDlpArgsForDownload.Add("-o"); $ytDlpArgsForDownload.Add($ytdlpOutputTemplate)
                $ytDlpArgsForDownload.Add("-f"); $ytDlpArgsForDownload.Add($formatStringForDownload)
                $ytDlpArgsForDownload.Add("--merge-output-format"); $ytDlpArgsForDownload.Add("mp4")
                $ytDlpArgsForDownload.Add("--write-subs")
                $ytDlpArgsForDownload.Add("--sub-lang"); $ytDlpArgsForDownload.Add("fa,en") 
                $ytDlpArgsForDownload.Add("--embed-subs")
                $ytDlpArgsForDownload.Add("--convert-subs"); $ytDlpArgsForDownload.Add("srt") 

                $ytDlpArgsForDownload.Add($currentUrl)
                
                $downloadProcessOutputLines = @() 
                Write-Host "Executing yt-dlp for video download..." -ForegroundColor DarkGray 
                Write-ErrorLog "Executing Video Download: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' ')"
                
                $exitCodeDownload = -1 
                try {
                    $downloadProcessOutputLines = & $ytDlpPath $ytDlpArgsForDownload 2>&1 
                    $exitCodeDownload = $LASTEXITCODE
                } catch {
                    $logMsg = "Critical error executing yt-dlp for video download. Command: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' '). Exception: $($_.Exception.ToString())"
                    Resolve-ScriptError -UserMessage "A critical error occurred while trying to run yt-dlp for video download." `
                                       -InternalLogMessage $logMsg
                    continue 
                }

                if ($exitCodeDownload -eq 0) {
                    Write-ErrorLog "yt-dlp video download process completed successfully. Exit Code: $exitCodeDownload."
                    $downloadOutputStringForParsing = $downloadProcessOutputLines -join [System.Environment]::NewLine
                    $downloadedFileInTemp = $null
                    $tempFilesList = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue

                    Write-ErrorLog "Attempting to find downloaded video file. Method 1: Based on videoInfo.title."
                    if ($videoInfo -and $videoInfo.title) {
                        $expectedFileExtension = ".mp4" 
                        $normalizedExpectedNameFromTitle = Convert-FileNameToComparable ($videoInfo.title + $expectedFileExtension)
                        Write-ErrorLog "Method 1 (Video): Normalized expected name from title: `"$normalizedExpectedNameFromTitle`""
                        if ($tempFilesList) { foreach ($fileInTempDir in $tempFilesList) { if ((Convert-FileNameToComparable $fileInTempDir.Name) -eq $normalizedExpectedNameFromTitle) { $downloadedFileInTemp = $fileInTempDir.FullName; Write-ErrorLog "Method 1 (Video): File found by title-based normalized comparison: $downloadedFileInTemp"; break } } } else { Write-ErrorLog "Method 1 (Video): No files found in Temp directory for comparison." }
                    } else { Write-ErrorLog "Method 1 (Video): videoInfo or videoInfo.title is null, cannot use title-based comparison." }
                    if (-not $downloadedFileInTemp) {
                        Write-ErrorLog "Method 1 (Video) failed. Attempting Method 2: Based on yt-dlp --print filename."
                        $ytDlpArgsForPrint = New-Object System.Collections.Generic.List[string]; $ytDlpArgsForPrint.Add("--no-download"); $ytDlpArgsForPrint.Add("--no-warnings"); $ytDlpArgsForPrint.Add("--print"); $ytDlpArgsForPrint.Add("filename"); $ytDlpArgsForPrint.Add("-o"); $ytDlpArgsForPrint.Add($ytdlpOutputTemplate); $ytDlpArgsForPrint.Add("-f"); $ytDlpArgsForPrint.Add($formatStringForDownload); $ytDlpArgsForPrint.Add("--merge-output-format"); $ytDlpArgsForPrint.Add("mp4"); $ytDlpArgsForPrint.Add($currentUrl); Write-ErrorLog "Method 2 (Video): Executing Print Filename: `"$ytDlpPath`" $($ytDlpArgsForPrint -join ' ')"; $determinedPathArray = & $ytDlpPath $ytDlpArgsForPrint 2>$null 
                        if ($LASTEXITCODE -eq 0 -and $determinedPathArray -and $determinedPathArray.Count -gt 0) { $determinedPathRaw = ($determinedPathArray | Select-Object -First 1).Trim(); $determinedLeaf = Split-Path $determinedPathRaw -Leaf; if ($determinedLeaf) { $normalizedDeterminedLeaf = Convert-FileNameToComparable $determinedLeaf; Write-ErrorLog "Method 2 (Video): --print filename provided leaf '$determinedLeaf', normalized to '$normalizedDeterminedLeaf'. Raw path: '$determinedPathRaw'"; if ($tempFilesList) { foreach ($fileInTempDir_Print in $tempFilesList) { if ((Convert-FileNameToComparable $fileInTempDir_Print.Name) -eq $normalizedDeterminedLeaf) { $downloadedFileInTemp = $fileInTempDir_Print.FullName; Write-ErrorLog "Method 2 (Video): File confirmed by --print filename and normalized comparison: $downloadedFileInTemp"; break } } }; if (-not $downloadedFileInTemp -and (Test-Path $determinedPathRaw) -and ($determinedPathRaw -like "$tempDir\*")) { $downloadedFileInTemp = $determinedPathRaw; Write-ErrorLog "Method 2 (Video): File confirmed by --print filename using direct Test-Path on its raw output: $downloadedFileInTemp."} } else { Write-ErrorLog "Method 2 (Video): Could not extract leaf from --print filename output: '$determinedPathRaw'" } } else { Write-ErrorLog "Method 2 (Video): yt-dlp --print filename command failed. Exit: $LASTEXITCODE. Output: $($determinedPathArray -join ', ')"}
                    }
                    if (-not $downloadedFileInTemp) {
                        Write-ErrorLog "Methods 1 & 2 (Video) failed. Attempting Method 3: Based on parsing [Merger] or [ffmpeg] Destination."
                        $patternForMethod3 = [regex]'\[Merger\] Merging formats into "(?<FileNameFromOutput>.*?)"'; $matchMethod3 = $patternForMethod3.Match($downloadOutputStringForParsing); if (-not $matchMethod3.Success) { $patternForMethod3 = [regex]'\[ffmpeg\] Destination: (?<FileNameFromOutput>.*?)$'; $matchMethod3 = $patternForMethod3.Match($downloadOutputStringForParsing) }
                        if ($matchMethod3.Success) { $filePathFromRegex = $matchMethod3.Groups["FileNameFromOutput"].Value.Trim(); $fileLeafFromRegex = Split-Path $filePathFromRegex -Leaf; if ($fileLeafFromRegex) { $normalizedLeafFromRegex = Convert-FileNameToComparable $fileLeafFromRegex; Write-ErrorLog "Method 3 (Video): Using pattern '$($patternForMethod3.ToString())'. Reported leaf: '$fileLeafFromRegex', normalized: '$normalizedLeafFromRegex'. Raw path: '$filePathFromRegex'"; if ($tempFilesList) { foreach ($fileInTempDir_Regex in $tempFilesList) { if ((Convert-FileNameToComparable $fileInTempDir_Regex.Name) -eq $normalizedLeafFromRegex) { $downloadedFileInTemp = $fileInTempDir_Regex.FullName; Write-ErrorLog "Method 3 (Video): File confirmed by regex pattern output and normalized comparison: $downloadedFileInTemp"; break } } }; if (-not $downloadedFileInTemp -and (Test-Path $filePathFromRegex) -and ($filePathFromRegex -like "$tempDir\*")) { $downloadedFileInTemp = $filePathFromRegex; Write-ErrorLog "Method 3 (Video): File confirmed by regex pattern output using direct Test-Path on its raw output: $downloadedFileInTemp."} } else { Write-ErrorLog "Method 3 (Video): Could not extract leaf from regex pattern output: '$filePathFromRegex'" } } else { Write-ErrorLog "Method 3 (Video): Pattern for [Merger] or [ffmpeg] Destination not found in yt-dlp output." }
                    }

                    if ($downloadedFileInTemp -and (Test-Path $downloadedFileInTemp)) {
                        $fileNameOnly = Split-Path $downloadedFileInTemp -Leaf
                        $destinationDir = $videoOutputDir
                        $destinationPath = Join-Path $destinationDir $fileNameOnly
                        
                        Write-ErrorLog "Attempting to move video '$fileNameOnly' from '$downloadedFileInTemp' to '$destinationDir'..."
                        try {
                            Move-Item -Path $downloadedFileInTemp -Destination $destinationPath -Force -ErrorAction Stop
                            Write-Host "`nVideo file '$fileNameOnly' successfully downloaded and moved to:" -ForegroundColor Green 
                            Write-Host "$destinationPath" -ForegroundColor Cyan 
                            Write-ErrorLog "Successfully moved video '$downloadedFileInTemp' to '$destinationPath'."

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
                            } else { Write-ErrorLog "No subtitle files found in Temp for '$baseVideoNameWithoutExt'."}

                        } catch {
                            $logMsg = "Move-Item (Video) failed. Source: '$downloadedFileInTemp', Dest: '$destinationPath'. Exception: $($_.Exception.ToString())"
                            Resolve-ScriptError -UserMessage "Failed to move the downloaded video from Temp to '$destinationDir'. It might be in 'Temp'." `
                                               -InternalLogMessage $logMsg
                        }
                    } else {
                        $logMsg = "yt-dlp video download completed (Exit Code $exitCodeDownload), but script couldn't find the file in '$tempDir'. Output for parsing: $downloadOutputStringForParsing"
                        Resolve-ScriptError -UserMessage "Video download seemed to complete, but script couldn't find file in 'Temp' to move. Check 'Temp' folder and debug.txt." `
                                           -InternalLogMessage $logMsg
                        if ($tempFilesList) { Write-Host "Files currently in '$tempDir': $( ($tempFilesList).Name -join ', ' )" -ForegroundColor Yellow }
                    }
                } else { 
                    $logMsg = "yt-dlp video download failed. Exit Code: $exitCodeDownload. URL: $currentUrl. Args: $($ytDlpArgsForDownload -join ' '). Output: $($downloadProcessOutputLines -join [System.Environment]::NewLine)"
                    Resolve-ScriptError -UserMessage "Video download with yt-dlp failed. Please check the console output above for errors from yt-dlp and debug.txt." `
                                       -InternalLogMessage $logMsg
                }

            } elseif ($isAudioOnlySelected) { 
                Write-Host "Preparing to download audio (Best Available MP3)... This may take a while." -ForegroundColor Green
                $formatStringForDownload = "bestaudio/best" 
                
                $ytDlpArgsForDownload = New-Object System.Collections.Generic.List[string]
                $ytDlpArgsForDownload.Add("--no-warnings")
                $ytDlpArgsForDownload.Add("--ffmpeg-location"); $ytDlpArgsForDownload.Add($ffmpegPath)
                $ytDlpArgsForDownload.Add("-o"); $ytDlpArgsForDownload.Add($ytdlpOutputTemplate)
                $ytDlpArgsForDownload.Add("-f"); $ytDlpArgsForDownload.Add($formatStringForDownload)
                $ytDlpArgsForDownload.Add("--extract-audio"); $ytDlpArgsForDownload.Add("--audio-format"); $ytDlpArgsForDownload.Add("mp3")
                $ytDlpArgsForDownload.Add($currentUrl)

                $downloadProcessOutputLines = @() 
                Write-Host "Executing yt-dlp for audio download..." -ForegroundColor DarkGray 
                Write-ErrorLog "Executing Audio Download: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' ')"
                
                $exitCodeDownload = -1
                try {
                    $downloadProcessOutputLines = & $ytDlpPath $ytDlpArgsForDownload 2>&1
                    $exitCodeDownload = $LASTEXITCODE
                } catch {
                    $logMsg = "Critical error executing yt-dlp for audio download. Command: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' '). Exception: $($_.Exception.ToString())"
                    Resolve-ScriptError -UserMessage "A critical error occurred while trying to run yt-dlp for audio download." `
                                       -InternalLogMessage $logMsg
                    continue 
                }

                if ($exitCodeDownload -eq 0) {
                    Write-ErrorLog "yt-dlp audio download process completed successfully. Exit Code: $exitCodeDownload."
                    $downloadOutputStringForParsing = $downloadProcessOutputLines -join [System.Environment]::NewLine
                    $downloadedFileInTemp = $null
                    $tempFilesList = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue

                    Write-ErrorLog "Attempting to find downloaded audio file. Method 1: Based on videoInfo.title."
                    if ($videoInfo -and $videoInfo.title) {
                        $expectedFileExtension = ".mp3"
                        $normalizedExpectedNameFromTitle = Convert-FileNameToComparable ($videoInfo.title + $expectedFileExtension)
                        Write-ErrorLog "Method 1 (Audio): Normalized expected name from title: `"$normalizedExpectedNameFromTitle`""
                        if ($tempFilesList) { foreach ($fileInTempDir in $tempFilesList) { if ((Convert-FileNameToComparable $fileInTempDir.Name) -eq $normalizedExpectedNameFromTitle) { $downloadedFileInTemp = $fileInTempDir.FullName; Write-ErrorLog "Method 1 (Audio): File found by title-based normalized comparison: $downloadedFileInTemp"; break } } } else { Write-ErrorLog "Method 1 (Audio): No files found in Temp directory for comparison." }
                    } else { Write-ErrorLog "Method 1 (Audio): videoInfo or videoInfo.title is null, cannot use title-based comparison."}
                    if (-not $downloadedFileInTemp) {
                        Write-ErrorLog "Method 1 (Audio) failed. Attempting Method 2: Based on yt-dlp --print filename."
                        $ytDlpArgsForPrint = New-Object System.Collections.Generic.List[string]; $ytDlpArgsForPrint.Add("--no-download"); $ytDlpArgsForPrint.Add("--no-warnings"); $ytDlpArgsForPrint.Add("--print"); $ytDlpArgsForPrint.Add("filename"); $ytDlpArgsForPrint.Add("-o"); $ytDlpArgsForPrint.Add($ytdlpOutputTemplate); $ytDlpArgsForPrint.Add("-f"); $ytDlpArgsForPrint.Add("bestaudio/best"); $ytDlpArgsForPrint.Add("--extract-audio"); $ytDlpArgsForPrint.Add("--audio-format"); $ytDlpArgsForPrint.Add("mp3"); $ytDlpArgsForPrint.Add($currentUrl); Write-ErrorLog "Method 2 (Audio): Executing Print Filename: `"$ytDlpPath`" $($ytDlpArgsForPrint -join ' ')"; $determinedPathArray = & $ytDlpPath $ytDlpArgsForPrint 2>$null
                        if ($LASTEXITCODE -eq 0 -and $determinedPathArray -and $determinedPathArray.Count -gt 0) { $determinedPathRaw = ($determinedPathArray | Select-Object -First 1).Trim(); $determinedLeaf = Split-Path $determinedPathRaw -Leaf; if ($determinedLeaf) { $normalizedDeterminedLeaf = Convert-FileNameToComparable $determinedLeaf; Write-ErrorLog "Method 2 (Audio): --print filename provided leaf '$determinedLeaf', normalized to '$normalizedDeterminedLeaf'. Raw path: '$determinedPathRaw'"; if ($tempFilesList) { foreach ($fileInTempDir_Print in $tempFilesList) { if ((Convert-FileNameToComparable $fileInTempDir_Print.Name) -eq $normalizedDeterminedLeaf) { $downloadedFileInTemp = $fileInTempDir_Print.FullName; Write-ErrorLog "Method 2 (Audio): File confirmed by --print filename and normalized comparison: $downloadedFileInTemp"; break } } }; if (-not $downloadedFileInTemp -and (Test-Path $determinedPathRaw) -and ($determinedPathRaw -like "$tempDir\*")) { $downloadedFileInTemp = $determinedPathRaw; Write-ErrorLog "Method 2 (Audio): File confirmed by --print filename using direct Test-Path on its raw output: $downloadedFileInTemp."} } else { Write-ErrorLog "Method 2 (Audio): Could not extract leaf from --print filename output: '$determinedPathRaw'" } } else { Write-ErrorLog "Method 2 (Audio): yt-dlp --print filename command failed. Exit: $LASTEXITCODE. Output: $($determinedPathArray -join ', ')"}
                    }
                    if (-not $downloadedFileInTemp) {
                        Write-ErrorLog "Methods 1 & 2 (Audio) failed. Attempting Method 3: Based on parsing [ExtractAudio] output."
                        $patternForMethod3 = [regex]'\[ExtractAudio\] Destination: (?<FileNameFromOutput>.*?)$'; $matchMethod3 = $patternForMethod3.Match($downloadOutputStringForParsing); if (-not $matchMethod3.Success) { $patternForMethod3 = [regex]'\[ffmpeg\] Destination: (?<FileNameFromOutput>.*?)$'; $matchMethod3 = $patternForMethod3.Match($downloadOutputStringForParsing) }
                        if ($matchMethod3.Success) { $filePathFromRegex = $matchMethod3.Groups["FileNameFromOutput"].Value.Trim(); $fileLeafFromRegex = Split-Path $filePathFromRegex -Leaf; if ($fileLeafFromRegex) { $normalizedLeafFromRegex = Convert-FileNameToComparable $fileLeafFromRegex; Write-ErrorLog "Method 3 (Audio): Using pattern '$($patternForMethod3.ToString())'. Reported leaf: '$fileLeafFromRegex', normalized: '$normalizedLeafFromRegex'. Raw path: '$filePathFromRegex'"; if ($tempFilesList) { foreach ($fileInTempDir_Regex in $tempFilesList) { if ((Convert-FileNameToComparable $fileInTempDir_Regex.Name) -eq $normalizedLeafFromRegex) { $downloadedFileInTemp = $fileInTempDir_Regex.FullName; Write-ErrorLog "Method 3 (Audio): File confirmed by regex pattern output and normalized comparison: $downloadedFileInTemp"; break } } }; if (-not $downloadedFileInTemp -and (Test-Path $filePathFromRegex) -and ($filePathFromRegex -like "$tempDir\*")) { $downloadedFileInTemp = $filePathFromRegex; Write-ErrorLog "Method 3 (Audio): File confirmed by regex pattern output using direct Test-Path on its raw output: $downloadedFileInTemp."} } else { Write-ErrorLog "Method 3 (Audio): Could not extract leaf from regex pattern output: '$filePathFromRegex'" } } else { Write-ErrorLog "Method 3 (Audio): Pattern for [ExtractAudio] or [ffmpeg] Destination not found in yt-dlp output." }
                    }

                    if ($downloadedFileInTemp -and (Test-Path $downloadedFileInTemp)) {
                        $fileNameOnly = Split-Path $downloadedFileInTemp -Leaf
                        $destinationDir = $audioOutputDir
                        $destinationPath = Join-Path $destinationDir $fileNameOnly
                        
                        Write-ErrorLog "Attempting to move audio '$fileNameOnly' from '$downloadedFileInTemp' to '$destinationDir'..."
                        try {
                            Move-Item -Path $downloadedFileInTemp -Destination $destinationPath -Force -ErrorAction Stop
                            Write-Host "`nAudio file '$fileNameOnly' successfully downloaded and moved to:" -ForegroundColor Green
                            Write-Host "$destinationPath" -ForegroundColor Cyan
                            Write-ErrorLog "Successfully moved audio '$downloadedFileInTemp' to '$destinationPath'."
                        } catch {
                            $logMsg = "Move-Item (Audio) failed. Source: '$downloadedFileInTemp', Dest: '$destinationPath'. Exception: $($_.Exception.ToString())"
                            Resolve-ScriptError -UserMessage "Failed to move the downloaded audio from Temp to '$destinationDir'. It might be in 'Temp'." `
                                               -InternalLogMessage $logMsg
                        }
                    } else {
                        $logMsg = "yt-dlp audio download completed (Exit Code $exitCodeDownload), but script couldn't find file in '$tempDir'. Output for parsing: $downloadOutputStringForParsing"
                        Resolve-ScriptError -UserMessage "Audio download seemed to complete, but script couldn't find file in 'Temp' to move. Check 'Temp' folder and debug.txt." `
                                           -InternalLogMessage $logMsg
                        if ($tempFilesList) { Write-Host "Files currently in '$tempDir': $( ($tempFilesList).Name -join ', ' )" -ForegroundColor Yellow }
                    }
                } else {
                    $logMsg = "yt-dlp audio download failed. Exit Code: $exitCodeDownload. URL: $currentUrl. Args: $($ytDlpArgsForDownload -join ' '). Output: $($downloadProcessOutputLines -join [System.Environment]::NewLine)"
                    Resolve-ScriptError -UserMessage "Audio download with yt-dlp failed. Please check the console output above for errors from yt-dlp and debug.txt." `
                                       -InternalLogMessage $logMsg
                }
            } 
        } else { 
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }

        Write-Host ""
        $userResponseSameUrl = Read-Host "Do you want to download another quality/option for THIS video ('$($videoInfo.title)')? (y/n)"
        if ($userResponseSameUrl.ToLower() -ne 'y') {
            $downloadAnotherFormatForSameUrl = 'n' 
        }

    } while ($downloadAnotherFormatForSameUrl.ToLower() -eq 'y') 

    Write-Host ""
    $userContinueChoiceWithNewLink = Read-Host "Do you want to download from a NEW YouTube link? (y/n)"
    if ($userContinueChoiceWithNewLink.ToLower() -ne 'y') {
        $continueWithNewLink = 'n' 
    }

} while ($continueWithNewLink.ToLower() -eq 'y') 

$Host.UI.RawUI.BackgroundColor = $originalBackground
$Host.UI.RawUI.ForegroundColor = $originalForeground
Clear-Host
Write-Host "Exiting YouTube Downloader Script. Goodbye!"
Write-ErrorLog "Script session ended."