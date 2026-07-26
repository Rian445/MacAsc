# Privacy Policy for Mac ASC

Last Updated: July 27, 2026

**Mac ASC** is built with absolute privacy as a core principle. The application operates strictly as a local utility on your device. We do not collect, store, transmit, or share any of your personal data, files, prompts, or usage statistics.

---

## 🔒 1. 100% Offline & Local Operation
All operations are executed entirely on your machine:
* **Storage Breakdown Analysis**: Directory size calculations are handled locally using native macOS system calls (`FileManager`).
* **Pinned Folders, Notes & Nested Folders**: Paths to folders you pin, quick notes you write, nested subfolder path trees (`Parent/Child`), and custom manual sort orders are saved locally in standard macOS user preferences (`UserDefaults`) and never shared.
* **Settings Backup**: When exporting settings backups, the app encodes your custom commands, quick notes, nested subfolder structures, tab sorting order (`DashboardTabOrder`), folder sort orders (`CustomCommandFolderOrder`, `QuickNoteFolderOrder`), pins, tweaks, and AI history into a local JSON file of your choosing. No third-party servers or telemetry are involved in the backup process.
* **Custom Terminal Commands**: Your shell shortcuts and window tags are stored locally on your device's preferences and executed using standard macOS command processes.

## 🤖 2. Native Offline Local AI Engine (Google Gemma 270M)
* **100% On-Device GPU Inference**: The **Chat with AI** panel uses an embedded Apple Metal GPU-accelerated GGUF neural inference engine (`Resources/bin/llama-cli` and `LocalAIEngine.swift`). All prompt processing and token generation happen 100% locally on your Mac's graphics hardware.
* **Air-Gapped Processing**: The Local AI engine contains zero networking code, zero web sockets, and zero telemetry. No prompt, text completion, or context data is ever transmitted over the internet or sent to external servers.
* **Zero Idle Memory Footprint**: The Local AI engine runs strictly on-demand. As soon as a response finishes generating, the process terminates immediately (`process.waitUntilExit()`), returning idle RAM and GPU memory usage to **0 MB**.
* **Local Session Storage**: Your chat threads, history, thread titles, folder groupings, and selected active model are saved strictly on your local disk inside macOS user preferences (`UserDefaults`).
* **File & Folder Context**: Dropping files/folders or attaching paths via the paperclip menu only captures their absolute string path. The app does **not** read or upload the contents of your files. It only appends the path string (e.g. `Context Directory: /path/to/folder`) to the local prompt query.

## 🌐 3. Zero Network Connectivity (ATS Firewall Block)
The application has zero networking capabilities:
* **System-Level Firewall Directive**: The app's configuration (`Info.plist`) includes a strict **App Transport Security (ATS)** block directive (`NSAllowsArbitraryLoads: false`). This instructs the macOS operating system to reject all outbound and inbound HTTP/HTTPS network connections.
* **No Telemetry or SDKs**: The application does not import any networking libraries, crash reporters, analytics trackers, or telemetry SDKs.

## 📊 4. Zero Analytics, Tracking, or Cookies
* We do not collect analytics, telemetry, or crash reports.
* We do not use cookies, identifiers, or tracking tokens.
* The application runs silently in your menu bar and remains completely isolated from the internet.

## ✉️ 5. Contact & Support
Since we do not collect any user data, we have no database to look up your details. If you have any questions regarding the security structure of the application, please feel free to review the open-source code directly on [GitHub](https://github.com/Rian445/MacAsc).
