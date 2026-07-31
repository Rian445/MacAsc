# Mac ASC

Mac ASC is a premium, lightweight, and privacy-focused macOS menu bar utility built with SwiftUI and AppKit. It provides a real-time, categorized breakdown of your internal and external storage space, interactive application monitoring, quick folder pinning with direct Finder navigation, custom shell script shortcuts, quick note-taking, and a native multi-agent AI assistant panel supporting **Local Offline LLMs (Gemma 3 1B)** as well as **CLI Agents (`opencode`, OpenAI `codex`, Google `antigravity` / `agy`)**.

Designed with a sleek, translucent glassmorphism interface, it blends seamlessly with the macOS environment while ensuring total data privacy and zero background RAM leakage.

### 📥 [Download Latest Release DMG](https://github.com/Rian445/MacAsc/releases/download/APP/Mac_ASC.dmg)

---

## 📸 Interface Previews

<p align="center">
  <img src="Screenshots/macasc.png" width="480" alt="Mac ASC Interface Preview"/>
</p>

---

## ✨ Key Features

* **🪟 Premium Glassmorphic UI**: Uses AppKit's native backdrop-blur transparency (`NSVisualEffectView` layered with a 45% dark opacity tint) to create a wallpaper-bleeding menu bar dropdown that respects light and dark modes dynamically.
* **🤖 Multi-Model AI Assistant Panel**:
  * **100% Offline Local LLM (Google Gemma 3 1B Instruct)**: Embedded Apple Metal GPU-accelerated GGUF neural inference engine (`gemma-1b.gguf`) running 100% locally on your Mac's GPU with zero internet connection or python/CLI dependencies.
  * **Multi-CLI Agent Support (`opencode`, `codex`, `antigravity`)**: Seamlessly chat with installed CLI agents directly inside the app. Dynamically parses models from your system binaries and `~/.codex/config.toml`.
  * **Provider Model Preservation**: Preserves full provider model identifiers (e.g. `opencode/deepseek-v4-flash-free`) to ensure zero API endpoint errors.
  * **Interactive Terminal Launcher**: Launch active chat sessions directly into macOS Terminal (`cd "<attached_path>"`) with single and multi-path file/folder attachment support.
  * **Automatic Server Session Cleanup**: Deletes server-side sessions on `opencode` automatically when a thread is deleted or cleared.
  * **Zero Idle Memory Footprint**: Spawns processes strictly on-demand and terminates immediately upon response completion (`0 MB RAM` when idle).
  * **File & Folder Context Attachment**: Drag and drop any file or folder anywhere onto the chat window, or click the **Paperclip** icon to attach local path context for the AI.
  * **Markdown & Code Snippets**: Render multi-line markdown formatting, bullet points, headers, and syntax blocks.
* **📁 Nested Subfolders & Tree Hierarchy**: Supports unlimited nested folder trees using forward-slash path strings (e.g. `DevOps/Docker` or `Work/Projects/Scripts`) across Custom Commands and Quick Notes. Subfolders render with visual tree indentation, recursive collapse/expand, and item count badges.
* **🔃 Interactive Sort Mode & Drag-and-Drop Nesting**: Click the **Sort** button at the top of Saved Commands or Saved Notes to activate manual sorting mode:
  * **Up / Down Arrow Controls**: Manually reorder folders, subfolders, and individual items up and down.
  * **Drag-and-Drop Folder Nesting**: Drag any folder and drop it onto another folder to nest it inside (`Target Folder / Dragged Folder`).
  * **Move Out / Un-nest (`[↰]`)**: Click the Move Out button on any nested subfolder to un-nest it out of its parent folder.
* **↔️ Expand / Collapse All**: Easily expand or collapse all folder structures across all nesting levels in a single click.
* **🗑️ Safe Folder Deletion**: Delete folders directly using the minus button with a safety confirmation dialog giving you the choice to **Uncategorize Items** (keep commands/notes) or **Delete Folder & All Contents**.
* **📊 Categorized Storage Breakdown**: Visualizes your storage allocations using multi-colored stacked progress bars:
  * 🔵 **Applications**
  * 🟣 **Developer Files** (build directories, caches)
  * 🟠 **Documents**
  * 🟢 **Media Files** (audio, video, photos)
  * ⚪ **System / Other**
* **🔌 Multi-Drive Support**: Automatically detects and monitors external USB drives, SD cards, and Thunderbolt disks. Scan categorized breakdowns and safely eject external volumes directly from the dropdown.
* **📌 Folder Pinning & Size Tracker**: Select and pin custom directories to the dashboard. The application calculates directory sizes asynchronously in the background and provides single-click Finder access.
* **📱 Interactive App List**: Automatically lists your top installed applications by size. Click "Other Apps" to expand and view the full list, or tap on any application to instantly locate it in Finder.
* **⚙️ Main Window Settings & Tab Reordering**: A Settings icon button in the header opens preferences directly in the main window:
  * **About Page**: Lists developer details, ATS security specifications, and exact disk usage/preference sizes for the application.
  * **Dashboard Tweaks & Tab Reordering**: Toggle switches to show or hide dashboard components (*Disk Insight*, *Custom Commands*, *Quick Note*, *Chat with AI*) and manually reorder dashboard tabs using Up/Down controls.
  * **Comprehensive Backup & Restore**: Export all custom commands, quick notes, nested subfolder structures, tab sorting order, folder sort orders, pinned folders, tweaks, and AI chat sessions into a JSON backup file, or upload/import a backup file to restore your configuration instantly.
* **💾 Local Storage Cache**: Caches scanned storage categories locally for instant load times on launch.
* **🔒 100% Safe & Private**: Contains zero analytics, zero telemetry, and zero tracking code.

---

## 🛠️ Technology Stack

* **Platform**: macOS 13.0+
* **Language**: Swift 5.9+ (Swift 6 async-concurrency compliant)
* **Frameworks**: SwiftUI & AppKit (MVVM Architecture)
* **Subprocesses**: Native background process wrapper (`Process` & `Pipe`) executing bundled local binaries (`llama-cli`) and system CLI agents (`opencode`, `codex`, `agy`).
* **AI Engine**: Embedded Apple Metal GPU GGUF inference engine (`libggml-metal.dylib`) with Google Gemma 3 1B Instruct weights (`gemma-1b.gguf`), plus CLI agent integration.
* **Packaging**: Built into a standalone `.app` bundle and distributed via a compressed `.dmg` installer.

---

## 🚀 Building & Running

A shell script `build.sh` is included to compile the Swift source files, generate app metadata, structure the bundle, and package the installer.

### Prerequisite
* macOS 13+ with Xcode Command Line Tools installed (run `xcode-select --install` if you don't have it).

### Installation

#### Option 1: Direct Download (Recommended)
1. Download the pre-compiled **[Mac_ASC.dmg](https://github.com/Rian445/MacAsc/releases/download/APP/Mac_ASC.dmg)**.
2. Double-click the downloaded `.dmg` file to mount it.
3. Drag **Mac ASC** into your **Applications** folder.

#### Option 2: Homebrew Cask (Tap)
You can tap this repository and install the application directly via Homebrew.

```bash
# 1. Tap the repository directly
brew tap Rian445/MacAsc https://github.com/Rian445/MacAsc.git

# 2. Trust the tap (Required for third-party user taps on newer Homebrew versions)
brew trust rian445/macasc

# 3. Install the application
brew install --cask macasc
```

#### Option 3: Build from Source
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Rian445/MacAsc.git
   cd MacAsc
   ```
2. **Build and Package**:
   Run the build script in the root directory:
   ```bash
   ./build.sh
   ```
   *This script automatically checks for model weights, compiles the binary, structures the `Mac ASC.app` bundle, generates standard macOS icon sets, and compiles everything into a DMG installer named `Mac_ASC.dmg`.*

---

## 📁 File Structure

* `Sources/`
  * `MacStorageUtilityApp.swift` — App entry point deploying the Status Bar Item and centered `NSPanel` controller.
  * `StorageViewModel.swift` — Coordinates application state, custom commands, quick notes, AI chat threads, CLI discovery, and directory size indexing.
  * `StorageManager.swift` — Scans application sizes, traverses folder hierarchies asynchronously, and measures disk volumes.
  * `LocalAIEngine.swift` — Swift manager executing native offline GGUF inference via Apple Metal GPU acceleration.
  * `DropdownView.swift` — Core user interface, modular `@ViewBuilder` chat controls, sliding tab switcher, custom commands pane, quick notes, and local AI chat panel overlays.
  * `VisualEffectView.swift` — Bridges SwiftUI to AppKit for custom glassmorphism.
* `Resources/`
  * `bin/` — Bundled C++/Metal GPU inference binary (`llama-cli`) and backend dynamic libraries (`libggml-metal.dylib`, `libllama.dylib`).
  * `models/` — Bundled Gemma 3 1B Instruct GGUF model weights (`gemma-1b.gguf`).
* `app_icon.png` — High-resolution source icon.
* `build.sh` — Compilation script compiling code and packing the DMG.

---

## 📄 License, Changelog & Privacy

* **Changelog**: Read [CHANGELOG.md](CHANGELOG.md) for version release notes.
* **Privacy Policy**: Read [PRIVACY.md](PRIVACY.md) for full data privacy details.
* **Architecture Docs**: Read [LOCAL_LLM_ARCHITECTURE.md](LOCAL_LLM_ARCHITECTURE.md) for technical inference details.
* **License**: Open-source under the [MIT License](LICENSE).
