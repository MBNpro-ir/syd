<div align="center">
  <h1>🚀 SYD - Simple YouTube Downloader by MBNPRO 🚀</h1>
  <p>
    <strong>The Ultimate PowerShell YouTube Downloader with Advanced Error Handling & Smart Features</strong>
  </p>
  <p>
    Experience the most advanced YouTube downloader for Windows with intelligent error management, comprehensive format support, and bulletproof reliability.
  </p>
  
  ![PowerShell](https://img.shields.io/badge/PowerShell-%3E%3D5.1-blue.svg)
  ![License](https://img.shields.io/badge/License-MIT-green.svg)
  ![Version](https://img.shields.io/badge/Version-2.0%20Enhanced-orange.svg)
  ![Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)
</div>

## 🚀 Getting Started

This guide will get you up and running in minutes.

### 1. System Requirements
- **OS**: Windows 10/11
- **PowerShell**: Version 5.1 or newer
- **Permissions**: Administrator rights are required for the first-time setup to configure PowerShell policies and create a desktop shortcut.

### 2. Installation (Recommended Method)

The easiest way to install SYD is with the smart launcher script.

1.  **Open PowerShell**: Press `Win + R`, type `powershell`, and press Enter.
2.  **Run the Installer**: Copy and paste the following command into PowerShell and press Enter:

```powershell
Invoke-WebRequest -Uri "https://github.com/MBNpro-ir/syd/releases/latest/download/syd.bat" -OutFile "syd.bat"; .\syd.bat
```

This command downloads the `syd.bat` launcher and runs it immediately. On its first run, it will:
- ✅ Check and download the latest version of the core script.
- ✅ Create a `SYD` folder to keep all its files organized.
- ✅ Create a desktop shortcut named "SYD - YouTube Downloader" with a custom icon.
- ✅ Launch the downloader.

### 3. Windows PowerShell Execution Policy

If this is your first time running a PowerShell script, you might see an error like `"Execution of scripts is disabled on this system"`. This is a default security feature in Windows.

**To fix this, run PowerShell as Administrator and execute the following command:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
This command allows locally run scripts, which is safe and recommended for using SYD. You only need to do this once.

---

## 💻 How to Use SYD

### Running the Application

After the first run, you can launch SYD in several easy ways:
- **🥇 Desktop Shortcut (Easiest)**: Double-click the **"SYD - YouTube Downloader"** shortcut on your desktop.
- **File Explorer**: Double-click the `syd.bat` file.
- **Command Line**: Navigate to the folder where you saved `syd.bat` and run `.\syd.bat`.

Each time you run `syd.bat`, it intelligently checks for updates and launches the program instantly if everything is up-to-date.

### Downloading Your First Video

1.  **Enter URL**: Paste the YouTube video or playlist URL when prompted.
    ```
    📥 Enter YouTube URL (or command): https://www.youtube.com/watch?v=dQw4w9WgXcQ
    ```
2.  **Choose Format**: Select one of the quick options or explore more formats.
    ```
    ⭐ QUICK OPTIONS
    ────────────────
      1. 🏆 Best Quality (Recommended - Merges best video + best audio)
      2. 🎥 1080p Full HD (1920x1080) - H.264
      3. 💎 MP3 - 320 kbps (Studio Quality)
      4. 🖼️ Download Thumbnail
    ```
3.  **Done!**: Your file will be downloaded, and the `Downloaded` folder will automatically open for you.

Files are neatly organized into subdirectories: `Downloaded/Video/`, `Downloaded/Audio/`, and `Downloaded/Covers/`.

---

## ⚙️ Advanced Configuration

All advanced settings are managed in the `SYD` folder, which is created automatically.

### File Structure Overview
```
📁 Your User Folder on c:/Users/(Your windows username account)/
├── 📄 syd.bat                    # Main launcher file, safe to move
├── 📁 SYD/                       # Auto-created folder for all SYD files
│   ├── 📄 syd_latest.ps1         # The core PowerShell script
│   ├── 📄 settings.json          # All user configurations
│   ├── 📄 cookies.txt            # Place your exported cookies here
│   ├── 📄 video_cache.json       # Caches video metadata for speed
│   ├── 📄 logo.ico               # Icon for the desktop shortcut
│   ├── 📁 Temp/                      # Temporary files, cleaned automatically
│   ├── 📁 Downloaded/                # Your downloaded content
│        ├── 📁 Video/
│        ├── 📁 Audio/
│        └── 📁 Covers/
```

### Configuring `settings.json`

You can customize SYD's behavior by editing `SYD/settings.json`. The file is created with default settings on the first run. Below is a detailed explanation of all available settings.

---

### **General Settings**
Controls the core behavior of the script.

| Setting | Description | Possible Values | Default |
|---|---|---|---|
| `show_processing_messages` | Toggles the display of detailed processing messages during downloads (e.g., "Merging formats..."). | `true`, `false` | `true` |
| `request_timeout_seconds` | The maximum time (in seconds) to wait for a response from YouTube's servers. Increase this on slow connections. | Number (e.g., `30`) | `20` |
| `database_file` | The name of the file used for caching video metadata. | String (filename) | `"video_cache.json"` |
| `max_retries` | The number of times the script will retry a failed download. | Number (e.g., `5`) | `3` |
| `use_database_cache` | If `true`, caches video information to speed up repeated downloads of the same URL. | `true`, `false` | `true` |

### **Download Settings**
Defines where your files are stored.

| Setting | Description | Possible Values | Default |
|---|---|---|---|
| `output_directory` | The main folder for all downloaded content. | Path (e.g., `"D:\\Downloads"`) | `"Downloaded"` |
| `video_subdirectory` | The subfolder inside `output_directory` where videos are saved. | String (foldername) | `"Video"` |
| `audio_subdirectory` | The subfolder for saved audio files. | String (foldername) | `"Audio"` |
| `covers_subdirectory` | The subfolder for saved thumbnails. | String (foldername) | `"Covers"` |
| `temp_directory` | The folder for temporary files that are deleted after a successful download. | Path (e.g., `"./Temp"`) | `"Temp"` |

### **Cookie Settings**
Manages authentication for private and age-restricted content.

| Setting | Description | Possible Values | Default |
|---|---|---|---|
| `use_cookies` | If `true`, the script will look for and use the `cookies.txt` file. | `true`, `false` | `false` |
| `cookie_file_path` | The name of the cookie file. It should be placed in the `SYD` folder. | String (filename) | `"cookies.txt"` |
| `cookie_file_directory` | (Optional) Specify a custom directory for your cookie file if you don't want to place it in the `SYD` folder. | Path (e.g., `"C:\\MyCookies"`) | `""` (empty) |

### **Proxy Settings**
Configure for use on corporate or restricted networks.

| Setting | Description | Possible Values | Default |
|---|---|---|---|
| `use_system_proxy` | If `true`, SYD will automatically use the proxy configured in Windows settings. | `true`, `false` | `true` |
| `custom_proxy_enabled`| Set to `true` to manually specify a proxy server. | `true`, `false` | `false` |
| `custom_proxy_host` | The address of your custom proxy server. | String (e.g., `"proxy.mycompany.com"`) | `""` |
| `custom_proxy_port` | The port for your custom proxy. | Number (e.g., `8080`) | `""` |
| `custom_proxy_username`| (Optional) Username for proxy authentication. | String | `""` |
| `custom_proxy_password`| (Optional) Password for proxy authentication. | String | `""` |

### **Advanced Settings**
For debugging and fine-tuning.

| Setting | Description | Possible Values | Default |
|---|---|---|---|
| `enable_debug_logging` | If `true`, creates a `debug.txt` file with detailed logs for troubleshooting. | `true`, `false` | `false` |
| `log_file_path` | The name of the log file. | String (filename) | `"debug.txt"` |
| `cleanup_temp_files` | If `true`, automatically deletes temporary files after a download is complete. | `true`, `false` | `true` |
| `max_description_lines`| The maximum number of lines from the video description to display. | Number | `5` |

### 🍪 Using Cookies (For Age-Restricted & Private Content)

To download age-restricted, private, or member-only videos, you need to use cookies from your browser.

1.  **Install a Cookie Exporter Extension**:
    - For Chrome/Edge/Firefox, use an extension like **"Get cookies.txt LOCALLY"** or **"Cookie-Editor"**.
2.  **Export Your Cookies**:
    - Log in to YouTube in your browser.
    - Go to any YouTube page.
    - Click the extension's icon and export the cookies in **Netscape format**.
    - Save the file as exactly `cookies.txt`.
3.  **Place the File**:
    - Move your `cookies.txt` file into the `SYD` folder.
4.  **Enable in Settings**:
    - Open `SYD/settings.json` and ensure `"use_cookies"` is set to `true`.

SYD will now use these cookies to authenticate your requests. Remember to refresh your cookies every few weeks for best results.

### 🌐 Using a Proxy

If you are on a corporate or restricted network, you can configure a proxy in `SYD/settings.json`.

- **System Proxy**: By default, SYD tries to use your Windows system proxy (`"use_system_proxy": true`).
- **Custom Proxy**: To use a custom proxy, set `"custom_proxy_enabled": true` and fill in your proxy details (`host`, `port`, `username`, `password`) in the `proxy` section.

---

## �� Troubleshooting

| Error Type | Common Cause | Solution |
|---|---|---|
| **🚫 Access Denied (403)** | Age-restricted, private, or region-locked video. | **Use the cookie setup** described above. A VPN may also help for region-locked content. |
| **⏱️ Rate Limited (429)** | Too many download requests in a short time. | Wait 15-30 minutes before trying again. Using a VPN or proxy can also help. |
| **📺 Video Not Found (404)** | The video has been deleted or the URL is incorrect. | Double-check the URL. Try opening it in your browser first. |
| **📁 Permission Denied** | The script cannot write to the download folder. | Ensure you have write permissions for the folder. Running as Administrator can help, but changing folder permissions is a better long-term fix. |
| **🎵 Missing Codec** | `ffmpeg` might be missing or corrupted. | SYD downloads dependencies automatically. Try deleting the `Temp` folder to force a re-download of `ffmpeg`. |

For more detailed errors, check the **`debug.txt`** file located in the `SYD` folder.

---

## 🤝 Contributing & Support

- **Found a bug or have a feature request?** Please [open an issue](https://github.com/MBNpro-ir/syd/issues) on GitHub.
- **Need help?** Contact the developer directly on Telegram: [@mbnproo](https://t.me/mbnproo).

---

## 📜 License & Credits

- **License**: [MIT License](https://github.com/MBNpro-ir/syd/blob/main/LICENSE).
- **Core Engine**: This script relies on the powerful `yt-dlp` and `ffmpeg`, which are automatically managed for you.
- **Development**: Made with ❤️ by MBNPRO.

---

<div align="center">
  <h2>🎉 Ready to Download? Let's Go!</h2>
  <p>
    <strong>Download the latest version and start enjoying hassle-free YouTube downloads!</strong>
  </p>
  
  **[📥 Download Latest Release](https://github.com/MBNpro-ir/syd/releases/latest)**
  
  ---
  
  <p>
    <strong>Made with ❤️ by MBNPRO</strong><br>
    Follow on Telegram: <a href="https://t.me/mbnproo">@mbnproo</a>
  </p>
  
  <p>
    ⭐ <strong>Star this repo if you found it helpful!</strong> ⭐
  </p>
</div>
