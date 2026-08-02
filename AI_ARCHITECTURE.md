# AI & Multi-Agent Integration Architecture - Mac ASC

This document explains the technical design, execution pipelines, memory management, and subprocess architecture for external **CLI Agents (`opencode`, `codex`, `antigravity`)** integrated into **Mac ASC**.

---

## 🌟 Overview & Architecture

**Mac ASC** features a unified multi-agent AI assistant system supporting:
- **System CLI AI Agents (`opencode`, OpenAI `codex`, Google `antigravity` / `agy`)**: Direct integration with local CLI tools installed on your Mac, supporting dynamic model discovery, provider model preservation, session hash tracking, and interactive Terminal handoff.

### Key Highlights
- **Universal CLI Agent Discovery**: Resolves `opencode`, `codex`, and `antigravity` (`agy`) across Apple Silicon (`/opt/homebrew`), Intel (`/usr/local`), NPM, NVM, Cargo, and Bun paths.
- **Zero Idle Memory Footprint**: Spawns processes strictly on-demand. Consumes **0 MB RAM** and **0% CPU** when idle.
- **Interactive Terminal Handoff**: Resumes active chat sessions directly inside macOS Terminal with proper workspace `cd` navigation and session hash binding.

---

## 🏗️ Unified AI Execution Pipeline

```mermaid
graph TD
    UI[SwiftUI Dropdown Chat Panel] -->|sendChatMessage| VM[StorageViewModel]
    
    VM -->|Model Selection Router| Router{Selected Model?}
    
    %% CLI Agents (opencode / codex / antigravity)
    Router -->|"opencode / codex / antigravity"| CLIRunner[StorageViewModel CLI Dispatcher]
    CLIRunner -->|makeCLIEnvironment| PATH[Universal PATH Injection]
    PATH -->|opencode run| Opencode[Process: opencode]
    PATH -->|codex exec via stdin| Codex[Process: codex]
    PATH -->|agy -p| AGY[Process: antigravity]
    
    Opencode -->|Parse stdout logs| SessionCapture[Capture Session Hash & Filter Echo]
    Codex -->|Parse stdout logs| SessionCapture
    AGY -->|Parse stdout logs| SessionCapture
    
    SessionCapture -->|Update UI & Save activeSessionId| UI
    Opencode -->|process.waitUntilExit| TerminateCLI[Process Terminates Immediately]
    Codex -->|process.waitUntilExit| TerminateCLI
    AGY -->|process.waitUntilExit| TerminateCLI
    TerminateCLI -->|0 MB Idle RAM| macOS[Memory Reclaimed by macOS]
```

---

## 🚀 Terminal Handoff & Session Persistence Sequence Diagram

When you click **"Resume Session in Terminal"**, Mac ASC generates an executable script (`.command`) that navigates to your workspace and resumes the active session hash:

```mermaid
sequenceDiagram
    autonumber
    participant User
    participant MacASC as Mac ASC (SwiftUI)
    participant VM as StorageViewModel
    participant Subprocess as Background Process
    participant Term as macOS Terminal (Terminal.app)

    User->>MacASC: Send Prompt ("Build feature in ~/Projects/MyApp")
    MacASC->>VM: sendChatMessage(prompt, attachments)
    VM->>Subprocess: Process.run("/bin/bash -c opencode run ...")
    Subprocess-->>VM: Stream Response & Output Session Hash (e.g., ses_04a9...)
    VM->>VM: Extract & Save activeSessionId in ChatThread (UserDefaults)
    VM-->>MacASC: Update UI with AI Response & Terminal Icon
    
    User->>MacASC: Click "Open in Terminal" Button
    MacASC->>VM: launchTerminalSession(for: activeThread)
    VM->>VM: Write script: cd "~/Projects/MyApp" && opencode --session ses_04a9...
    VM->>Term: NSWorkspace.open(scriptURL)
    Term-->>User: Interactive Terminal Session Resumed with Full History!
```

---

## 🔑 Session Hash Extraction & CLI Command Mapping

1. **`opencode`**:
   - **Session Hash**: `ses_[a-zA-Z0-9]+`
   - **In-App Runner**: `opencode run "<prompt>" -m <model> --auto`
   - **Terminal Resume**: `cd "<attached_path>" && opencode --session <sessionId> -m <model> --auto`
   - **Session Cleanup**: `opencode session delete <sessionId>`

2. **OpenAI `codex`**:
   - **Session Hash**: `--conversation=<uuid>`
   - **In-App Runner**: `echo "<prompt>" | codex exec -m <model> --skip-git-repo-check`
   - **Terminal Resume**: `cd "<attached_path>" && codex resume <sessionId>`

3. **Google `antigravity` (`agy`)**:
   - **Session Hash**: `--conversation=<uuid>`
   - **In-App Runner**: `agy -p "<prompt>" --model <model> --add-dir "<path>"`
   - **Terminal Resume**: `cd "<attached_path>" && agy --conversation=<sessionId> --model <model>`
