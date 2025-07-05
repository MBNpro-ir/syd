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

---

## 🌟 What Makes This Special?

**Simple YouTube Downloader** isn't just another downloader - it's a comprehensive solution engineered for reliability, ease of use, and advanced functionality. Built with enterprise-grade error handling and smart user validation.

### 🔥 Key Highlights
- **🧠 Intelligent Error Management**: 15+ error types with specific solutions
- **✅ Smart Input Validation**: Prevents user mistakes before they happen  
- **⚡ Lightning Fast Caching**: Instant video info retrieval for repeated downloads
- **🔐 Advanced Authentication**: Cookie support for private/age-restricted content
- **🌐 Enterprise Proxy Support**: Works behind corporate firewalls
- **🎯 Format Perfection**: Support for 8K, HDR, AV1, and all modern codecs
- **🛡️ Bulletproof Downloads**: Multiple fallback mechanisms ensure success

---

## ✨ Feature Showcase

### 🎬 **Video Downloads**
- **All Resolutions**: 144p to 8K (4320p) support
- **Modern Codecs**: H.264, H.265/HEVC, VP9, AV1
- **HDR Support**: HDR10, Dolby Vision compatible
- **Smart Merging**: Automatic best video + audio combination
- **Subtitle Support**: Download with embedded or separate subtitles

### 🎵 **Audio Extraction**
- **Multiple Qualities**: 128k, 256k, 320k MP3
- **Lossless Options**: FLAC, WAV support
- **Smart Conversion**: Preserves maximum quality
- **Metadata Preservation**: Artist, title, thumbnail embedding

### 🖼️ **Thumbnail & Covers**
- **Highest Quality**: Up to 4K thumbnail downloads
- **Multiple Formats**: JPG, PNG, WebP support
- **Smart Detection**: Automatic best quality selection
- **Batch Support**: Download covers for playlists

### 🚀 **Performance & Reliability**
- **Smart Caching**: 10x faster repeated operations
- **Progress Tracking**: Real-time download progress with ETA
- **Automatic Retries**: Intelligent failure recovery
- **Network Optimization**: Adaptive speed and connection handling

### 🔒 **Security & Authentication**
- **Cookie Integration**: Import from Chrome, Firefox, Edge
- **Private Content**: Age-restricted and member-only videos
- **Proxy Support**: HTTP/HTTPS/SOCKS proxy compatibility
- **Safe Operations**: Sandboxed downloads with cleanup

---

## 🛠️ Installation & Setup

### **Option 1: Direct Download from Releases (Fastest & Recommended)**
1. **Go to [Releases Page](https://github.com/MBNpro-ir/syd/releases/latest)**
2. **Download `syd.bat`** directly from the latest release
3. **Double-click `syd.bat`** or run from command line: `.\syd.bat`
4. **Done!** The script will automatically download the latest version and run

### **Option 2: Download via PowerShell**
```powershell
# Download the batch file launcher
Invoke-WebRequest -Uri "https://github.com/MBNpro-ir/syd/releases/latest/download/syd.bat" -OutFile "syd.bat"
# Run it (double-click or command line)
.\syd.bat
```

**Features of syd.bat:**
- 🚀 **Direct Launch**: No menu needed - launches directly!
- 🔄 **Auto-Update**: Always downloads the latest version automatically
- 🖥️ **Desktop Shortcut**: Automatically creates a desktop shortcut for easy access
- 🎨 **User-Friendly**: Colorful interface with error handling
- 📁 **Auto-Organize**: Downloads files and automatically opens the folder

### **Option 3: Direct PowerShell (Advanced Users)**
```powershell
# Download and run the latest version
Invoke-WebRequest -Uri "https://github.com/MBNpro-ir/syd/releases/latest/download/syd.ps1" -OutFile "syd.ps1"
.\syd.ps1
```

### **Option 4: Git Clone (Developers)**
```bash
git clone https://github.com/MBNpro-ir/syd.git
cd syd
.\syd.ps1
```

### **System Requirements**
- ✅ Windows 10/11 (PowerShell 5.1+)
- ✅ Internet connection
- ✅ 100MB free disk space
- ✅ Admin rights (for first-time setup)

### **📋 Using syd.bat - Direct Launch**

When you run `syd.bat`, it will automatically:

1. **Create SYD folder** if it doesn't exist
2. **Download latest version** of syd.ps1 into the SYD folder
3. **Launch the downloader** immediately
4. **Create desktop shortcut** for easy future access

**No menu needed** - it launches directly to the YouTube downloader!

**Benefits:**
- 🚀 **Instant Launch**: No menu navigation needed
- 🔄 **Always Latest**: Auto-downloads the newest version
- 🖥️ **Desktop Shortcut**: Creates shortcut automatically with logo icon
- 🎨 **User-Friendly**: Colorful interface with error handling
- 📁 **Auto-Open Folder**: Opens download folder automatically after each download

**🔁 Re-running the Program:**
- You can run `.\syd.bat` again anytime from PowerShell or CMD
- Or use the desktop shortcut created automatically
- Each time it will check for updates and launch the latest version

### **🔒 Windows 11 PowerShell Execution Policy Setup**

**⚠️ Important Notice for Windows 11 Users:**
Windows 11 may block PowerShell script execution by default. If you encounter errors like:
- `"Execution of scripts is disabled on this system"`
- `"UnauthorizedAccess"`
- `"ExecutionPolicy restriction"`

**🛠️ Solution: Temporarily Allow Script Execution**

**Step 1: Check Current Policy**
```powershell
# Run PowerShell as Administrator and check current policy
Get-ExecutionPolicy
```

**Step 2: Temporarily Allow Script Execution**
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Or for all users (requires admin):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

**Step 3: Run SYD**
```powershell
# Now you can run syd.bat without issues
.\syd.bat
```

**Step 4: Restore Original Security Settings (Recommended)**
```powershell
# After using SYD, restore original policy for security
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
# Or for all users:
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine
```

**🔄 Quick Commands Summary:**
```powershell
# Allow execution
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Use SYD
.\syd.bat

# Restore security (when done)
Set-ExecutionPolicy Restricted -Scope CurrentUser
```

**📝 Execution Policy Options Explained:**
- **Restricted**: No scripts allowed (Windows 11 default)
- **RemoteSigned**: Local scripts allowed, downloaded scripts need signature
- **Unrestricted**: All scripts allowed (not recommended)

**🎯 Pro Tip:** Use `CurrentUser` scope to avoid affecting other users on the system.

---

## 🎯 Quick Start Guide

### **Step 1: Launch the Application**

**Method A: Using syd.bat (Recommended)**
```powershell
# Double-click syd.bat or run from command line
.\syd.bat
# It will launch directly - no menu needed!
```

**Method B: Desktop Shortcut (After first run)**
- Use the desktop shortcut created automatically
- Double-click "SYD - YouTube Downloader" on your desktop

**Method C: Direct PowerShell**
```powershell
.\syd.ps1
```

**🔁 Running Again:**
You can run `.\syd.bat` anytime from PowerShell or CMD to launch the program again.

### **Step 2: Enter YouTube URL**
```
📥 Enter YouTube URL (or command): https://www.youtube.com/watch?v=dQw4w9WgXcQ
```

### **Step 3: Choose Your Format**
```
⭐ QUICK OPTIONS
────────────────
  1. 🏆 Best Quality (Recommended - Merges best video + best audio)
  2. 🎥 4K Ultra HD (3840x2160) - H.264
  3. 🎥 1080p Full HD (1920x1080) - H.264
  4. 💎 MP3 - 320 kbps (Studio Quality)
  5. 🖼️ Download Thumbnail
```

### **Step 4: Enjoy Your Content!**
Files are automatically organized in the `Downloaded` folder:
- 📁 `Downloaded/Video/` - Video files
- 📁 `Downloaded/Audio/` - Audio files  
- 📁 `Downloaded/Covers/` - Thumbnails

**🎉 Bonus Features:**
- 📁 **Auto-Open Folder**: The download folder opens automatically after each download
- 🖥️ **Desktop Shortcut**: A shortcut is created on your desktop for easy access
- 🔄 **Always Updated**: Each run checks for and downloads the latest version

---

## 🚀 Different Ways to Run SYD

### **🖥️ Desktop Shortcut (Easiest)**
- After first run, use the desktop shortcut "SYD - YouTube Downloader"
- Double-click to launch instantly
- Features custom logo icon (if logo.png exists)

### **💻 Command Line**
```powershell
# From PowerShell or CMD
.\syd.bat
```

### **📂 File Explorer**
- Double-click `syd.bat` in File Explorer
- No command line needed

### **🔁 Re-running**
- You can run `.\syd.bat` multiple times
- Each time it will check for updates and launch the latest version
- Use any of the above methods whenever you want to download videos

---

## ⚙️ Advanced Configuration

### **Settings.json Configuration**
The script automatically creates a `settings.json` file for advanced users:

```json
{
  "general": {
    "request_timeout_seconds": 20,
    "max_retries": 3,
    "use_database_cache": true
  },
  "proxy": {
    "use_system_proxy": true,
    "custom_proxy_enabled": false,
    "custom_proxy_host": "",
    "custom_proxy_port": 8080
  },
  "cookies": {
    "use_cookies": true,
    "cookie_file_path": "cookies.txt"
  },
  "download": {
    "temp_directory": "Temp",
    "output_directory": "Downloaded",
    "video_subdirectory": "Video",
    "audio_subdirectory": "Audio",
    "covers_subdirectory": "Covers"
  },
  "advanced": {
    "enable_debug_logging": true,
    "cleanup_temp_files": true,
    "log_file_path": "debug.txt"
  }
}
```

### **Cookie Setup for Private Content**
1. **Export cookies** from your browser using a cookie extension
2. **Save as** `cookies.txt` in the script directory
3. **Enable cookies** in settings.json (`"use_cookies": true`)
4. **Download private/age-restricted content** seamlessly

### **Proxy Configuration**
```json
{
  "proxy": {
    "custom_proxy_enabled": true,
    "custom_proxy_host": "proxy.company.com",
    "custom_proxy_port": 8080
  }
}
```

---

## 🆘 Troubleshooting & Error Solutions

### **🔍 Common Errors & Solutions**

| **Error Type** | **Symptoms** | **Solutions** |
|---|---|---|
| **🚫 Access Denied (HTTP 403)** | "The video server rejected the download request" | • Use cookies from browser<br>• Check if video is age-restricted<br>• Try VPN for region-blocked content |
| **⏱️ Rate Limited (HTTP 429)** | "Too many requests sent to server" | • Wait 15-30 minutes<br>• Use different IP/VPN<br>• Try at different time |
| **📺 Video Not Found (404)** | "Video no longer exists" | • Check URL spelling<br>• Video might be deleted/private<br>• Try accessing in browser first |
| **🔒 Age Restricted** | "Sign in to confirm your age" | • Export cookies from logged-in browser<br>• Use --cookies-from-browser option<br>• Sign in to YouTube first |
| **🌐 Network Timeout** | "Connection timed out" | • Check internet connection<br>• Try VPN/proxy<br>• Retry when network is stable |
| **🎵 Missing Codec** | "Unknown encoder" or "codec not supported" | • Update ffmpeg to latest version<br>• Download complete ffmpeg build<br>• Use different output format |
| **📁 Permission Denied** | "Access denied" or "insufficient permissions" | • Run as administrator<br>• Check folder permissions<br>• Choose different download location |

### **🚑 Emergency Commands**
```
help          - Show detailed help guide
exit          - Exit the program
clear-cache   - Clear video information cache
```

### **📋 Debug Information**
- **Debug Log**: Check `debug.txt` for detailed error information
- **System Info**: Script automatically logs system and network details
- **Error Context**: Every error includes specific solutions

---

## 🎓 Pro Tips & Advanced Usage

### **⚡ Performance Optimization**
```json
{
  "general": {
    "use_database_cache": true,    // 10x faster repeated downloads
    "max_retries": 5,              // Better reliability
    "request_timeout_seconds": 30   // For slow connections
  }
}
```

### **🔒 Corporate Network Setup**
```json
{
  "proxy": {
    "use_system_proxy": true,
    "custom_proxy_enabled": true,
    "custom_proxy_host": "corporate-proxy.com",
    "custom_proxy_port": 8080
  }
}
```

### **📱 Playlist & Channel Downloads**
```
📥 Enter YouTube URL: https://www.youtube.com/playlist?list=...
📥 Enter YouTube URL: https://www.youtube.com/@channelname
```

### **🎯 Quality Selection Guide**
- **🏆 Best Quality**: Automatic best video + audio (recommended)
- **4K/8K**: For large screens and future-proofing
- **1080p**: Perfect balance of quality and file size
- **720p**: Good for mobile devices and limited storage
- **Audio Only**: For music, podcasts, and audio content

---

## 🤝 Contributing & Support

### **🐛 Found a Bug?**
1. Check `debug.txt` for error details
2. Note the YouTube URL and selected options
3. Create an issue with full details

### **💡 Feature Request?**
We welcome suggestions for new features and improvements!

### **📞 Get Help**
- **Telegram**: [@mbnproo](https://t.me/mbnproo) - Direct support from developer
- **Issues**: [GitHub Issues](https://github.com/MBNpro-ir/syd/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MBNpro-ir/syd/discussions)

---

## 📈 What's New in Version 2.0

### **🚀 Streamlined Experience**
- **Direct Launch**: No menu navigation - launches directly to downloader
- **Auto-Open Folders**: Downloaded files' folders open automatically
- **Desktop Shortcut**: Automatic shortcut creation with custom logo
- **Smart Organization**: Files organized in SYD folder structure

### **🧠 Enhanced Error Handling**
- **15+ Error Types**: Specific solutions for each error category
- **Smart Recovery**: Automatic retry with different methods
- **User Guidance**: Clear explanations and step-by-step solutions

### **✅ Input Validation**
- **URL Verification**: Automatic YouTube URL validation
- **Choice Validation**: No more invalid menu selections
- **Retry Logic**: Multiple attempts for user input

### **⚡ Performance Improvements**
- **Smart Caching**: 10x faster video info retrieval
- **Optimized Downloads**: Better speed and reliability
- **Memory Management**: Reduced resource usage

### **🔒 Security Enhancements**
- **Cookie Support**: Secure authentication handling
- **Proxy Integration**: Corporate network compatibility
- **Safe Downloads**: Sandboxed operations

---

## 📜 License & Credits

### **License**
MIT License - Feel free to use, modify, and distribute

### **Credits**
- **yt-dlp**: Core download engine
- **ffmpeg**: Media processing
- **MBNPRO**: Development and maintenance

### **Dependencies**
- All dependencies are automatically downloaded and managed
- No manual installation required
- Always uses latest stable versions

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
