# Mac ASC

<p align="center">
  <b>A premium, ultra-lightweight macOS menu bar utility for disk insight, custom shell automation, quick notes, and multi-agent AI workflows.</b>
</p>

<p align="center">
  <a href="https://github.com/Rian445/MacAsc/releases/download/v1.1.0/Mac_ASC.dmg"><b>📥 Download Latest Release DMG (v1.1.0)</b></a> •
  <a href="#-quick-installation"><b>⚡ Quick Installation</b></a> •
  <a href="PRIVACY.md"><b>🔒 Privacy Policy</b></a> •
  <a href="AI_ARCHITECTURE.md"><b>🏗️ AI Architecture</b></a> •
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

## ✨ Core Features & Modules

### 📊 1. Categorized Disk Storage & Drive Insight
- **Visual Storage Breakdown**: Interactive progress bars categorizing Applications, Developer Caches (`.build`), Documents, Media, and System files.
- **External Volume Scanner**: Real-time detection of USB drives, SD cards, and Thunderbolt disks with one-click safe volume ejection.
- **Pinned Folder Tracker**: Pin custom directories to monitor size changes and jump directly to Finder.

### ⚡ 2. Custom Shell Script Commands (Terminal & Silent Modes)
- **Nested Folder Subtrees**: Organize shell scripts using forward-slash folder paths (e.g. `DevOps/Docker`).
- **Visual Terminal Mode**: Opens scripts in a dedicated macOS `Terminal.app` window.
- **🔇 Silent Background Mode**: Toggle *"Run in Silent Mode"* to run scripts headlessly in the background via native Swift `Process()` with **zero Terminal popups**.
- **Live Stop Control**: Real-time running indicators (`stop.circle.fill`) and single-click Stop buttons for both Terminal and Silent background scripts.

### 📝 3. Quick Notes & Read-Only Virtualization
- **Viewport Virtualization**: Instant 0ms load times and smooth scrolling for multi-megabyte note files via native `NSTextView` virtualization.
- **Folder Organization & Drag-Sort**: Organize notes into nested subfolders with drag-and-drop reordering.

### 🤖 4. Multi-Model CLI AI Assistant
- **System CLI Compatibility**: Integrates directly with installed AI CLI tools:
  - ⚡ **`opencode`**: Execute models like `opencode/deepseek-v4-flash-free`.
  - 🤖 **OpenAI `codex`**: Stream Codex prompts via `stdin` with automatic workspace context.
  - 🌌 **Google `antigravity` (`agy`)**: Execute Antigravity models with multi-directory flag mapping.
- **Interactive Terminal Handoff**: Resume active chat threads directly in Terminal with `cd` workspace navigation.
- 💡 *Want to learn more about how our zero-idle-memory AI runner works? Read our dedicated [AI Architecture Documentation](AI_ARCHITECTURE.md).*

### ⌨️ 5. Customizable Tab Keyboard Shortcuts
- **Instant Tab Switching**: Switch between tabs (`⌘1` Disk Insight, `⌘2` Commands, `⌘3` Quick Notes, `⌘4` Chat with AI) when the Mac ASC panel is open.
- **Interactive Key Recorder**: Reassign shortcuts for any tab in Settings using a live key recorder badge.
- **Local Window Security**: Key monitoring runs strictly while the window is active, guaranteeing zero keylogging or collisions when closed.
- 💡 *Want to learn more about shortcut safety? Read our [Privacy & Security Policy](PRIVACY.md).*

### ⚙️ 6. Settings, Tab Tweaks & Backup System
- **Dashboard Tweaks**: Reorder tabs and toggle components on or off.
- **JSON Backup & Restore**: Export all notes, commands, sorting structures, and AI threads to a single JSON backup file.

---

## 🏗️ Architecture & Privacy Deep Dives

For technical specifications, security models, and subprocess pipelines, explore our dedicated guides:

| Guide | Description | Link |
| :--- | :--- | :--- |
| 🏗️ **AI Architecture** | Multi-agent execution pipeline, session hash persistence, and 0 MB idle RAM model | [Read AI Architecture](AI_ARCHITECTURE.md) |
| 🔒 **Privacy & Security** | Data safety guarantees, window-scoped key monitoring, and ATS network rules | [Read Privacy Policy](PRIVACY.md) |
| 📜 **Changelog** | Complete release history and version notes | [Read Changelog](CHANGELOG.md) |

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
1. Download **[Mac_ASC.dmg (v1.1.0)](https://github.com/Rian445/MacAsc/releases/download/v1.1.0/Mac_ASC.dmg)**.
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
├── Sources/
│   ├── MacStorageUtilityApp.swift   # Status bar item & NSPanel window lifecycle
│   ├── StorageViewModel.swift       # State coordinator, commands, notes & AI engine
│   ├── StorageManager.swift         # Async directory size scanner & disk volume reader
│   ├── DropdownView.swift           # Main SwiftUI view, tab switcher & settings UI
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
