# Changelog

All notable changes to **Mac ASC** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - 2026-08-22

### ✨ Added
- **Time Tracker & Event Countdowns Module (Tab 5)**: Complete event countdown & count-up tracking tab with title, date & time picker, and full CRUD operations.
- **Dynamic Auto-Phrased Timer Readouts**:
  - Future targets: Displays `[Event Title] coming in X days Y hrs Z mins S secs` with a cyan `COMING IN` badge.
  - Past targets: Displays `[Event Title] passed for X yrs Y days Z mins S secs` with an orange `PASSED FOR` badge.
- **Seamless Future ➔ Past Transition**: Automatically transitions from `coming in` to `passed for` and counts up without stopping or freezing when target dates pass.
- **0% Idle CPU & RAM Guarantee**: Live UI ticker runs strictly while the window is open and Tab 5 is selected. Instantly invalidated on window close or tab switch.
- **Native Screen Recorder & H.265 .mov Compression**: Captures video in hardware-accelerated HEVC (H.265) saved directly into standard QuickTime `.mov` files for instant WhatsApp, Slack, and web sharing compatibility.
- **Custom Active Menu Bar Animations**: Choose between **Phoenix**, **Record**, and **Fire** animated menu bar icons with native template white and color modes.
- **Fixed Standard macOS Settings Shortcut (`⌘,`)**: Pressing `Command + Comma` (`⌘,`) anywhere in the app toggles the Settings panel. Pressing any tab shortcut (`⌘1..6`) while in Settings automatically dismisses Settings and navigates to the requested tab.
- **Dedicated Time Tracker Shortcut (`⌘6`)**: Added `⌘6` default keyboard shortcut mapping for Tab 5, fully integrated into the Settings key binder.
- **Full Settings Backup Integration**: Includes `SavedTimeEvents`, `TweakTimeTracker`, and `TabKeyboardShortcuts` in JSON export and import.

### 🧹 Refactored & Improved
- **Window-Bound Timer Management**: Wrapped popover transitions to instantly kill command scanning timers on window resignation, guaranteeing 0% background idle CPU usage.
- **Redundant Stop Item Cleanup**: Removed secondary menu bar stop button, unifying status indication directly into the main status bar animated icon.

---

## [1.1.0] - 2026-07-31

### ✨ Added
- **Multi-Model CLI Agent Framework**: Complete integration with system-installed AI CLI tools (`opencode`, OpenAI `codex`, and Google `antigravity` / `agy`).
- **Dynamic Model Discovery**: Automatically parses available models directly from installed CLI agents (`opencode models`, `codex`, `antigravity`).
- **Provider Model Preservation**: Preserves full model identifiers (e.g. `opencode/deepseek-v4-flash-free`) to prevent provider API endpoint resolution errors.
- **Smart Terminal Session Launcher**: Resumes active chat threads in macOS Terminal with proper `cd` working directory navigation, session binding, and CLI-specific permission flags (`--auto`, `--dangerously-skip-permissions`).
- **Silent Background Execution Mode for Custom Commands**: Added *"Run in Silent Mode (Background execution)"* toggle option to custom commands, executing shell scripts headlessly in the background via native Swift `Process()` wrappers without opening Terminal.app, complete with purple `[🔇 Silent]` badges and real-time process cancellation control.
- **Customizable Tab Keyboard Shortcuts**: Added configurable window-scoped keyboard shortcuts (`⌘1` for Disk Insight, `⌘2` for Commands, `⌘3` for Notes, `⌘4` for AI Chat) active only when Mac ASC is open, with an interactive key recorder in Settings and zero background CPU/RAM overhead when closed.
- **Read-Only Viewing Mode & Note Virtualization**: Added read-only mode for Quick Notes utilizing native `NSTextView` viewport virtualization (`ReadOnlyNoteTextView`), achieving instant 0ms load times and smooth trackpad scrolling for multi-megabyte note files without main-thread UI beachballs.
- **Icon-Only Single-Row Top Toolbar**: Streamlined Note View top bar into a single compact row featuring icon-only Back (`chevron.left`), Edit (`pencil`), Copy, and Delete buttons alongside a horizontally scrollable note title and fixed folder badge.

### 🧹 Refactored & Improved
- **Complete Local LLM Removal**: Removed embedded Gemma 3 1B GGUF model weights and `llama-cli` runtime, reducing application bundle size from **1.0 GB down to 9.0 MB** (DMG installer **5.2 MB**).
- **Clean Build Script**: Added automatic build directory cleaning (`rm -rf Mac ASC.app`) in `build.sh` to ensure zero stale or orphaned assets persist across compiles.
- **Terminal Handoff Repair**: Fixed `EPERM: operation not permitted` macOS privacy errors when opening CLI threads in Terminal by utilizing home directory (`~`) navigation and accurate flags (`--auto` for `opencode`).
- **Automatic Session Cleanup**: Automatically issues session deletion requests (`opencode session delete <sessionID>`) when clearing or deleting chat threads.
- **Process Termination Safety**: Enforced process guards in `sendChatMessage(_:)` to terminate existing queries before launching new ones, preventing background subprocess leakage.

### 🔒 Security & Privacy
- Verified zero network calls inside the native Swift app binary.
- Enforced safe permission defaults (auto-approval flags require explicit opt-in via "Allow AI System Actions").

---

## [1.0.0] - 2026-07-28

### ✨ Added
- Initial release of Mac ASC (Mac Storage Utility & System Control).
- Categorized storage breakdown (Applications, Developer, Documents, Media, System/Other).
- External disk detection, space monitoring, and safe volume ejection.
- Native offline Local LLM (Google Gemma 3 1B GGUF via Metal GPU acceleration).
- Custom Terminal command shortcuts with folder hierarchy and manual sort modes.
- Quick Notes manager with tree nesting, search, and JSON export/import backup system.
- Visual effect glassmorphism UI with AppKit `NSVisualEffectView` integration.
