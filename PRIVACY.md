# Privacy Policy for Mac ASC

Last Updated: July 31, 2026

**Mac ASC** is designed with privacy and data security as core principles. The application operates as a native, lightweight macOS utility. We do not collect, store, transmit, or share any of your personal data, files, prompts, or usage analytics.

---

## 🔒 1. 100% Private Native Application
The Mac ASC native application binary (`Mac ASC.app`) contains zero telemetry, zero tracking code, zero analytics SDKs, and zero crash reporting libraries:
* **Storage Breakdown Analysis**: Directory size calculations are handled strictly on your local machine using native macOS system calls (`FileManager`).
* **Pinned Folders, Notes & Nested Folders**: Pinned directory paths, quick notes, nested subfolder trees, custom command shortcuts, and tab sorting preferences are saved locally in standard macOS user preferences (`UserDefaults`) on your own Mac.
* **Settings Backup**: Exported JSON backup files encode your settings, custom commands, quick notes, pinned paths, and chat threads directly to a local JSON file of your choosing. No third-party servers or cloud backup endpoints are involved.

---

## ⚡ 2. Custom Shell Commands & Background Process Isolation
* **Local Execution Only**: Custom commands run strictly on your local Mac.
* **Terminal Mode vs Silent Background Mode**: Commands configured for standard execution open in macOS Terminal (`Terminal.app`), while commands set to *Run in Silent Mode* execute headlessly via native Swift background process wrappers (`Process()`).
* **Process Isolation & Safety**: Background commands run under your own local user permissions (`/bin/bash`). Mac ASC includes process boundary safety checks (`pid != myPid`) so process termination logic (`stopCustomCommand`) can only target processes explicitly spawned by your custom scripts.

---

## ⌨️ 3. Window-Scoped Keyboard Shortcuts & Privacy
* **Local Window Scope Only**: Tab keyboard shortcuts (`⌘1..4` or custom reassignments) use native AppKit local monitors (`NSEvent.addLocalMonitorForEvents`). Key presses are intercepted **strictly when the Mac ASC window is active and open**.
* **Zero Global Keylogging**: The application cannot observe, capture, or log keystrokes typed in other applications, browsers, or password fields when Mac ASC is closed or unfocused.
* **No Accessibility Permissions Needed**: Because event monitoring is strictly scoped to Mac ASC's own window, no system-level macOS Accessibility or Keylogger permissions are requested or required.

---

## 🤖 4. External CLI AI Agents (`opencode`, `codex`, `antigravity`)
Mac ASC supports integration with command-line agents (`opencode`, OpenAI `codex`, Google `antigravity` / `agy`) that you have installed on your Mac:
* **Zero Credential / API Key Input Requirement**: Mac ASC **never** prompts for or collects API keys, passwords, or login credentials inside the application. Authentication is handled 100% directly inside your terminal environment by logging into the respective CLI tool (`opencode auth login`, `codex auth login`, `agy auth login`).
* **User-Initiated Execution**: CLI agents are only executed when you explicitly select a CLI model from the chat dropdown and send a prompt.
* **Local CLI Execution**: Mac ASC executes your locally installed CLI binaries (`/opt/homebrew/bin/opencode`, `codex`, `agy`) using standard background subprocess wrappers (`Process()`). The CLI tools use your existing local authentication tokens configured in your terminal environment.
* **Server-Side Sessions**: Chat session IDs (`ses_...` or `--conversation`) are maintained by the respective CLI provider to preserve conversation context.
* **Automatic Session Cleanup**: When you delete or clear a chat thread in Mac ASC, the application automatically issues a session removal request (`opencode session delete <sessionID>`) to clean up local and remote session references.

---

## 🛡️ 3. AI System Action Permission Controls
* **Safe Defaults**: Permission auto-approval flags (`--dangerously-skip-permissions` / `--dangerously-bypass-approvals-and-sandbox`) are **disabled by default**.
* **Explicit Opt-In**: System action flags are only passed to CLI runners if you explicitly turn on the *"Allow AI System Actions"* toggle in Settings.

---

## 🌐 4. System-Level ATS Security & Firewall
* **App Transport Security (ATS)**: The application bundle configuration (`Info.plist`) includes a strict App Transport Security directive (`NSAllowsArbitraryLoads: false`), instructing the macOS system runtime to block unauthorized network connections from the native app binary.

---

## ✉️ 5. Contact & Support
Because we do not collect any user data or maintain user databases, we have no tracking logs to look up. If you have questions regarding the security or privacy architecture of Mac ASC, you can review the open-source codebase directly on [GitHub](https://github.com/Rian445/MacAsc).
