# Changelog

All notable changes to **Mac ASC** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-31

### ✨ Added
- **Dynamic Multi-Model CLI Agent Support**: Integrated `opencode`, OpenAI `codex`, and Google `antigravity` (`agy`) CLI agents alongside the embedded offline Local LLM (`Gemma 3 1B`).
- **Dynamic Model Discovery**: Automatically parses available models from CLI outputs and user configuration files (`~/.codex/config.toml`).
- **Provider Model Preservation**: Preserves full model identifiers (e.g. `opencode/deepseek-v4-flash-free`) to prevent provider API endpoint resolution errors.
- **Automatic Session Cleanup**: Automatically removes server-side sessions on `opencode` when a thread is deleted or cleared.
- **Smart Terminal Session Launcher**: Resumes active chat threads in macOS Terminal with proper `cd` working directory navigation for single and multi-path file/folder attachments.
- **Codex Stdin Execution**: Refactored Codex execution to pipe prompts via `stdin` and auto-append `--skip-git-repo-check` for non-git directory execution.

### 🧹 Refactored & Improved
- **SwiftUI View Modularization**: Extracted complex thread picker and dropdown menus into `@ViewBuilder` sub-views in `DropdownView.swift`, eliminating Swift compiler type-check bottlenecks.
- **Output Cleaner Improvements**: Refactored `cleanOpencodeOutput(_:)` with role-aware section parsing to strip echoed user prompts, CLI headers, token metadata, and duplicate response outputs.
- **Process Termination Safety**: Added process guards in `sendChatMessage(_:)` to terminate previous queries before starting new ones, preventing overlapping or orphan background tasks.
- **CLI Environment Caching**: Cached universal PATH resolution (`makeCLIEnvironment()`) with automatic invalidation on Refresh to optimize binary lookups across Homebrew, NVM, NPM, Cargo, and Bun.

### 🔒 Security & Privacy
- Verified zero network calls inside the native Swift app binary.
- Enforced default permission prompts (`--dangerously-skip-permissions` requires explicit opt-in via "Allow AI System Actions").

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
