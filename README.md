# Mac ASC

Mac ASC is a premium, lightweight, and offline-locked macOS menu bar utility built with SwiftUI and AppKit. It provides a real-time, categorized breakdown of your internal and external storage space, interactive application monitoring, quick folder pinning with direct Finder navigation, custom shell script commands, quick note-taking, and a local AI assistant panel.

Designed with a sleek, translucent glassmorphism interface, it blends seamlessly with the macOS environment while ensuring absolute data privacy.

### 📥 [Download Latest Release DMG](https://github.com/Rian445/MacAsc/releases/download/APP/Mac_ASC.dmg)

---

## 📸 Interface Previews

<p align="center">
  <img src="Screenshots/Screenshot%202026-06-26%20at%2012.56.03%E2%80%AFPM.png" width="360" alt="Mac ASC Tab Preview"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Screenshots/Screenshot%202026-06-26%20at%2012.56.31%E2%80%AFPM.png" width="360" alt="Custom Commands Tab Preview"/>
</p>

---

## ✨ Key Features

* **🪟 Premium Glassmorphic UI**: Uses AppKit's native backdrop-blur transparency (`NSVisualEffectView` layered with a 45% dark opacity tint) to create a stunning, wallpaper-bleeding menu bar dropdown that respects light and dark modes dynamically.
* **↔️ Tab Paging Slider**: Rebuilds the segmented header into a horizontal sliding window that displays exactly two tabs at a time. Use spring-animated chevrons (`<` and `>`) to navigate between pages:
  * **Page 0**: *Disk Insight* & *Custom Commands*
  * **Page 1**: *Quick Note* & *Chat with AI*
* **🤖 Chat with Local AI (opencode)**: A dedicated chat interface that communicates with your locally installed `opencode` command-line utility:
  * **Multiple Chat Threads**: Create, name, switch, and delete multiple independent conversation threads.
  * **Auto-Naming Threads**: New chat threads automatically rename themselves to match your first query.
  * **Context continuation**: Uses your local database session ID (scraped dynamically from log output) to continue specific conversation histories for follow-up questions.
  * **Clean Output Filtering**: Automatically filters out shell TUI progress loaders (`> build · ...`) and logs (`timestamp=...`), presenting clean text results.
  * **Interactive Bubble Controls**: Message bubbles support text selection and instant copy-to-clipboard actions with checkmark feedback.
  * **Stop AI Processing**: Cancel running queries mid-way, immediately terminating the background subprocess and releasing ports.
  * **Dot Typing Indicator**: Features a pulsed three-dot typing loading view during background AI execution.
* **📊 Categorized Storage Breakdown**: Visualizes your storage allocations using multi-colored stacked progress bars. Breaks down space into:
  * 🔵 **Applications**
  * 🟣 **Developer Files** (build directories, caches)
  * 🟠 **Documents**
  * 🟢 **Media Files** (audio, video, photos)
  * ⚪ **System / Other**
* **🔌 Multi-Drive Support**: Automatically detects and monitors external USB drives, SD cards, and thunderbolt disks. Scan categorized breakdowns and safely eject external volumes directly from the dropdown.
* **📌 Folder Pinning & Size Tracker**: Select and pin custom directories to the dashboard. The application calculates directory sizes asynchronously in the background and provides single-click Finder access.
* **📱 Interactive App List**: Automatically lists your top installed applications by size. Click "Other Apps" to expand and view the full list, or tap on any application to instantly locate it in Finder.
* **🧹 Mole Cleaner Integration**: Automatically detects if the interactive CLI cleaning utility `mo` is installed. Allows launching it directly inside a new Terminal window with a single click, or guides you to the download page.
* **⌨️ Custom Terminal Commands**: A dedicated tab for developers and power users to configure shell script shortcuts:
  * Group saved commands visually into collapsible, structured **Folder Categories**.
  * Add commands using a **collapsible creation form** with an optional folder category input.
  * **Window Tag / Grouping**: Assign an optional window tag to commands. Commands sharing the same tag will execute in the **same** Terminal window/tab sequentially instead of spawning new Terminal windows.
  * **Edit saved commands** inline using a pen edit button (fills input fields with pre-filled details, Cancel/Save action layout).
  * Execute saved shell commands in a new Terminal window with a single click.
  * **Stop commands**: Safely terminate active commands individually (orange stop button displays only on actively executing rows) or run a global **Stop All** process interruption routine (sending Ctrl+C process group signals).
  * **Safety Deletion Confirmation**: Displays a secure confirmation dialog when deleting saved commands to prevent accidental loss.
* **📝 Quick Notes**: A dedicated tab to save and copy text snippets, commands, or reminders:
  * Add notes using a **collapsible creation form** with animated transitions.
  * **Edit saved notes** inline to quickly correct or update text.
  * **Copy notes instantly** with a dedicated copy button next to each note (features checkmark visual feedback).
  * **Persistent Storage**: Saves your notes locally in macOS user preferences (`UserDefaults`) so they are available across launches.
* **💾 Local Storage Cache**: Caches scanned storage categories locally. On launch, it loads previous statistics instantly, ensuring a fast load time without display lag.
* **🔒 100% Offline & Secure**: Operates strictly offline. Has zero dependencies on network frameworks and is locked down via App Transport Security (ATS) to ensure your storage details never leave your device.

---

## 🛠️ Technology Stack

* **Platform**: macOS 13.0+
* **Language**: Swift 5.9+ (Swift 6 async-concurrency compliant)
* **Frameworks**: SwiftUI & AppKit (MVVM Architecture)
* **Subprocesses**: Native background process wrapper (`Process` & `Pipe`) executing local binaries (`opencode`, `mo`, `osascript`).
* **Packaging**: Built into a standalone `.app` bundle and distributed via a compressed `.dmg` installer.

---

## 🚀 Building & Running

A shell script `build.sh` is included to compile the Swift source files, generate app metadata, structure the bundle, and package the installer.

### Prerequisite
* macOS 13+ with Xcode Command Line Tools installed (run `xcode-select --install` if you don't have it).
* To use the AI Chat panel, install the `opencode` CLI utility (see instructions below).

### Installation

#### Option 1: Direct Download (Recommended)
1. Download the pre-compiled **[Mac_ASC.dmg](https://github.com/Rian445/MacAsc/releases/download/APP/Mac_ASC.dmg)**.
2. Double-click the downloaded `.dmg` file to mount it.
3. Drag **Mac ASC** into your **Applications** folder.

#### Option 2: Homebrew Cask (Tap)
You can tap this repository and install the application directly via Homebrew:
```bash
# Tap the repository directly
brew tap Rian445/MacAsc https://github.com/Rian445/MacAsc.git

# Install the application
brew install --cask macasc
```

> [!TIP]
> **Quarantine Bypass**: Installing via Homebrew Cask automatically runs a postflight script to clear the `com.apple.quarantine` attribute, allowing the app to launch instantly without macOS Gatekeeper verification warnings.

> [!NOTE]
> **Untrusted Tap Warning**: On recent versions of Homebrew, you may receive a warning: `Refusing to load cask rian445/macasc/macasc from untrusted tap`. If this occurs, simply run `brew trust rian445/macasc` to mark the tap as trusted, then run the install command again.

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
   *This compiles the binary, structures the `Mac ASC.app` bundle, generates standard macOS icon sets, and compiles everything into a DMG installer named `Mac ASC.dmg`.*
3. **Install the Application**:
   * Open the generated `Mac ASC.dmg` in Finder.
   * Drag **Mac ASC** into your **Applications** folder.

4. **Launch**:
   * Start **Mac ASC** from your Applications folder or Launchpad.
   * The disk status icon (`externaldrive` glyph) will immediately appear in your macOS menu bar.

---

## 📁 File Structure

* `Sources/`
  * `MacStorageUtilityApp.swift` — App entry point deploying the Status Bar Item and centered `NSPanel` controller.
  * `StorageViewModel.swift` — Coordinates application state, mounts/unmounts, custom terminal commands, AI chat threads, and directory size indexing.
  * `StorageManager.swift` — Scans application sizes, traverses folder hierarchies asynchronously, and measures disk volumes.
  * `DropdownView.swift` — The core user interface, sliding tab switcher, custom commands pane, quick notes, and local AI chat panel overlays.
  * `VisualEffectView.swift` — Bridges SwiftUI to AppKit for custom glassmorphism.
* `app_icon.png` — High-resolution source icon.
* `build.sh` — Compilation script compiling code and packing the DMG.

---

## 📄 License & Privacy

* **Privacy Policy**: This application operates strictly offline and collects no data. See the [Privacy Policy](PRIVACY.md) for more details.
* **License**: This project is open-source and available under the [MIT License](LICENSE).
