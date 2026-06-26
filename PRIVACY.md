# Privacy Policy for Mac ASC

Last Updated: June 26, 2026

**Mac ASC** is built with absolute privacy as a core principle. The application operates strictly as a local utility on your device. We do not collect, store, transmit, or share any of your personal data, files, or usage statistics.

---

## 🔒 1. 100% Offline & Local Operation
All operations are executed entirely on your machine:
* **Storage Breakdown Analysis**: The directory size calculation is handled locally using native macOS system calls (`FileManager`).
* **Pinned Folders**: Paths to folders you pin are saved locally in the standard macOS user preferences (`UserDefaults`) and never shared.
* **Custom Terminal Commands**: Your shell shortcuts are stored locally on your device's keychain/preferences and executed using the native macOS `Terminal.app`.

## 🌐 2. Zero Network Connectivity (ATS Block)
The application has zero networking capabilities:
* **System-Level Block**: The app's configuration (`Info.plist`) includes a strict **App Transport Security (ATS)** block directive (`NSAllowsArbitraryLoads: false`). This instructs macOS to reject all outbound and inbound HTTP/HTTPS network connections.
* **No Dependencies**: The application does not import any networking libraries or use external SDKs (such as databases, analytics trackers, or telemetry tools).

## 📊 3. Zero Analytics, Tracking, or Cookies
* We do not collect analytics, telemetry, or crash reports.
* We do not use cookies, identifiers, or tracking tokens.
* The application runs silently in your menu bar and remains completely isolated from the internet.

## 🤝 4. Third-Party Websites & Utilities
* **Mole Cleaner (`mo`) Integration**: If you choose to launch the cleaning utility `mo`, it is launched inside your local system shell. If it is missing, clicking the download option opens the official GitHub URL in your default system web browser. This web navigation is handled entirely by your default web browser, subject to your browser's own privacy policy.

## ✉️ 5. Contact & Support
Since we do not collect any user data, we have no database to look up your details. If you have any questions regarding the security structure of the application, please feel free to review the open-source code directly on [GitHub](https://github.com/Rian445/MacAsc).
