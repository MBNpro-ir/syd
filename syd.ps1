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
    Write-Host " Description: Downloads videos or audio from YouTube."
    Write-Host " Usage (interactive): Just run .\syd.ps1 and follow prompts."
    Write-Host " Usage (command line help): .\syd.ps1 -Help (or -h)"
    Write-Host ""
    Write-Host " Main Prompts:" -ForegroundColor Green
    Write-Host "   - Enter YouTube Link: Paste the full YouTube video URL."
    Write-Host "   - 'exit': Type 'exit' at the link prompt to quit the script."
    Write-Host "   - '-h' or 'help': Type at link prompt to see this help again."
    Write-Host ""
    Write-Host " Features:" -ForegroundColor Green
    Write-Host "   - Video Download: Saves to 'Downloaded\Video' as MP4."
    Write-Host "   - Audio Download: Saves to 'Downloaded\Audio' as MP3."
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

# --- Main Script Logic ---

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
Write-Host "2. Choose the desired download quality (video) or select audio only."
Write-Host "3. Files are saved in 'Downloaded\Video' or 'Downloaded\Audio' subfolders within the script directory."
Write-Host "4. Type 'exit' to quit, or '-h' / 'help' for detailed help at the prompt." 
Write-Host "--------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host ""

$tempDir = Join-Path $scriptDir "Temp"
$downloadedDir = Join-Path $scriptDir "Downloaded"
$videoOutputDir = Join-Path $downloadedDir "Video"
$audioOutputDir = Join-Path $downloadedDir "Audio"

Initialize-Directory $tempDir
Initialize-Directory $downloadedDir
Initialize-Directory $videoOutputDir
Initialize-Directory $audioOutputDir

$continueResponse = 'y' 

do {
    Write-Host "=== YouTube Downloader ===" -ForegroundColor Yellow
    $userInputUrl = Read-Host "Enter YouTube video link (or 'exit' to quit, '-h' or 'help' for help)"

    if ($userInputUrl -eq 'exit') { break }

    if ($userInputUrl -match '^\-h$' -or $userInputUrl -match '^\-{1,2}help$' -or $userInputUrl -eq 'help') {
        Show-ScriptHelp
        $continueResponse = 'y' 
        continue 
    }
    
    $currentUrl = $userInputUrl 
    Write-ErrorLog "Attempting to process URL: $currentUrl"

    $jsonOutput = "" 
    try {
        $jsonOutput = & $ytDlpPath --dump-json --no-warnings $currentUrl 2>&1
        if ($LASTEXITCODE -ne 0) { throw "yt-dlp --dump-json failed. Exit code: $LASTEXITCODE" }
    } catch {
        $logMsg = "Failed to get video info for '$currentUrl'. yt-dlp output/error: $($jsonOutput -join [System.Environment]::NewLine). Exception: $($_.Exception.Message)"
        Resolve-ScriptError -UserMessage "Could not retrieve video information. The link might be invalid, private, or a network issue occurred." `
                           -InternalLogMessage $logMsg
        $continueResponse = 'y' ; continue
    }
    
    $videoInfo = $null
    try {
        $videoInfo = ($jsonOutput -join [System.Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $logMsg = "Failed to parse JSON for '$currentUrl'. JSON String: $($jsonOutput -join [System.Environment]::NewLine). Exception: $($_.Exception.Message)"
        Resolve-ScriptError -UserMessage "Received invalid video information from yt-dlp. The video might be unsupported or an internal error occurred." `
                           -InternalLogMessage $logMsg
        $continueResponse = 'y' ; continue
    }

    $formats = $videoInfo.formats
    $availableHeights = $formats | Where-Object { $_.height -ne $null -and $_.vcodec -ne 'none' -and $_.acodec -ne $null } | Select-Object -ExpandProperty height | Sort-Object -Unique -Descending

    $optionsArray = @() 
    $displayOptions = @() 

    $videoOptionsCount = 0
    if ($availableHeights -and $availableHeights.Count -gt 0) {
        foreach ($h in $availableHeights) {
            $optionsArray += "$h" 
            $displayOptions += "$($h)p (MP4 Video)"
            $videoOptionsCount++
        }
    }
    
    $optionsArray += "audio" 
    $displayOptions += "Audio only (MP3)"

    Write-Host "`nAvailable Download Options for '$($videoInfo.title)':" -ForegroundColor Cyan
    Write-Host "---------------------------------------------" -ForegroundColor Gray
    
    $currentOptionNumber = 1
    if ($videoOptionsCount -gt 0) {
        Write-Host "--- Video Qualities ---" -ForegroundColor Yellow
        for ($i = 0; $i -lt $videoOptionsCount; $i++) {
            Write-Host "  $($currentOptionNumber). $($displayOptions[$i])" -ForegroundColor White
            $currentOptionNumber++
        }
    } else {
        Write-Host "No specific video resolution options found. Audio download is available." -ForegroundColor Yellow
    }

    Write-Host "`n--- Audio Option ---" -ForegroundColor Yellow
    Write-Host "  $($currentOptionNumber). $($displayOptions[$displayOptions.Count -1])" -ForegroundColor White 
    Write-Host "---------------------------------------------" -ForegroundColor Gray

    $userSelectionInput = Read-Host "`nSelect an option (1-$($currentOptionNumber))"
    Write-Host ""

    if ($userSelectionInput -match '^\d+$' -and [int]$userSelectionInput -ge 1 -and [int]$userSelectionInput -le $currentOptionNumber) {
        $selectedIndex = [int]$userSelectionInput - 1 
        
        $selectedChoiceIdentifier = $optionsArray[$selectedIndex] 
        $ytdlpOutputTemplate = Join-Path -Path $scriptDir -ChildPath "Temp\%(title)s.%(ext)s" 

        $isAudioOnlySelected = ($selectedChoiceIdentifier -eq "audio")
        
        $ytDlpArgsForDownload = New-Object System.Collections.Generic.List[string]
        $ytDlpArgsForDownload.Add("--progress")
        $ytDlpArgsForDownload.Add("--progress-delta") 
        $ytDlpArgsForDownload.Add("0")
        $ytDlpArgsForDownload.Add("--no-warnings")
        $ytDlpArgsForDownload.Add("--ffmpeg-location")
        $ytDlpArgsForDownload.Add($ffmpegPath)
        $ytDlpArgsForDownload.Add("-o")
        $ytDlpArgsForDownload.Add($ytdlpOutputTemplate)
        $formatString = "" 

        if (-not $isAudioOnlySelected) { 
            $selectedHeight = $selectedChoiceIdentifier 
            $formatString = "bestvideo[height<=$selectedHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$selectedHeight]+bestaudio/best[height<=$selectedHeight][ext=mp4]/best[height<=$selectedHeight]"
            Write-Host "Preparing to download video in $($selectedHeight)p... This may take a while." -ForegroundColor Green
            $ytDlpArgsForDownload.Insert(0, $formatString) 
            $ytDlpArgsForDownload.Insert(0, "-f")
            $ytDlpArgsForDownload.Add("--merge-output-format")
            $ytDlpArgsForDownload.Add("mp4")
        } else { 
            Write-Host "Preparing to download audio... This may take a while." -ForegroundColor Green
            $formatString = "bestaudio"
            $ytDlpArgsForDownload.Insert(0, $formatString) 
            $ytDlpArgsForDownload.Insert(0, "-f")
            $ytDlpArgsForDownload.Add("--extract-audio")
            $ytDlpArgsForDownload.Add("--audio-format")
            $ytDlpArgsForDownload.Add("mp3")
        }
        $ytDlpArgsForDownload.Add($currentUrl) 
        
        $downloadProcessOutputLines = @()
        Write-Host "Executing yt-dlp for download... (Live progress should appear below)" -ForegroundColor DarkGray 
        Write-ErrorLog "Executing Download: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' ')"
        
        $exitCodeDownload = -1 
        try {
            & $ytDlpPath $ytDlpArgsForDownload *>&1 | ForEach-Object {
                Write-Host $_
                $downloadProcessOutputLines += $_
            }
            $exitCodeDownload = $LASTEXITCODE
        } catch {
            $logMsg = "Critical error executing yt-dlp for download. Command: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' '). Exception: $($_.Exception.ToString())"
            Resolve-ScriptError -UserMessage "A critical error occurred while trying to run yt-dlp for download." `
                               -InternalLogMessage $logMsg
            $continueResponse = 'y'; continue
        }

        if ($exitCodeDownload -eq 0) {
            Write-ErrorLog "yt-dlp download process completed successfully. Exit Code: $exitCodeDownload. Full output for parsing: $($downloadProcessOutputLines -join [System.Environment]::NewLine)"
            $downloadedFileInTemp = $null
            $downloadOutputStringForParsing = $downloadProcessOutputLines -join [System.Environment]::NewLine

            # Priority 1: Parse [Merger] or [ExtractAudio] or [download] Destination from live output
            $PrimaryPatterns = @(
                [regex]'\[Merger\] Merging formats into "(.*?)"', 
                [regex]'\[ExtractAudio\] Destination: (.*?)$', 
                [regex]'\[download\] Destination: (.*?)$', # Catches initial downloads and "already downloaded" if path is absolute
                [regex]'\[download\] (.*?) has already been downloaded' # Catches "already downloaded" when path is absolute
            )
            foreach ($pattern in $PrimaryPatterns) {
                $match = $pattern.Match($downloadOutputStringForParsing)
                if ($match.Success) {
                    $filePathFromOutput = $match.Groups[1].Value.Trim()
                    # Check if it's an absolute path within our Temp folder and exists
                    if ((Split-Path $filePathFromOutput -IsAbsolute) -and ($filePathFromOutput -like "$tempDir\*") -and (Test-Path $filePathFromOutput)) {
                        $downloadedFileInTemp = $filePathFromOutput
                        Write-ErrorLog "File confirmed by primary pattern ('$($pattern.ToString())'): $downloadedFileInTemp"
                        break
                    }
                    # If it's just a filename (relative), join with $tempDir
                    elseif (-not (Split-Path $filePathFromOutput -IsAbsolute)) {
                        $potentialFullPath = Join-Path $tempDir (Split-Path $filePathFromOutput -Leaf)
                        if (Test-Path $potentialFullPath) {
                            $downloadedFileInTemp = $potentialFullPath
                            Write-ErrorLog "File confirmed by primary pattern (relative, '$($pattern.ToString())'): $downloadedFileInTemp"
                            break
                        }
                    }
                }
            }
            
            # Priority 2: If not found, use yt-dlp --print filename
            if (-not $downloadedFileInTemp) {
                Write-ErrorLog "Primary pattern matching failed. Trying yt-dlp --print filename..."
                $ytDlpArgsForPrint = New-Object System.Collections.Generic.List[string]
                $ytDlpArgsForPrint.Add("--no-download"); $ytDlpArgsForPrint.Add("--no-warnings"); $ytDlpArgsForPrint.Add("--print"); $ytDlpArgsForPrint.Add("filename")
                $ytDlpArgsForPrint.Add("-o"); $ytDlpArgsForPrint.Add($ytdlpOutputTemplate)
                if (-not $isAudioOnlySelected) {
                    $ytDlpArgsForPrint.Add("-f"); $ytDlpArgsForPrint.Add($formatString); $ytDlpArgsForPrint.Add("--merge-output-format"); $ytDlpArgsForPrint.Add("mp4")
                } else {
                    $ytDlpArgsForPrint.Add("-f"); $ytDlpArgsForPrint.Add("bestaudio"); $ytDlpArgsForPrint.Add("--extract-audio"); $ytDlpArgsForPrint.Add("--audio-format"); $ytDlpArgsForPrint.Add("mp3")
                }
                $ytDlpArgsForPrint.Add($currentUrl)
                Write-ErrorLog "Executing Print Filename: `"$ytDlpPath`" $($ytDlpArgsForPrint -join ' ')"
                $determinedPathArray = & $ytDlpPath $ytDlpArgsForPrint 2>$null
                
                if ($LASTEXITCODE -eq 0 -and $determinedPathArray -and $determinedPathArray.Count -gt 0) {
                    $determinedPath = ($determinedPathArray | Select-Object -First 1).Trim()
                    if (Test-Path $determinedPath) {
                        $downloadedFileInTemp = $determinedPath
                        Write-ErrorLog "File confirmed by --print filename: $downloadedFileInTemp"
                    } else {
                        $expectedExtension = if ($isAudioOnlySelected) { ".mp3" } else { ".mp4" }
                        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($determinedPath)
                        $potentialFileWithCorrectExt = Join-Path $tempDir ($baseName + $expectedExtension)
                        if (Test-Path $potentialFileWithCorrectExt) {
                            $downloadedFileInTemp = $potentialFileWithCorrectExt
                            Write-ErrorLog "Corrected extension from --print filename. Found: $downloadedFileInTemp. Original print: $determinedPath"
                        } else {
                            Write-ErrorLog "yt-dlp --print filename provided '$determinedPath' (or corrected '$potentialFileWithCorrectExt'), but file does not exist in Temp folder."
                        }
                    }
                } else {
                     Write-ErrorLog "yt-dlp --print filename failed. Exit Code: $LASTEXITCODE. Output: $($determinedPathArray -join ', ')"
                }
            }

            # Priority 3: Fallback to searching Temp folder
            if (-not $downloadedFileInTemp -and $videoInfo.title) {
                Write-ErrorLog "--print filename also failed or file not found. Attempting fallback: searching Temp folder..."
                $fileExtensionFilter = if ($isAudioOnlySelected) { "*.mp3" } else { "*.mp4" }
                # Match against any file containing the first few words of the sanitized title.
                $sanitizedTitleWords = ($videoInfo.title -replace '[\\/:*?"<>|]', '_').Split(' ')
                $searchPattern = "*" + ($sanitizedTitleWords[0..([System.Math]::Min(4, $sanitizedTitleWords.Count-1))] -join '*') + "*" + $fileExtensionFilter.Substring(1)

                $latestFileInTemp = Get-ChildItem -Path $tempDir -Filter $fileExtensionFilter | Where-Object {$_.Name -like $searchPattern} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($latestFileInTemp -and (Test-Path $latestFileInTemp.FullName)) {
                    $downloadedFileInTemp = $latestFileInTemp.FullName
                    Write-ErrorLog "Fallback (title substring match) confirmed file: $downloadedFileInTemp"
                } else {
                     Write-ErrorLog "Fallback search in Temp folder also failed to find a matching file."
                }
            }

            if ($downloadedFileInTemp -and (Test-Path $downloadedFileInTemp)) {
                $fileNameOnly = Split-Path $downloadedFileInTemp -Leaf
                $fileTypeString = if ($isAudioOnlySelected) { "Audio" } else { "Video" }
                $destinationDir = if ($isAudioOnlySelected) { $audioOutputDir } else { $videoOutputDir }
                $destinationPath = Join-Path $destinationDir $fileNameOnly
                
                Write-ErrorLog "Attempting to move '$fileNameOnly' from '$downloadedFileInTemp' to '$destinationDir'..."
                try {
                    Move-Item -Path $downloadedFileInTemp -Destination $destinationPath -Force -ErrorAction Stop
                    Write-Host "`n$fileTypeString file '$fileNameOnly' successfully downloaded and moved to:" -ForegroundColor Green 
                    Write-Host "$destinationPath" -ForegroundColor Cyan 
                    Write-ErrorLog "Successfully moved '$downloadedFileInTemp' to '$destinationPath'."
                } catch {
                    $logMsg = "Move-Item failed. Source: '$downloadedFileInTemp', Dest: '$destinationPath'. Exception: $($_.Exception.ToString())"
                    Resolve-ScriptError -UserMessage "Failed to move the downloaded file from Temp to the '$destinationDir' folder. The file may still be in the 'Temp' folder. This can sometimes happen with special characters in filenames." `
                                       -InternalLogMessage $logMsg
                }
            } else {
                $logMsg = "yt-dlp download process completed (Exit Code $exitCodeDownload), but script could not identify/locate the downloaded file in '$tempDir'. Full download output for parsing was: $downloadOutputStringForParsing"
                Resolve-ScriptError -UserMessage "Download seemed to complete (check console), but the script could not find the final file in 'Temp' to move it. Please check 'Temp' folder." `
                                   -InternalLogMessage $logMsg
                $tempFiles = Get-ChildItem -Path $tempDir -ErrorAction SilentlyContinue
                if ($tempFiles) { Write-Host "Files currently in '$tempDir': $( ($tempFiles).Name -join ', ' )" -ForegroundColor Yellow }
            }
        } else { 
            $logMsg = "yt-dlp download process failed with Exit Code: $exitCodeDownload. URL: $currentUrl. Args: $($ytDlpArgsForDownload -join ' '). Output: $($downloadProcessOutputLines -join [System.Environment]::NewLine)"
            Resolve-ScriptError -UserMessage "The download process with yt-dlp failed. Please check the console output above for errors from yt-dlp." `
                               -InternalLogMessage $logMsg
        }
    } else { 
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    }

    Write-Host ""
    $userContinueChoice = Read-Host "Do you want to download another video/audio? (y/n)"
    if ($userContinueChoice.ToLower() -eq 'y') {
        $continueResponse = 'y'
    } else {
        $continueResponse = 'n' 
    }

} while ($continueResponse.ToLower() -eq 'y')

$Host.UI.RawUI.BackgroundColor = $originalBackground
$Host.UI.RawUI.ForegroundColor = $originalForeground
Clear-Host
Write-Host "Exiting YouTube Downloader Script. Goodbye!"
Write-ErrorLog "Script session ended."