# Privacy Policy for Mac ASC

Last Updated: July 2, 2026

**Mac ASC** is built with absolute privacy as a core principle. The application operates strictly as a local utility on your device. We do not collect, store, transmit, or share any of your personal data, files, or usage statistics.

---

## 🔒 1. 100% Offline & Local Operation
All operations are executed entirely on your machine:
* **Storage Breakdown Analysis**: The directory size calculation is handled locally using native macOS system calls (`FileManager`).
* **Pinned Folders & Notes**: Paths to folders you pin and quick notes you write are saved locally in the standard macOS user preferences (`UserDefaults`) and never shared.
* **Custom Terminal Commands**: Your shell shortcuts are stored locally on your device's preferences and executed using standard macOS command processes.

## 🤖 2. Local AI Chat Integration (opencode)
* **Subprocess Execution**: The **Chat with AI** panel communicates with the locally installed `opencode` command-line tool. It spawns `opencode` as a background subprocess using your standard user account privileges.
* **Local Session Storage**: Your chat threads, history, and generated responses are saved strictly on your local disk inside macOS user preferences (`UserDefaults`) under the key `AIChatThreads`. 
* **Data Transmission**: Mac ASC itself does **not** have internet access and does **not** transmit or upload your prompts. Any networking required to generate AI responses (e.g. sending queries to DeepSeek or OpenAI) is handled entirely by your own locally installed and configured `opencode` utility, using your personal credentials stored on your Mac.

## 🌐 3. Zero Network Connectivity (ATS Block)
The application has zero networking capabilities:
* **System-Level Block**: The app's configuration (`Info.plist`) includes a strict **App Transport Security (ATS)** block directive (`NSAllowsArbitraryLoads: false`). This instructs macOS to reject all outbound and inbound HTTP/HTTPS network connections.
* **No Dependencies**: The application does not import any networking libraries or use external SDKs (such as databases, analytics trackers, or telemetry tools).

## 📊 4. Zero Analytics, Tracking, or Cookies
* We do not collect analytics, telemetry, or crash reports.
* We do not use cookies, identifiers, or tracking tokens.
* The application runs silently in your menu bar and remains completely isolated from the internet.

## 🤝 5. Third-Party Websites & Utilities
* **opencode / mole Integration**: If you choose to run `opencode` or `mo`, they are launched inside your local system shell. If they are missing, links are provided to install them via Homebrew. Any download or web page navigation is handled entirely by your system web browser, subject to your browser's own privacy policy.

## ✉️ 6. Contact & Support
Since we do not collect any user data, we have no database to look up your details. If you have any questions regarding the security structure of the application, please feel free to review the open-source code directly on [GitHub](https://github.com/Rian445/MacAsc).
