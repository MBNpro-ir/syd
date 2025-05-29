<div align="center">
  <h1>🚀 syd.ps1 - Simple YouTube Downloader 🚀</h1>
  <p>
    <strong>Your friendly PowerShell companion for effortlessly downloading YouTube videos and audio!</strong>
  </p>
  <p>
    Tired of complicated downloaders? syd.ps1 offers a clean, interactive command-line experience to grab your favorite content directly from YouTube, with automatic setup of necessary tools.
  </p>
  <img src="https://img.shields.io/badge/PowerShell-%3E%3D5.1-blue.svg" alt="PowerShell Version">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</div>

## ✨ About The Script

**syd.ps1** is a PowerShell script designed to simplify the process of downloading videos and audio from YouTube. It provides an interactive menu to choose between available video qualities or to download audio-only (as MP3). The script is smart enough to automatically download and place `yt-dlp.exe` (the core downloader) and `ffmpeg.exe` (for audio extraction and merging) if they are not found in its directory, making the initial setup a breeze!

### Key Features:
*   🎬 **Video Downloads**: Choose from available resolutions (e.g., 1080p, 720p) and save as MP4.
*   🎵 **Audio Downloads**: Extract and save audio directly as MP3.
*   ⚙️ **Automatic Tool Setup**: Downloads `yt-dlp.exe` and `ffmpeg.exe` on first run if not detected.
*   📂 **Organized Storage**:
    *   Downloads are initially stored in a `Temp` folder within the script's directory.
    *   Completed videos are moved to `Downloaded\Video`.
    *   Completed audio files are moved to `Downloaded\Audio`.
*   🙋 **Interactive Menu**: User-friendly prompts for URL input and quality selection.
*   📜 **In-Script Help**: Type `-h` or `help` at the URL prompt for quick instructions.
*   🛠️ **Error Logging**: Creates a `debug.txt` file for troubleshooting, with clear instructions for seeking help.
*   🎨 **Custom Console Theme**: A distinct dark theme for a pleasant user experience.
*   🌐 **Unicode Support**: Designed to handle video titles with various characters (UTF-8).

## 🛠️ Prerequisites

1.  **Windows Operating System**: This is a PowerShell script.
2.  **PowerShell**: Version 5.1 or higher (usually pre-installed on Windows 10 and later).
    *   To check your PowerShell version, open PowerShell and type: `$PSVersionTable.PSVersion`
3.  **Internet Connection**: Required for:
    *   Downloading `syd.ps1` (if using `syd.bat`), `yt-dlp.exe`, and `ffmpeg.exe` (on first run or if they are missing).
    *   Fetching video information from YouTube.
    *   Downloading the video/audio content.
4.  **Script Execution Policy (if running `syd.ps1` directly)**: You might need to set your PowerShell execution policy. If you encounter an error about script execution being disabled when running `.\syd.ps1` directly, open PowerShell **as an Administrator** and run one of the following:
    *   `Set-ExecutionPolicy RemoteSigned` (Recommended)
    *   `Set-ExecutionPolicy Unrestricted` (Less secure)
    The `syd.bat` launcher attempts to bypass this for its session. You can type `Get-ExecutionPolicy` to see your current policy.

_Note: `yt-dlp.exe` and `ffmpeg.exe` are downloaded automatically by the `syd.ps1` script if not found in the same directory._

## 🚀 How to Use

**Method 1: Using the `syd.bat` Launcher (Recommended for ease of use)**

This is the simplest way to get started and ensures you're always using the latest version of the script.

1.  **Download the Launcher**:
    *   Download the `syd.bat` file from the [Releases page](https://github.com/MBNpro-ir/syd/releases/latest) of this repository.
    *   Place `syd.bat` in a folder of your choice (e.g., `C:\Users\YourName\YouTubeDownloads`).

2.  **Run the Launcher**:
    *   Simply double-click on the `syd.bat` file.
    *   The first time you run it, the launcher will download the latest `syd.ps1` script into the same folder. On subsequent runs, it will re-download to ensure you have the newest version.
    *   A PowerShell window will open, and the `syd.ps1` script will start.

3.  **Follow Interactive Prompts (within the PowerShell window)**:
    *   **Enter YouTube Link**: When prompted, paste the full URL of the YouTube video you want to download (e.g., `https://www.youtube.com/watch?v=dQw4w9WgXcQ`).
        *   Type `exit` to quit the script.
        *   Type `-h` or `help` to display the script's help message.
    *   **Select Quality**: A menu will appear showing available video qualities and an audio-only option. Enter the number corresponding to your choice.
    *   **Download Process**: `yt-dlp` will show its live download progress in the console.
    *   **Completion**: Upon successful download and processing, the script will inform you where the file has been saved (`Downloaded\Video` or `Downloaded\Audio` relative to where `syd.bat` and `syd.ps1` are located).
    *   **Download Another?**: You'll be asked if you want to download another file. Type `y` for yes or `n` for no.

**Method 2: Running `syd.ps1` Directly (For advanced users or if `.bat` fails)**

1.  **Download the Script**:
    *   Download the `syd.ps1` file from the [Releases page](https://github.com/MBNpro-ir/syd/releases/latest) (or clone the repository).
    *   Place it in a folder of your choice.

2.  **Run the Script via PowerShell**:
    *   Open PowerShell.
    *   Navigate to the directory where you saved `syd.ps1`. For example:
        ```powershell
        cd C:\Users\YourName\YouTubeDownloads
        ```
    *   Execute the script:
        ```powershell
        .\syd.ps1
        ```
    *   Follow the interactive prompts as described in Method 1.

3.  **Command-Line Help (for `syd.ps1`)**:
    *   To view the script's help message directly from the command line without starting the interactive download process, run:
        ```powershell
        .\syd.ps1 -h
        ```
        or
        ```powershell
        .\syd.ps1 -Help
        ```

**Output Folders (created where `syd.ps1` is run from)**:
*   `Temp`: Files are temporarily stored here during download and processing.
*   `Downloaded\Video`: Final MP4 video files are moved here.
*   `Downloaded\Audio`: Final MP3 audio files are moved here.
*   `debug.txt`: Logs errors and key actions.

## 🤔 Troubleshooting Common Errors

If you encounter issues, the first place to look is the `debug.txt` file created in the script's directory. It often contains detailed error messages from `yt-dlp` or the script itself.

| Error Message (or Symptom)                                  | Possible Cause & Solution                                                                                                                                                                                                                                                           |
| :---------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Script execution is disabled on this system.** (when running `.\syd.ps1` directly) | Your PowerShell execution policy is too restrictive. Open PowerShell **as Administrator** and run `Set-ExecutionPolicy RemoteSigned`. Confirm with `Y`. The `syd.bat` launcher tries to bypass this. |
| **Failed to download `syd.ps1` (by `syd.bat`), `yt-dlp.exe`, or `ffmpeg.exe`.** | <ul><li>**Network Issue**: Check your internet connection.</li><li>**Firewall/Antivirus**: Your security software might be blocking the download. Temporarily disable it or add an exception for PowerShell/`syd.bat` and the script's directory.</li><li>**Source URL Changed/Unavailable**: The GitHub URLs might have changed or the release asset might be missing. Check the script/`.bat` file for the correct URL or report the issue.</li></ul> |
| **Could not retrieve video information.** (from script)     | <ul><li>**Invalid URL**: Double-check the YouTube link.</li><li>**Private/Deleted Video**: The video might be private, deleted, or geo-restricted.</li><li>**YouTube Changes**: YouTube sometimes updates its site, which can temporarily break `yt-dlp`. Try again later. If the issue persists, `yt-dlp` might need an update. You can try deleting `yt-dlp.exe` from the script's folder; `syd.ps1` will attempt to download the latest version on its next run.</li><li>**Network Issue**: Temporary internet connectivity problem.</li></ul> |
| **`yt-dlp` shows errors like "Video unavailable", "This video is private", etc.** | This is an error from `yt-dlp` itself, indicating an issue with accessing the video content as described above. The script can't bypass these.                                                                                                                                   |
| **Download process seemed to complete, but script could not find the final file in `Temp`.** | <ul><li>**Permissions**: Ensure the script has write/delete permissions for the `Temp` and `Downloaded` folders.</li><li>**Unusual Filenames**: Very long or extremely unusual characters in video titles *could* cause issues. The `debug.txt` might show the filename `yt-dlp` attempted to use.</li><li>**`yt-dlp` Bug/Edge Case**: Rare, but `yt-dlp` might output a filename that differs slightly from what it actually creates. The script has several fallback methods.</li></ul> |
| **Failed to move the downloaded file from `Temp`...**       | <ul><li>**Permissions**: As above.</li><li>**File in Use**: Another program might have locked the file in the `Temp` folder.</li><li>**Path Too Long**: Extremely long video titles combined with long directory paths can exceed Windows' maximum path length. Try running the script/`.bat` from a directory with a shorter path (e.g., `C:\YT`).</li></ul> |
| **`yt-dlp.exe: error: invalid audio format` (when selecting audio)** | This was a bug in older versions of `syd.ps1`. Ensure you have the latest versions from `syd.bat`. If it persists, it's an unexpected script error.                                                                                                                                                |
| **`The term 'yt-dlp.exe' (or 'ffmpeg.exe') is not recognized...`** | The script couldn't find the required executable. This usually means the auto-download within `syd.ps1` failed, or the file was deleted. Delete `yt-dlp.exe` and/or `ffmpeg.exe` from the script's folder and re-run to trigger a fresh download. Ensure your antivirus isn't quarantining them. |
| **PowerShell shows errors in red text not covered by the script's error handling.** | This indicates a more fundamental PowerShell syntax error or runtime exception within the `syd.ps1` script itself. Please report this!                                                                                                                                                |

### 🆘 Getting Help

If you encounter an error not listed above or if the solutions don't work:
1.  **Note down the YouTube URL** you were trying to download.
2.  **Note the quality/option** you selected.
3.  **Locate the `debug.txt` file** in the same directory as `syd.ps1` (or `syd.bat`).
4.  **Contact MBNPRO on Telegram: `https://t.me/mbnproo`** and provide the URL, your selection, and attach the `debug.txt` file. The more details, the better!

---

<div align="center">
  <p>Happy Downloading! 📥</p>
  <p>Created by MBNPRO</p>
</div>
