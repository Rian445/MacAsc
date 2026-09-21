# Mac ASC

<p align="center">
  <b>A premium, ultra-lightweight macOS menu bar utility for disk insight, custom shell automation, quick notes, and multi-agent AI workflows.</b>
</p>

<p align="center">
  <a href="https://github.com/Rian445/MacAsc/releases/download/v2.0.0/Mac_ASC.dmg"><b>📥 Download Latest Release DMG (v2.0.0)</b></a> •
  <a href="#-quick-installation"><b>⚡ Quick Installation</b></a> •
  <a href="#-user-manuals--technical-guides"><b>📖 User Manuals</b></a> •
  <a href="PRIVACY.md"><b>🔒 Privacy Policy</b></a> •
  <a href="CHANGELOG.md"><b>📜 Changelog</b></a>
</p>

---

## 📸 Interface Preview

<p align="center">
  <img src="Screenshots/macasc.png" width="520" alt="Mac ASC Interface Preview"/>
</p>

---

## 🌟 What Makes Mac ASC Special?

Mac ASC combines system storage management, custom shell automation, instant note-taking, and AI CLI agents into a single **translucent glassmorphic menu bar utility**.

- ⚡ **0 MB Idle AI RAM**: Runs CLI AI agents on-demand with zero background memory waste.
- 🔒 **100% Private & Air-Gapped**: Zero analytics, zero telemetry, and zero tracking code.
- 🪟 **AppKit Glassmorphism**: Native backdrop-blur window layered with dark opacity tint.

---

## ✨ Core Features & Module Guides

### 📊 1. Categorized Disk Storage & Drive Insight
- **Visual Storage Breakdown**: Interactive progress bars categorizing Applications, Developer Caches (`.build`), Documents, Media, and System files.
- **External Volume Scanner**: Real-time detection of USB drives, SD cards, and Thunderbolt disks with one-click safe volume ejection.
- **Pinned Folder Tracker**: Pin custom directories to monitor size changes and jump directly to Finder.
- **Antigravity AI Quota Monitor**: High-precision 2-decimal quota tracking (`99.83%`) for Gemini and Claude + GPT with circular rings, reset countdowns, and a dedicated `↻` refresh button.
- 📖 *Want to learn more? Read the complete [Disk Insight User Manual](docs/DISK_INSIGHT.md).*

### ⚡ 2. Custom Shell Script Commands (Terminal & Silent Modes)
- **Nested Folder Subtrees**: Organize shell scripts using forward-slash folder paths (e.g. `DevOps/Docker`).
- **Visual Terminal Mode**: Opens scripts in a dedicated macOS `Terminal.app` window.
- **🔇 Silent Background Mode**: Toggle *"Run in Silent Mode"* to run scripts headlessly in the background via native Swift `Process()` with **zero Terminal popups**.
- **Live Stop Control**: Real-time running indicators (`stop.circle.fill`) and single-click Stop buttons for both Terminal and Silent background scripts.
- 📖 *Want to learn more? Read the complete [Custom Commands User Manual](docs/CUSTOM_COMMANDS.md).*

### 📝 3. Quick Notes & Read-Only Virtualization
- **Viewport Virtualization**: Instant 0ms load times and smooth scrolling for multi-megabyte note files via native `NSTextView` virtualization.
- **Folder Organization & Drag-Sort**: Organize notes into nested subfolders with drag-and-drop reordering.
- 📖 *Want to learn more? Read the complete [Quick Notes User Manual](docs/QUICK_NOTES.md).*

### 🤖 4. Multi-Model CLI AI Assistant
- **System CLI Compatibility**: Integrates directly with installed AI CLI tools (`opencode`, OpenAI `codex`, Google `antigravity` / `agy`).
- **Live Antigravity Quota Popover**: Pop open real-time usage metrics and reset countdowns directly from the chat header.
- **Unbiased Model Selection**: Clean model picker and favorites without forced defaults or hardcoded fallbacks.
- **Interactive Terminal Handoff**: Resume active chat threads directly in Terminal with `cd` workspace navigation.
- 📖 *Want to learn more? Read the complete [AI Assistant User Manual](docs/AI_ASSISTANT.md) and technical [AI Architecture Guide](AI_ARCHITECTURE.md).*

### 🎥 5. Native Screen Recorder & H.265 MOV Compression Engine
- **Hardware-Accelerated HEVC (H.265) .mov Output**: Native screen capture powered by AVFoundation utilizing macOS dedicated hardware encoders for up to 50% smaller sizes at pristine visual quality saved in standard QuickTime `.mov` format for instant WhatsApp and web sharing compatibility.
- **Interactive Crop Area Selector**: Choose capture mode (*Window* or *Full Screen*) to bring up an interactive, resizable neon-bordered crop selection overlay. Drag and resize to capture exactly what you need.
- **Fine-Tuned Configuration**: Select resolution (Native, 1080p, 720p), frame rates (30 FPS or 60 FPS), microphone toggle, and video quality bitrates (Low, Medium, High, Ultra up to 12 Mbps).
- **Custom Active Menu Bar Animations**: Choose your active recording menu bar animation (**Phoenix**, **Record**, or **Fire**) in Settings with native template white and color modes.
- **Pause/Resume & Auto-Hide Control**: Pause and resume recordings on-the-fly. The dropdown window auto-collapses during capture to stay out of your video frame and restores when paused or stopped.
- **Recent Recordings & Quick Actions**: Lists recent `.mov` and `.mp4` clips inside the scrollable section, allowing you to play instantly in QuickTime or reveal in Finder.
- 📖 *Want to learn more? Read the complete [Screen Recorder User Manual](docs/SCREEN_RECORDER.md).*

### ⏳ 6. Time Tracker & Event Countdowns
- **Future Countdowns & Past Milestones**: Create custom event timers (with title, target date & time picker).
- **Auto-Phrased Readouts**:
  - **Future Target**: `[Event Title] coming in X days Y hrs Z mins S secs` with a cyan `COMING IN` badge.
  - **Past Target**: `[Event Title] passed for X yrs Y days Z mins S secs` with an orange `PASSED FOR` badge.
- **Seamless Future ➔ Past Transition**: When a countdown passes its target date, it automatically transitions from `coming in` to `passed for` and counts up without stopping or freezing at zero.
- **0% Idle CPU & RAM Guarantee**: The 1-second UI countdown ticker is strictly active **only** while the dropdown window is open and the Time Tracker tab is selected. Closing the window or switching tabs instantly destroys the timer.

### ⌨️ 7. Customizable Tab Keyboard Shortcuts & Fixed Cmd+,
- **Instant Tab Switching**: Switch between tabs (`⌘1` Disk Insight, `⌘2` Commands, `⌘3` Quick Notes, `⌘4` Chat with AI, `⌘5` Screen Recorder, `⌘6` Time Tracker) when the Mac ASC panel is open.
- **Fixed Standard macOS Settings Shortcut (`⌘,`)**: Pressing `Command + Comma` (`⌘,`) anywhere in the app instantly toggles the Settings panel. Pressing any tab shortcut (`⌘1..6`) while in Settings automatically dismisses Settings and navigates to your requested tab.
- **Interactive Key Recorder**: Reassign shortcuts for any tab in Settings using a live key recorder badge.
- **Local Window Security**: Key monitoring runs strictly while the window is active, guaranteeing zero keylogging or collisions when closed.
- 📖 *Want to learn more? Read the complete [Keyboard Shortcuts User Manual](docs/KEYBOARD_SHORTCUTS.md) and [Privacy Policy](PRIVACY.md).*

### ⚙️ 8. Settings, Tab Tweaks & Backup System
- **Dashboard Tweaks**: Reorder tabs and toggle components on or off.
- **JSON Backup & Restore**: Export all notes, commands, sorting structures, time events (`SavedTimeEvents`), and AI preferences to a single JSON backup file.
- 📖 *Want to learn more? Read the complete [Settings & Backup User Manual](docs/SETTINGS_AND_BACKUP.md).*

---

## 📖 User Manuals & Technical Guides

For complete step-by-step instructions, examples, and technical specifications, explore our dedicated guides:

| Module / Topic | Description & Usage | Link |
| :--- | :--- | :--- |
| 📊 **Disk Insight** | Categorized storage scanning, external USB drive monitoring & volume ejection | [Read Manual](docs/DISK_INSIGHT.md) |
| ⚡ **Custom Commands** | Shell automation, Terminal mode vs Silent background mode & process termination | [Read Manual](docs/CUSTOM_COMMANDS.md) |
| 📝 **Quick Notes** | Viewport virtualization, read-only mode & folder drag-and-drop sorting | [Read Manual](docs/QUICK_NOTES.md) |
| 🤖 **AI Assistant** | CLI models (`opencode`/`codex`/`agy`), workspace attachments & Terminal handoff | [Read Manual](docs/AI_ASSISTANT.md) |
| 🎥 **Screen Recorder** | Configurable screen recording (resolution, mic audio, save path, window capture) | [Read Manual](docs/SCREEN_RECORDER.md) |
| ⏳ **Time Tracker** | Future countdowns, past milestones, auto-phrased readouts & 0% idle CPU ticker | [Read Manual](docs/TIME_TRACKER.md) |
| ⌨️ **Keyboard Shortcuts** | Configurable tab hotkeys (`⌘1..6`), `⌘,` Settings shortcut & local window safety | [Read Manual](docs/KEYBOARD_SHORTCUTS.md) |
| ⚙️ **Settings & Backup** | Tab reordering, component toggles & full JSON settings export/import | [Read Manual](docs/SETTINGS_AND_BACKUP.md) |
| 🏗️ **AI Architecture** | Multi-agent execution pipeline, session hash persistence & 0 MB idle RAM model | [Read Specs](AI_ARCHITECTURE.md) |
| 🔒 **Privacy Policy** | Security guarantees, window-scoped key monitoring & ATS network rules | [Read Policy](PRIVACY.md) |
| 📜 **Changelog** | Complete version history log and release notes | [Read Changelog](CHANGELOG.md) |

---

## ⚡ Quick Installation

### Option 1: Homebrew Cask (Recommended)

```bash
# 1. Tap the repository
brew tap Rian445/MacAsc https://github.com/Rian445/MacAsc.git

# 2. Trust the tap (Required for third-party taps on newer Homebrew versions)
brew trust rian445/macasc

# 3. Install the application
brew install --cask macasc
```

### Option 2: Direct DMG Download
1. Download **[Mac_ASC.dmg (v2.0.0)](https://github.com/Rian445/MacAsc/releases/download/v2.0.0/Mac_ASC.dmg)**.
2. Double-click to mount the DMG.
3. Drag **Mac ASC** into your **Applications** folder.

### Option 3: Build from Source
```bash
git clone https://github.com/Rian445/MacAsc.git
cd MacAsc
chmod +x build.sh
./build.sh
```

---

## 📁 Repository Structure

```
Mac storage Utility/
├── docs/                            # Per-module user manuals with detailed examples
│   ├── DISK_INSIGHT.md              # Disk storage & drive guide
│   ├── CUSTOM_COMMANDS.md           # Shell scripts & silent execution guide
│   ├── QUICK_NOTES.md               # Quick notes & virtualization guide
│   ├── AI_ASSISTANT.md              # CLI AI agent panel guide
│   ├── SCREEN_RECORDER.md           # Native screen recorder guide
│   ├── TIME_TRACKER.md              # Time tracker & event countdowns guide
│   ├── KEYBOARD_SHORTCUTS.md        # Tab keyboard shortcuts guide
│   └── SETTINGS_AND_BACKUP.md       # Settings & JSON backup guide
├── Sources/
│   ├── MacStorageUtilityApp.swift   # Status bar item & NSPanel window lifecycle
│   ├── StorageViewModel.swift       # State coordinator, commands, notes, timers & AI engine
│   ├── StorageManager.swift         # Async directory size scanner & disk volume reader
│   ├── DropdownView.swift           # Main SwiftUI view, tab switcher & settings UI
│   ├── ScreenRecorder.swift         # Hardware-accelerated HEVC MOV capture session
│   ├── CropSelectionWindow.swift    # Interactive crop area selection window
│   └── VisualEffectView.swift       # AppKit glassmorphism backdrop view
├── Casks/
│   └── macasc.rb                    # Homebrew Cask formula
├── AI_ARCHITECTURE.md               # Dedicated technical AI pipeline guide
├── PRIVACY.md                       # Comprehensive privacy & security specs
├── CHANGELOG.md                     # Version history log
└── build.sh                         # Build script for app bundling & DMG creation
```

---

## 📄 License

Mac ASC is open-source software released under the [MIT License](LICENSE).
