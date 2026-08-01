# Contributing to Mac ASC

Thank you for your interest in contributing to **Mac ASC**! We welcome bug reports, feature suggestions, documentation improvements, and pull requests.

---

## 🚀 How to Contribute

### 1. Reporting Bugs
- Check existing [GitHub Issues](https://github.com/Rian445/MacAsc/issues) to see if the bug has already been reported.
- If not, open a new Issue using the **Bug Report** template.
- Include your macOS version, application version (e.g. `v1.1.0`), steps to reproduce, and any relevant logs.

### 2. Suggesting Features
- Open a new Issue using the **Feature Request** template.
- Explain the user problem, the proposed solution, and why it would benefit the Mac ASC community.

### 3. Submitting Pull Requests
1. **Fork the Repository**: Create your own fork of `Rian445/MacAsc`.
2. **Clone & Create a Branch**:
   ```bash
   git clone https://github.com/your-username/MacAsc.git
   cd MacAsc
   git checkout -b feature/my-new-feature
   ```
3. **Build & Test**:
   - Ensure you have macOS 13+ and Xcode Command Line Tools installed (`xcode-select --install`).
   - Run the build verification script:
     ```bash
     chmod +x build.sh
     ./build.sh
     ```
4. **Commit & Push**: Keep your commits clean and descriptive.
5. **Open a Pull Request**: Submit your PR targeting the `main` branch of `Rian445/MacAsc`.

---

## 📜 Development Guidelines

- **Architecture**: Mac ASC follows SwiftUI + AppKit MVVM architecture. Keep views responsive and avoid blocking main-thread loops.
- **Privacy & Memory**: Maintain the 0 MB idle RAM footprint model and zero cloud telemetry guarantees.
- **Code Style**: Format Swift code according to standard Swift conventions.
