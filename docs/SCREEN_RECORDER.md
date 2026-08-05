# 🎥 Screen Recorder User Manual

Welcome to the **Screen Recorder** user guide for Mac ASC. This module allows you to record your screen directly from the menu bar with custom configurations, zero third-party dependencies, and 100% local processing.

---

## 🔍 Key Capabilities

1. **Native Screen Recording Engine**:
   - Built natively using macOS **AVFoundation** framework for ultra-lightweight recording performance and hardware-accelerated **HEVC (H.265)** video compression (`.mp4`) for 50% smaller sizes.

2. **Configurable Preferences**:
   - **Resolution Presets**: Record in native monitor resolution, standard **1080p**, or lightweight **720p**.
   - **Capture Area**: Toggle between capturing your **Full Screen** or a **Window/Selected Region** (75% center of main screen).
   - **Frame Rate (FPS)**: Choose between **30 FPS** or ultra-smooth **60 FPS** recordings.
   - **Video Quality (HEVC Bitrate Control)**: 
     - `Low`: Highly compressed tiny file size (600 Kbps target).
     - `Medium`: Balanced profile for excellent quality and small size (1.4 Mbps target - **Recommended**).
     - `High`: High quality (3.0 Mbps target).
     - `Ultra`: Pristine detail, near-lossless clarity for sharp text legibility (12.0 Mbps target).
   - **Microphone Input**: Toggle voice commentary recording on or off.
   - **Save Location**: Customize where recordings are saved using a native macOS directory picker.

3. **Window Auto-Hiding Workflow**:
   - **Immediate Auto-Hide**: The Mac ASC dropdown window automatically collapses when recording starts or resumes, ensuring it is never captured in your video.
   - **Pause Auto-Restore**: Pausing the recording automatically reveals the utility window, allowing you to easily click resume or stop.

4. **In-App Recent Recordings**:
   - Lists the 5 most recent screen recordings from your designated folder.
   - Includes full scroll support when your recordings grow.
   - Click the **Play Button** (`play.fill`) to open the recording directly in Apple QuickTime Player.
   - Click the **Folder Button** (`folder`) to immediately reveal and highlight the video file in Finder.

---

## 🛠️ Step-by-Step Usage & Examples

### Example 1: Recording Full Screen with Microphone Audio
1. Switch to the **Screen Recorder** tab (`⌘5`).
2. Set your Preferences:
   - **Resolution**: `Native` or `1080p`
   - **Capture Area**: `Full Screen`
   - **Frame Rate**: `60 FPS`
   - **Quality**: `Medium` (Recommended for high clarity at a compact size)
   - **Microphone**: Toggle to **On** (Mac ASC will prompt for macOS Microphone permission on first run).
3. Click the blue **Start Recording** button.
4. The Mac ASC window collapses immediately, and recording begins.
5. Press the menu bar icon (or click pause) to bring the controls back.
6. The control card displays **Pause/Resume** and **Stop** buttons with a live duration timer (`00:00:00`).
7. To finish, click **Stop**. The video is saved directly to your chosen directory and listed under **Recent Recordings**.

### Example 2: Changing Your Recording Save Directory
1. In the Screen Recorder panel, find the **Save Location** row under Recording Preferences.
2. Click the **Browse** button.
3. Choose a custom folder (e.g. `~/Downloads` or an external drive) from the native macOS panel.
4. Click **Select Save Directory**. All future recordings will go to this folder, and the recent recording list will update to show videos from it.

---

## 🔒 Security & Backup Guarantees

- **No Remote Telemetry**: Videos are saved purely locally on your hard drive. No clips are ever uploaded to cloud servers.
- **Backup Profile Inclusion**: Only your recording **preferences** (resolution, capture mode, FPS, quality, mic toggle, and save path) are included in the JSON backup file exported in Settings. The video files themselves are not backed up.
