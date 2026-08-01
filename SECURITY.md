# Security Policy for Mac ASC

## 🔒 Supported Versions

We provide security updates and patches for the latest release of Mac ASC:

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| < 1.1.0 | :x:                |

---

## 🛡️ Security Architecture

Mac ASC is designed with security and data privacy as core principles:

1. **Air-Gapped Local Binary**: The native Swift binary contains zero analytics, zero crash reporting, and zero network telemetry.
2. **App Transport Security (ATS)**: Enforces `NSAllowsArbitraryLoads: false` in `Info.plist` to prevent unauthorized background network calls.
3. **Local Window Event Scope**: Tab keyboard shortcuts (`NSEvent.addLocalMonitorForEvents`) run strictly while the application window is active and open, avoiding global keylogging.
4. **Subprocess Boundary Guards**: Command termination logic (`stopCustomCommand`) includes safety PID guards (`pid != myPid`) to prevent interfering with system processes.

---

## ✉️ Reporting a Vulnerability

If you discover a security vulnerability or privacy concern in Mac ASC, please report it privately:

- **Private Email / GitHub Disclosure**: Contact the project maintainer via [GitHub](https://github.com/Rian445/MacAsc).
- Please **do not** open public GitHub issues for undisclosed security vulnerabilities.
- We will acknowledge your report within 48 hours and release a patch as soon as possible.
