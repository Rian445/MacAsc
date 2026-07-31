# Changelog

All notable changes to **Mac ASC** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-31

### ✨ Added
- **Multi-Model CLI Agent Framework**: Complete integration with system-installed AI CLI tools (`opencode`, OpenAI `codex`, and Google `antigravity` / `agy`).
- **Dynamic Model Discovery**: Automatically parses available models directly from installed CLI agents (`opencode models`, `codex`, `antigravity`).
- **Provider Model Preservation**: Preserves full model identifiers (e.g. `opencode/deepseek-v4-flash-free`) to prevent provider API endpoint resolution errors.
- **Smart Terminal Session Launcher**: Resumes active chat threads in macOS Terminal with proper `cd` working directory navigation, session binding, and CLI-specific permission flags (`--auto`, `--dangerously-skip-permissions`).
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
