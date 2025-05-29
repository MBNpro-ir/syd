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
        $ytDlpArgsForDownload.Add("--no-warnings")
        $ytDlpArgsForDownload.Add("--ffmpeg-location"); $ytDlpArgsForDownload.Add($ffmpegPath)
        $ytDlpArgsForDownload.Add("-o"); $ytDlpArgsForDownload.Add($ytdlpOutputTemplate)

        $formatStringForDownload = ""

        if (-not $isAudioOnlySelected) {
            $selectedHeight = $selectedChoiceIdentifier
            $formatStringForDownload = "bestvideo[height<=$selectedHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$selectedHeight]+bestaudio/best[height<=$selectedHeight][ext=mp4]/best[height<=$selectedHeight]"
            Write-Host "Preparing to download video in $($selectedHeight)p... This may take a while." -ForegroundColor Green
            $ytDlpArgsForDownload.Add("-f"); $ytDlpArgsForDownload.Add($formatStringForDownload)
            $ytDlpArgsForDownload.Add("--merge-output-format"); $ytDlpArgsForDownload.Add("mp4")
        } else {
            Write-Host "Preparing to download audio... This may take a while." -ForegroundColor Green
            $formatStringForDownload = "bestaudio"
            $ytDlpArgsForDownload.Add("-f"); $ytDlpArgsForDownload.Add($formatStringForDownload)
            $ytDlpArgsForDownload.Add("--extract-audio"); $ytDlpArgsForDownload.Add("--audio-format"); $ytDlpArgsForDownload.Add("mp3")
        }
        $ytDlpArgsForDownload.Add($currentUrl)

        $downloadProcessOutputLines = @()
        Write-Host "Executing yt-dlp for download..." -ForegroundColor DarkGray
        Write-ErrorLog "Executing Download: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' ')"

        $exitCodeDownload = -1
        try {
            $downloadProcessOutputLines = & $ytDlpPath $ytDlpArgsForDownload 2>&1
            $exitCodeDownload = $LASTEXITCODE
        } catch {
            $logMsg = "Critical error executing yt-dlp for download. Command: `"$ytDlpPath`" $($ytDlpArgsForDownload -join ' '). Exception: $($_.Exception.ToString())"
            Resolve-ScriptError -UserMessage "A critical error occurred while trying to run yt-dlp for download." `
                               -InternalLogMessage $logMsg
            $continueResponse = 'y'; continue
        }

        if ($exitCodeDownload -eq 0) {
            Write-ErrorLog "yt-dlp download process completed successfully. Exit Code: $exitCodeDownload."
            $downloadOutputStringForParsing = $downloadProcessOutputLines -join [System.Environment]::NewLine
            $downloadedFileInTemp = $null

            $PrimaryPatterns = @(
                [regex]'\[Merger\] Merging formats into "(?<FileNameFromOutput>.*?)"',
                [regex]'\[ExtractAudio\] Destination: (?<FileNameFromOutput>.*?)$',
                [regex]'\[download\] Destination: (?<FileNameFromOutput>.*?)$',
                [regex]'\[download\] (?<FileNameFromOutput>.*?) has already been downloaded'
            )

            foreach ($pattern in $PrimaryPatterns) {
                $match = $pattern.Match($downloadOutputStringForParsing)
                if ($match.Success) {
                    $filePathFromOutputRaw = $match.Groups["FileNameFromOutput"].Value.Trim()
                    $fileNameFromOutputRawLeaf = Split-Path $filePathFromOutputRaw -Leaf

                    if (-not $fileNameFromOutputRawLeaf) {
                        Write-ErrorLog "Could not extract leaf name from raw path reported by yt-dlp pattern '$($pattern.ToString())': $filePathFromOutputRaw"
                        continue
                    }

                    $normalizedFileNameFromOutputLeaf = Convert-FileNameToComparable $fileNameFromOutputRawLeaf
                    Write-ErrorLog "Normalized leaf from yt-dlp output pattern '$($pattern.ToString())' is: `"$normalizedFileNameFromOutputLeaf`" (Original raw leaf: `"$fileNameFromOutputRawLeaf`")"

                    $tempFilesListForThisCheck = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue
                    if ($tempFilesListForThisCheck) {
                        foreach ($fileInTempActual in $tempFilesListForThisCheck) {
                            $normalizedActualFileInTempLeaf = Convert-FileNameToComparable $fileInTempActual.Name
                            if ($normalizedActualFileInTempLeaf -eq $normalizedFileNameFromOutputLeaf) {
                                $downloadedFileInTemp = $fileInTempActual.FullName
                                Write-ErrorLog "File confirmed by normalized matching of yt-dlp output leaf: $downloadedFileInTemp. Matched '$normalizedActualFileInTempLeaf' with '$normalizedFileNameFromOutputLeaf'."
                                break
                            }
                        }
                    }
                    if ($downloadedFileInTemp) { break }
                }
            }
            
            if (-not $downloadedFileInTemp) {
                 Write-ErrorLog "Primary pattern matching (revised) from download output failed. Trying normalized name comparison for files in Temp using video title..."
                 $tempFilesList = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue
                 $expectedFinalFileNamePatternFromOutput = ""

                 $mergerMatchForTitle = ([regex]'\[Merger\] Merging formats into "(?<FileNameFromOutput>.*?)"').Match($downloadOutputStringForParsing)
                 $extractAudioMatchForTitle = ([regex]'\[ExtractAudio\] Destination: (?<FileNameFromOutput>.*?)$').Match($downloadOutputStringForParsing)

                 if ($mergerMatchForTitle.Success) { 
                    $expectedFinalFileNamePatternFromOutput = Split-Path ($mergerMatchForTitle.Groups["FileNameFromOutput"].Value.Trim()) -Leaf 
                    Write-ErrorLog "For title-based fallback, using leaf from Merger: $expectedFinalFileNamePatternFromOutput"
                 }
                 elseif ($extractAudioMatchForTitle.Success) { 
                    $expectedFinalFileNamePatternFromOutput = Split-Path ($extractAudioMatchForTitle.Groups["FileNameFromOutput"].Value.Trim()) -Leaf 
                    Write-ErrorLog "For title-based fallback, using leaf from ExtractAudio: $expectedFinalFileNamePatternFromOutput"
                 }
                 else { 
                    $expectedFinalFileNamePatternFromOutput = $videoInfo.title + (if ($isAudioOnlySelected) {".mp3"} else {".mp4"})
                    Write-ErrorLog "For title-based fallback, constructed name from videoInfo.title: $expectedFinalFileNamePatternFromOutput"
                 }
                 
                 if ($expectedFinalFileNamePatternFromOutput) {
                     $normalizedExpectedName = Convert-FileNameToComparable $expectedFinalFileNamePatternFromOutput
                     Write-ErrorLog "Normalized expected name for comparison (from title/fallback): `"$normalizedExpectedName`""
                     if ($tempFilesList) {
                         foreach ($fileInTempDir in $tempFilesList) {
                             $normalizedFileInTempDirName = Convert-FileNameToComparable $fileInTempDir.Name
                             if ($normalizedFileInTempDirName -eq $normalizedExpectedName) {
                                 $downloadedFileInTemp = $fileInTempDir.FullName
                                 Write-ErrorLog "File re-confirmed by normalized name comparison (from title/fallback): $downloadedFileInTemp"
                                 break
                             }
                         }
                     } else {
                        Write-ErrorLog "Temp directory is empty or inaccessible for title-based fallback check."
                     }
                 }
            }
            
            if (-not $downloadedFileInTemp) {
                Write-ErrorLog "Normalized name comparison (from title/fallback) also failed. Trying yt-dlp --print filename..."
                $ytDlpArgsForPrint = New-Object System.Collections.Generic.List[string]
                $ytDlpArgsForPrint.Add("--no-download"); $ytDlpArgsForPrint.Add("--no-warnings"); $ytDlpArgsForPrint.Add("--print"); $ytDlpArgsForPrint.Add("filename")
                $ytDlpArgsForPrint.Add("-o"); $ytDlpArgsForPrint.Add($ytdlpOutputTemplate)
                if (-not $isAudioOnlySelected) {
                    $ytDlpArgsForPrint.Add("-f"); $ytDlpArgsForPrint.Add($formatStringForDownload); $ytDlpArgsForPrint.Add("--merge-output-format"); $ytDlpArgsForPrint.Add("mp4")
                } else {
                    $ytDlpArgsForPrint.Add("-f"); $ytDlpArgsForPrint.Add("bestaudio"); $ytDlpArgsForPrint.Add("--extract-audio"); $ytDlpArgsForPrint.Add("--audio-format"); $ytDlpArgsForPrint.Add("mp3")
                }
                $ytDlpArgsForPrint.Add($currentUrl)
                Write-ErrorLog "Executing Print Filename: `"$ytDlpPath`" $($ytDlpArgsForPrint -join ' ')"
                $determinedPathArray = & $ytDlpPath $ytDlpArgsForPrint 2>$null 
                
                if ($LASTEXITCODE -eq 0 -and $determinedPathArray -and $determinedPathArray.Count -gt 0) {
                    $determinedPathRaw = ($determinedPathArray | Select-Object -First 1).Trim()
                    $determinedLeaf = Split-Path $determinedPathRaw -Leaf
                    $normalizedDeterminedLeaf = Convert-FileNameToComparable $determinedLeaf
                    Write-ErrorLog "yt-dlp --print filename provided leaf '$determinedLeaf', normalized to '$normalizedDeterminedLeaf'. Raw full path: '$determinedPathRaw'"
                    
                    # Compare normalized --print filename leaf with normalized actual files in Temp
                    $tempFilesListForPrintCheck = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue
                    if ($tempFilesListForPrintCheck) {
                        foreach ($fileInTempActual_Print in $tempFilesListForPrintCheck) {
                            $normalizedActualFileInTempLeaf_Print = Convert-FileNameToComparable $fileInTempActual_Print.Name
                            if ($normalizedActualFileInTempLeaf_Print -eq $normalizedDeterminedLeaf) {
                                $downloadedFileInTemp = $fileInTempActual_Print.FullName
                                Write-ErrorLog "File confirmed by --print filename and normalized comparison: $downloadedFileInTemp"
                                break 
                            }
                        }
                    }

                    if (-not $downloadedFileInTemp -and (Test-Path $determinedPathRaw)) {
                        $downloadedFileInTemp = $determinedPathRaw
                        Write-ErrorLog "File confirmed by --print filename (direct Test-Path on raw path): $downloadedFileInTemp. This was a fallback."
                    } elseif (-not $downloadedFileInTemp) {
                         Write-ErrorLog "Normalized comparison for --print filename failed, and direct Test-Path on '$determinedPathRaw' also failed."
                         $expectedExtension = if ($isAudioOnlySelected) { ".mp3" } else { ".mp4" }
                         $baseName = [System.IO.Path]::GetFileNameWithoutExtension($determinedPathRaw)
                         $potentialFileWithCorrectExt = Join-Path $tempDir ($baseName + $expectedExtension)
                         if (Test-Path $potentialFileWithCorrectExt) {
                             $downloadedFileInTemp = $potentialFileWithCorrectExt
                             Write-ErrorLog "Corrected extension from --print filename. Found: $downloadedFileInTemp. Original print: $determinedPathRaw"
                         } else {
                             Write-ErrorLog "yt-dlp --print filename provided '$determinedPathRaw' (or corrected '$potentialFileWithCorrectExt'), but file does not exist in Temp folder via Test-Path."
                         }
                    }
                } else {
                     Write-ErrorLog "yt-dlp --print filename command failed or returned no output. Exit Code: $LASTEXITCODE. Output: $($determinedPathArray -join ', ')"
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
                $logMsg = "yt-dlp download process completed (Exit Code $exitCodeDownload), but script could not identify/locate the downloaded file in '$tempDir' after all attempts. Full download output for parsing was: $downloadOutputStringForParsing"
                Resolve-ScriptError -UserMessage "Download seemed to complete (check console), but the script could not find the final file in 'Temp' to move it. Please check 'Temp' folder." `
                                   -InternalLogMessage $logMsg
                $tempFiles = Get-ChildItem -Path $tempDir -File -ErrorAction SilentlyContinue
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