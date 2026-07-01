import SwiftUI
import Combine
import AppKit

@MainActor
class StorageViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var internalDrive: DriveInfo?
    @Published var externalDrives: [DriveInfo] = []
    @Published var appItems: [AppItem] = []
    @Published var storageBreakdown = StorageBreakdown()
    @Published var driveBreakdowns: [String: StorageBreakdown] = [:]
    @Published var pinnedFolders: [PinnedFolder] = []
    @Published var isScanning = false
    @Published var lastScanTime: Date?
    @Published var isMoleInstalled = false
    @Published var customCommands: [TerminalCommand] = []
    @Published var runningCommandIds: Set<UUID> = []
    @Published var quickNotes: [QuickNote] = []
    @Published var appBundleSize: Int64 = 0
    @Published var appSettingsSize: Int64 = 0
    @Published var appCommandsSize: Int64 = 0
    @Published var appNotesSize: Int64 = 0
    @Published var appGeneralSettingsSize: Int64 = 0
    @Published var chatThreads: [ChatThread] = []
    @Published var selectedThreadId: UUID? = nil
    @Published var isAiResponding = false
    @Published var isOpencodeInstalled = false
    private var activeAiProcess: Process? = nil
    
    var selectedThread: ChatThread? {
        chatThreads.first(where: { $0.id == selectedThreadId })
    }
    
    
    // MARK: - Dependencies & Listeners
    private let storageManager = StorageManager()
    private var cancellables = Set<AnyCancellable>()
    private var runningCommandsTimer: AnyCancellable? = nil
    
    init() {
        // Listen to macOS notifications for physical volume changes
        setupVolumeMonitor()
        // Load custom pinned folders
        loadPinnedFolders()
        // Load custom terminal commands
        loadCustomCommands()
        // Load quick notes
        loadQuickNotes()
        // Load cached storage breakdown
        loadStorageBreakdown()
        // Check for mo/mole installation
        checkMoleInstallation()
        // Load AI chat history
        loadChatHistory()
        // Check for opencode installation
        checkOpencodeInstallation()
        // Run initial scans
        refresh()
    }
    
    // MARK: - Intent Methods
    
    /// Triggers a full storage and file scan asynchronously
    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        
        // Check for mo/mole installation
        checkMoleInstallation()
        // Check for opencode installation
        checkOpencodeInstallation()
        
        // Scan pinned folder sizes in background
        scanPinnedFolderSizes()
        
        Task {
            // 1. Instantly get drive info
            let drives = storageManager.fetchDrives()
            self.internalDrive = drives.first(where: { $0.isInternal })
            self.externalDrives = drives.filter { !$0.isInternal }
            
            // 2. Perform background scans for apps and files concurrently
            async let apps = storageManager.scanApplications()
            async let breakdown = storageManager.scanFilesAndCategories()
            
            let scannedApps = await apps
            var scannedBreakdown = await breakdown
            
            // Set the appsSize for the internal drive
            scannedBreakdown.appsSize = scannedApps.reduce(0) { $0 + $1.size }
            
            // 3. Scan external drives breakdown concurrently
            var extBreakdowns: [String: StorageBreakdown] = [:]
            for drive in self.externalDrives {
                let driveURL = URL(fileURLWithPath: drive.path)
                let extBreakdown = await storageManager.scanDriveBreakdown(at: driveURL)
                extBreakdowns[drive.path] = extBreakdown
            }
            
            // 4. Update state on MainActor
            self.appItems = scannedApps
            self.storageBreakdown = scannedBreakdown
            self.saveStorageBreakdown()
            self.driveBreakdowns = extBreakdowns
            self.isScanning = false
            self.lastScanTime = Date()
        }
    }
    
    /// Unmounts and ejects an external drive safely
    func eject(drive: DriveInfo) {
        guard !drive.isInternal else { return }
        let url = URL(fileURLWithPath: drive.path)
        
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            NSLog("Volume successfully ejected: \(drive.name)")
            self.refreshDrivesOnly()
        } catch {
            NSLog("Failed to eject volume: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupVolumeMonitor() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        
        Publishers.Merge3(
            workspaceCenter.publisher(for: NSWorkspace.didMountNotification),
            workspaceCenter.publisher(for: NSWorkspace.didUnmountNotification),
            workspaceCenter.publisher(for: NSWorkspace.didRenameVolumeNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.refreshDrivesOnly()
        }
        .store(in: &cancellables)
    }
    
    private func refreshDrivesOnly() {
        let drives = storageManager.fetchDrives()
        self.internalDrive = drives.first(where: { $0.isInternal })
        self.externalDrives = drives.filter { !$0.isInternal }
    }
    
    // MARK: - Pinned Folders Management
    
    /// Launches an NSOpenPanel directory picker to select and pin a directory.
    func addPinnedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.message = "Choose a folder to pin for quick storage analysis"
        
        // Force the app to become active so the file picker gets focus immediately
        NSApp.activate(ignoringOtherApps: true)
        // Elevate window level so it floats above other windows
        panel.level = .floating
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                let path = url.path
                // Prevent duplicate paths
                if !pinnedFolders.contains(where: { $0.path == path }) {
                    let folder = PinnedFolder(name: url.lastPathComponent, path: path)
                    self.pinnedFolders.append(folder)
                    self.savePinnedFolders()
                    self.scanPinnedFolderSizes()
                }
            }
        }
    }
    
    /// Unpins a directory by ID
    func removePinnedFolder(id: UUID) {
        pinnedFolders.removeAll { $0.id == id }
        savePinnedFolders()
    }
    
    /// Refreshes the byte size of all pinned folders asynchronously
    func scanPinnedFolderSizes() {
        Task {
            var updatedFolders: [PinnedFolder] = []
            for var folder in self.pinnedFolders {
                let folderURL = URL(fileURLWithPath: folder.path)
                let size = await storageManager.getDirectorySizeAsync(at: folderURL)
                folder.size = size
                updatedFolders.append(folder)
            }
            self.pinnedFolders = updatedFolders
            self.savePinnedFolders()
        }
    }
    
    /// Opens the specified folder directly in Finder
    func openFolder(path: String) {
        let url = URL(fileURLWithPath: path)
        // First try standard URL opening. If it fails, fall back to explicit Finder viewer selection.
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }
    }
    
    /// Save custom pinned folders to UserDefaults
    private func savePinnedFolders() {
        if let encoded = try? JSONEncoder().encode(pinnedFolders) {
            UserDefaults.standard.set(encoded, forKey: "PinnedFolders")
        }
    }
    
    /// Load custom pinned folders from UserDefaults
    private func loadPinnedFolders() {
        if let data = UserDefaults.standard.data(forKey: "PinnedFolders"),
           let decoded = try? JSONDecoder().decode([PinnedFolder].self, from: data) {
            self.pinnedFolders = decoded
        }
    }
    
    // MARK: - Mole Utility Methods
    
    /// Helper to find the active path of the mo/mole binary
    private func getMoleBinaryPath() -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
            "/usr/bin/mo",
            "/bin/mo",
            "\(NSHomeDirectory())/.local/bin/mo"
        ]
        return commonPaths.first { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Checks if the mole/mo utility is installed on the user's system
    func checkMoleInstallation() {
        self.isMoleInstalled = (getMoleBinaryPath() != nil)
    }
    
    /// Launches the macOS Terminal app and runs the interactive `mo` command using a temporary executable .command file
    func runMole() {
        guard let binaryPath = getMoleBinaryPath() else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("clean_with_mole.command")
        
        let scriptContent = """
        #!/bin/bash
        "\(binaryPath)"
        exec $SHELL
        """
        
        do {
            try scriptContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Set POSIX execution permissions (chmod +x)
            let attributes = [FileAttributeKey.posixPermissions: NSNumber(value: 0o755)]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
            
            // Open the .command file with NSWorkspace to launch it in Terminal
            NSWorkspace.shared.open(fileURL)
        } catch {
            NSLog("Failed to create or run command file: \(error.localizedDescription)")
        }
    }
    
    /// Opens the official Mole GitHub repository in the browser
    func downloadMole() {
        if let url = URL(string: "https://github.com/tw93/mole") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Custom Terminal Commands
    
    /// Adds a new terminal command and persists it
    func addCustomCommand(name: String, command: String, folder: String?, tag: String?) {
        guard !name.isEmpty, !command.isEmpty else { return }
        let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderValue = cleanFolder?.isEmpty == true ? nil : cleanFolder
        let cleanTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagValue = cleanTag?.isEmpty == true ? nil : cleanTag
        let newCmd = TerminalCommand(id: UUID(), name: name, command: command, folder: folderValue, tag: tagValue)
        self.customCommands.append(newCmd)
        saveCustomCommands()
    }
    
    /// Updates an existing terminal command details and persists it
    func updateCustomCommand(id: UUID, name: String, command: String, folder: String?, tag: String?) {
        guard !name.isEmpty, !command.isEmpty else { return }
        if let idx = customCommands.firstIndex(where: { $0.id == id }) {
            let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderValue = cleanFolder?.isEmpty == true ? nil : cleanFolder
            let cleanTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
            let tagValue = cleanTag?.isEmpty == true ? nil : cleanTag
            customCommands[idx].name = name
            customCommands[idx].command = command
            customCommands[idx].folder = folderValue
            customCommands[idx].tag = tagValue
            saveCustomCommands()
        }
    }
    
    /// Removes a custom command by ID
    func removeCustomCommand(id: UUID) {
        customCommands.removeAll { $0.id == id }
        saveCustomCommands()
    }
    
    /// Executes a custom command inside a temporary shell script in Terminal
    func runCustomCommand(_ cmd: TerminalCommand) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("custom_command_\(cmd.id.uuidString).command")
        
        let scriptContent = """
        #!/bin/bash
        \(cmd.command)
        exec $SHELL
        """
        
        do {
            try scriptContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Set POSIX execution permissions (chmod +x)
            let attributes = [FileAttributeKey.posixPermissions: NSNumber(value: 0o755)]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
            
            // Add to running IDs immediately
            self.runningCommandIds.insert(cmd.id)
            
            if let tag = cmd.tag, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
                let cleanTag = tag.components(separatedBy: allowedChars.inverted).joined().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanTag.isEmpty {
                    // AppleScript to search for a tab with cleanTag as title and execute the script inside it.
                    // If not found, runs the script in a new tab/window and sets its custom title.
                    let appleScript = """
                    tell application "Terminal"
                        activate
                        set foundTab to missing value
                        repeat with w in windows
                            repeat with t in tabs of w
                                try
                                    if custom title of t is "\(cleanTag)" then
                                        set foundTab to t
                                        exit repeat
                                    end if
                                end try
                            end repeat
                            if foundTab is not missing value then exit repeat
                        end repeat
                        
                        if foundTab is not missing value then
                            do script "\(fileURL.path)" in foundTab
                        else
                            set newTab to (do script "\(fileURL.path)")
                            delay 0.5
                            set custom title of newTab to "\(cleanTag)"
                        end if
                    end tell
                    """
                    
                    let process = Process()
                    process.launchPath = "/usr/bin/osascript"
                    process.arguments = ["-e", appleScript]
                    try process.run()
                } else {
                    NSWorkspace.shared.open(fileURL)
                }
            } else {
                // Launch the command file in Terminal normally (opens a new window)
                NSWorkspace.shared.open(fileURL)
            }
            
            // Trigger a scan check after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkRunningCommands()
            }
        } catch {
            NSLog("Failed to run custom command: \(error.localizedDescription)")
        }
    }
    
    /// Scans for and terminates a specific terminal command by its unique ID using SIGINT (Ctrl+C) 4 times
    func stopCustomCommand(id: UUID) {
        // Remove from running IDs immediately
        self.runningCommandIds.remove(id)
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -eo pid,pgid,command | grep -F 'custom_command_\(id.uuidString).command' | grep -v grep"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                var pidsToKill: Set<Int32> = []
                var pgidsToKill: Set<Int32> = []
                
                let myPgid = getpgrp()
                let myPid = getpid()
                
                for line in lines {
                    let parts = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .components(separatedBy: .whitespaces)
                                    .filter { !$0.isEmpty }
                    if parts.count >= 2, let pid = Int32(parts[0]), let pgid = Int32(parts[1]) {
                        // Safety Check: do not kill self, system init/root processes or our own group
                        if pid == myPid || pgid == myPgid || pgid <= 1 || pid <= 1 {
                            continue
                        }
                        pidsToKill.insert(pid)
                        pgidsToKill.insert(pgid)
                    }
                }
                
                guard !pidsToKill.isEmpty || !pgidsToKill.isEmpty else { return }
                
                for _ in 1...4 {
                    for pgid in pgidsToKill {
                        kill(-pgid, SIGINT) // target the process group
                    }
                    for pid in pidsToKill {
                        kill(pid, SIGINT) // target individual pid
                    }
                    usleep(100_000) // 100ms
                }
                
                // Re-scan after stopping
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkRunningCommands()
                }
            }
        } catch {
            NSLog("Failed to stop custom command \(id): \(error.localizedDescription)")
        }
    }
    
    /// Scans for and terminates all terminal commands spawned by this app using SIGINT (Ctrl+C) 4 times
    func stopAllRunningCommands() {
        self.runningCommandIds.removeAll()
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -eo pid,pgid,command | grep -E 'custom_command_|clean_with_mole.command' | grep -v grep"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                var pidsToKill: Set<Int32> = []
                var pgidsToKill: Set<Int32> = []
                
                let myPgid = getpgrp()
                let myPid = getpid()
                
                for line in lines {
                    let parts = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .components(separatedBy: .whitespaces)
                                    .filter { !$0.isEmpty }
                    if parts.count >= 2, let pid = Int32(parts[0]), let pgid = Int32(parts[1]) {
                        // Safety Check: do not kill self, system init/root processes or our own group
                        if pid == myPid || pgid == myPgid || pgid <= 1 || pid <= 1 {
                            continue
                        }
                        pidsToKill.insert(pid)
                        pgidsToKill.insert(pgid)
                    }
                }
                
                // If nothing to kill, exit early
                guard !pidsToKill.isEmpty || !pgidsToKill.isEmpty else { return }
                
                // Send SIGINT (2) at least 4 times with short delays to stop subprocesses cleanly
                for _ in 1...4 {
                    for pgid in pgidsToKill {
                        kill(-pgid, SIGINT) // target the process group
                    }
                    for pid in pidsToKill {
                        kill(pid, SIGINT) // target individual pid
                    }
                    usleep(100_000) // 100ms
                }
                
                // Re-scan after stopping
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkRunningCommands()
                }
            }
        } catch {
            NSLog("Failed to scan and stop running commands: \(error.localizedDescription)")
        }
    }
    
    /// Scans the system process list to check which custom commands are currently executing
    func checkRunningCommands() {
        Task {
            // Run the blocking process execution on a global background queue
            let activeIds = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .background).async {
                    let task = Process()
                    task.launchPath = "/bin/bash"
                    task.arguments = ["-c", "ps -eo command | grep -E 'custom_command_[0-9A-Fa-f-]{36}' | grep -v grep"]
                    
                    let pipe = Pipe()
                    task.standardOutput = pipe
                    
                    do {
                        try task.run()
                        task.waitUntilExit()
                        
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            let lines = output.components(separatedBy: .newlines)
                            var ids = Set<UUID>()
                            for line in lines {
                                if let range = line.range(of: "custom_command_") {
                                    let sub = line[range.upperBound...]
                                    if let endRange = sub.range(of: ".command") {
                                        let uuidStr = String(sub[..<endRange.lowerBound])
                                        if let uuid = UUID(uuidString: uuidStr) {
                                            ids.insert(uuid)
                                        }
                                    }
                                }
                            }
                            continuation.resume(returning: ids)
                            return
                        }
                    } catch {
                        NSLog("Failed to scan running commands: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: Set<UUID>())
                }
            }
            
            // Update our published state on the main actor
            self.runningCommandIds = activeIds
        }
    }
    
    /// Starts a recurring timer to poll running commands every 2 seconds while DropdownView is visible
    func startMonitoringRunningCommands() {
        runningCommandsTimer?.cancel()
        // Run initial check immediately
        checkRunningCommands()
        // Then poll every 2 seconds
        runningCommandsTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkRunningCommands()
            }
    }
    
    /// Stops the recurring background monitoring timer
    func stopMonitoringRunningCommands() {
        runningCommandsTimer?.cancel()
        runningCommandsTimer = nil
    }
    
    /// Scans the size of the app itself and its local settings/plist storage
    func scanAppSelfSizes() {
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            
            // 1. App Bundle Size (.app folder size)
            let bundlePath = Bundle.main.bundlePath
            let bundleURL = URL(fileURLWithPath: bundlePath)
            var computedBundleSize: Int64 = 0
            
            let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
            if let enumerator = fileManager.enumerator(
                at: bundleURL,
                includingPropertiesForKeys: keys,
                options: []
            ) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                       values.isRegularFile == true {
                        computedBundleSize += Int64(values.fileSize ?? 0)
                    }
                }
            }
            
            // 2. App Settings plist size (~/Library/Preferences/com.rian445.MacASC.plist)
            let homeDir = fileManager.homeDirectoryForCurrentUser
            let plistURL = homeDir.appendingPathComponent("Library/Preferences/com.rian445.MacASC.plist")
            var computedSettingsSize: Int64 = 0
            if let attributes = try? fileManager.attributesOfItem(atPath: plistURL.path),
               let sizeVal = attributes[.size] as? Int64 {
                computedSettingsSize = sizeVal
            }
            
            // 3. User Data Breakdown from UserDefaults
            let commandsData = UserDefaults.standard.data(forKey: "CustomCommands")
            let computedCommandsSize = Int64(commandsData?.count ?? 0)
            
            let notesData = UserDefaults.standard.data(forKey: "QuickNotes")
            let computedNotesSize = Int64(notesData?.count ?? 0)
            
            let computedGeneralSettingsSize = max(0, computedSettingsSize - computedCommandsSize - computedNotesSize)
            
            // Create immutable copies to capture safely in Sendable closure
            let finalBundleSize = computedBundleSize
            let finalSettingsSize = computedSettingsSize
            let finalCommandsSize = computedCommandsSize
            let finalNotesSize = computedNotesSize
            let finalGeneralSettingsSize = computedGeneralSettingsSize
            
            // Post update back to the main thread
            await MainActor.run {
                self.appBundleSize = finalBundleSize
                self.appSettingsSize = finalSettingsSize
                self.appCommandsSize = finalCommandsSize
                self.appNotesSize = finalNotesSize
                self.appGeneralSettingsSize = finalGeneralSettingsSize
            }
        }
    }
    
    /// Save custom commands to UserDefaults
    private func saveCustomCommands() {
        if let encoded = try? JSONEncoder().encode(customCommands) {
            UserDefaults.standard.set(encoded, forKey: "CustomCommands")
        }
    }
    
    /// Load custom commands from UserDefaults
    private func loadCustomCommands() {
        if let data = UserDefaults.standard.data(forKey: "CustomCommands"),
           let decoded = try? JSONDecoder().decode([TerminalCommand].self, from: data) {
            self.customCommands = decoded
        }
    }
    
    // MARK: - Quick Notes Methods
    
    /// Adds a new quick note and persists it
    func addQuickNote(title: String, content: String) {
        guard !title.isEmpty, !content.isEmpty else { return }
        let newNote = QuickNote(id: UUID(), title: title, content: content, dateCreated: Date())
        self.quickNotes.append(newNote)
        saveQuickNotes()
    }
    
    /// Updates an existing quick note details and persists it
    func updateQuickNote(id: UUID, title: String, content: String) {
        guard !title.isEmpty, !content.isEmpty else { return }
        if let idx = quickNotes.firstIndex(where: { $0.id == id }) {
            quickNotes[idx].title = title
            quickNotes[idx].content = content
            saveQuickNotes()
        }
    }
    
    /// Removes a quick note by ID
    func removeQuickNote(id: UUID) {
        quickNotes.removeAll { $0.id == id }
        saveQuickNotes()
    }
    
    /// Save quick notes to UserDefaults
    private func saveQuickNotes() {
        if let encoded = try? JSONEncoder().encode(quickNotes) {
            UserDefaults.standard.set(encoded, forKey: "QuickNotes")
        }
    }
    
    /// Load quick notes from UserDefaults
    private func loadQuickNotes() {
        if let data = UserDefaults.standard.data(forKey: "QuickNotes"),
           let decoded = try? JSONDecoder().decode([QuickNote].self, from: data) {
            self.quickNotes = decoded
        }
    }
    
    /// Save storage breakdown cache to UserDefaults
    private func saveStorageBreakdown() {
        if let encoded = try? JSONEncoder().encode(storageBreakdown) {
            UserDefaults.standard.set(encoded, forKey: "CachedStorageBreakdown")
        }
    }
    
    /// Load storage breakdown cache from UserDefaults
    private func loadStorageBreakdown() {
        if let data = UserDefaults.standard.data(forKey: "CachedStorageBreakdown"),
           let decoded = try? JSONDecoder().decode(StorageBreakdown.self, from: data) {
            self.storageBreakdown = decoded
        }
    }
    
    // MARK: - AI Chat Methods
    
    /// Checks if opencode is installed on the user's system
    func checkOpencodeInstallation() {
        self.isOpencodeInstalled = (getOpencodeBinaryPath() != nil)
    }
    
    /// Finds the location of the opencode binary on the user's system
    private func getOpencodeBinaryPath() -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/opencode",
            "/usr/local/bin/opencode"
        ]
        let fileManager = FileManager.default
        for path in commonPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    /// Loads the AI chat history and threads from UserDefaults
    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: "AIChatThreads"),
           let decoded = try? JSONDecoder().decode([ChatThread].self, from: data) {
            self.chatThreads = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: "AISelectedThreadId"),
           let uuid = UUID(uuidString: idString) {
            self.selectedThreadId = uuid
        }
        
        // Clean up duplicate empty "New Chat" threads (keep at most one)
        var seenEmpty = false
        var cleanedThreads: [ChatThread] = []
        for thread in chatThreads {
            if thread.messages.isEmpty && thread.title == "New Chat" {
                if !seenEmpty {
                    cleanedThreads.append(thread)
                    seenEmpty = true
                }
            } else {
                cleanedThreads.append(thread)
            }
        }
        self.chatThreads = cleanedThreads
        
        // Migrate old single chat messages if they exist
        if chatThreads.isEmpty {
            if let oldData = UserDefaults.standard.data(forKey: "AIChatHistory"),
               let oldMessages = try? JSONDecoder().decode([ChatMessage].self, from: oldData) {
                let oldSessionId = UserDefaults.standard.string(forKey: "AIActiveSessionId")
                let migratedThread = ChatThread(
                    id: UUID(),
                    title: "Previous Chat",
                    activeSessionId: oldSessionId,
                    messages: oldMessages,
                    dateCreated: Date()
                )
                self.chatThreads = [migratedThread]
                self.selectedThreadId = migratedThread.id
                // Remove old keys to avoid re-migration
                UserDefaults.standard.removeObject(forKey: "AIChatHistory")
                UserDefaults.standard.removeObject(forKey: "AIActiveSessionId")
            } else {
                createNewChatThread()
            }
        }
        
        // Ensure we have a valid selection
        if selectedThreadId == nil || !chatThreads.contains(where: { $0.id == selectedThreadId }) {
            selectedThreadId = chatThreads.first?.id
        }
    }
    
    /// Saves the AI chat threads and selected thread ID to UserDefaults
    private func saveChatHistory() {
        if let encoded = try? JSONEncoder().encode(chatThreads) {
            UserDefaults.standard.set(encoded, forKey: "AIChatThreads")
        }
        if let selectedId = selectedThreadId {
            UserDefaults.standard.set(selectedId.uuidString, forKey: "AISelectedThreadId")
        } else {
            UserDefaults.standard.removeObject(forKey: "AISelectedThreadId")
        }
    }
    
    /// Creates a new chat thread and selects it
    func createNewChatThread() {
        // If there is already an empty thread, select it instead of creating a duplicate
        if let existingEmpty = chatThreads.first(where: { $0.messages.isEmpty && $0.title == "New Chat" }) {
            self.selectedThreadId = existingEmpty.id
            saveChatHistory()
            return
        }
        
        let newThread = ChatThread(
            id: UUID(),
            title: "New Chat",
            activeSessionId: nil,
            messages: [],
            dateCreated: Date()
        )
        self.chatThreads.append(newThread)
        self.selectedThreadId = newThread.id
        saveChatHistory()
    }
    
    /// Selects an existing chat thread
    func selectChatThread(id: UUID) {
        stopAiMessageQuery()
        self.selectedThreadId = id
        saveChatHistory()
    }
    
    /// Deletes a chat thread by ID
    func deleteChatThread(id: UUID) {
        if selectedThreadId == id {
            stopAiMessageQuery()
        }
        self.chatThreads.removeAll { $0.id == id }
        if self.chatThreads.isEmpty {
            createNewChatThread()
        } else {
            self.selectedThreadId = chatThreads.first?.id
        }
        saveChatHistory()
    }
    
    /// Clears messages in the active chat thread and resets its session
    func clearChatHistory() {
        stopAiMessageQuery()
        if let threadId = selectedThreadId,
           let idx = chatThreads.firstIndex(where: { $0.id == threadId }) {
            self.chatThreads[idx].messages.removeAll()
            self.chatThreads[idx].activeSessionId = nil
            self.chatThreads[idx].title = "New Chat"
            saveChatHistory()
        }
    }
    
    /// Sends a query message to the AI (opencode binary) in the background
    func sendChatMessage(_ text: String) {
        guard !text.isEmpty, let threadId = selectedThreadId else { return }
        
        // Find current thread index
        guard let idx = chatThreads.firstIndex(where: { $0.id == threadId }) else { return }
        
        let userMessage = ChatMessage(id: UUID(), text: text, isUser: true, timestamp: Date())
        self.chatThreads[idx].messages.append(userMessage)
        
        // Auto-rename thread title if it was default
        if chatThreads[idx].title == "New Chat" {
            let limit = 20
            let cleanTitle = text.count > limit ? String(text.prefix(limit)) + "..." : text
            chatThreads[idx].title = cleanTitle
        }
        
        saveChatHistory()
        self.isAiResponding = true
        
        Task.detached(priority: .userInitiated) {
            guard let binaryPath = await self.getOpencodeBinaryPath() else {
                await MainActor.run {
                    if let threadIdx = self.chatThreads.firstIndex(where: { $0.id == threadId }) {
                        let errorMessage = ChatMessage(
                            id: UUID(),
                            text: "Error: Could not find 'opencode' binary. Please verify that opencode is installed at /opt/homebrew/bin/opencode or /usr/local/bin/opencode.",
                            isUser: false,
                            timestamp: Date()
                        )
                        self.chatThreads[threadIdx].messages.append(errorMessage)
                        self.isAiResponding = false
                        self.saveChatHistory()
                    }
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            
            // Set up arguments
            var arguments = ["run", text, "--dir", "/tmp"]
            
            // Check if this thread has an active session ID to resume
            let threadSessionId = await self.chatThreads.first(where: { $0.id == threadId })?.activeSessionId
            if let sessionId = threadSessionId {
                arguments.append("--session")
                arguments.append(sessionId)
            } else {
                // First query in thread: request logs to scrape the newly generated session ID
                arguments.append("--print-logs")
            }
            
            process.arguments = arguments
            
            // Set input to null device so it runs headless and won't hang waiting for stdin
            process.standardInput = FileHandle.nullDevice
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            await MainActor.run {
                self.activeAiProcess = process
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let rawOutput = String(data: data, encoding: .utf8) ?? ""
                let cleanedOutput = await self.cleanOpencodeOutput(rawOutput)
                
                await MainActor.run {
                    // Check if this was the active process we expected (not cancelled)
                    if self.activeAiProcess === process {
                        if let threadIdx = self.chatThreads.firstIndex(where: { $0.id == threadId }) {
                            // Extract session ID if we don't have one yet for this thread
                            if self.chatThreads[threadIdx].activeSessionId == nil {
                                if let sessionRange = rawOutput.range(of: "ses_[a-zA-Z0-9]+", options: .regularExpression) {
                                    let matchedId = String(rawOutput[sessionRange])
                                    self.chatThreads[threadIdx].activeSessionId = matchedId
                                }
                            }
                            
                            let aiMessage = ChatMessage(id: UUID(), text: cleanedOutput, isUser: false, timestamp: Date())
                            self.chatThreads[threadIdx].messages.append(aiMessage)
                            self.isAiResponding = false
                            self.activeAiProcess = nil
                            self.saveChatHistory()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if self.activeAiProcess === process {
                        if let threadIdx = self.chatThreads.firstIndex(where: { $0.id == threadId }) {
                            let errorMessage = ChatMessage(id: UUID(), text: "Error executing AI process: \(error.localizedDescription)", isUser: false, timestamp: Date())
                            self.chatThreads[threadIdx].messages.append(errorMessage)
                            self.isAiResponding = false
                            self.activeAiProcess = nil
                            self.saveChatHistory()
                        }
                    }
                }
            }
        }
    }
    
    /// Interrupts/terminates the active opencode background process and clears port/process
    func stopAiMessageQuery() {
        if let process = activeAiProcess {
            if process.isRunning {
                process.terminate()
            }
            activeAiProcess = nil
        }
        if isAiResponding {
            isAiResponding = false
            // Add a notice that query was stopped by user to the selected thread
            if let threadId = selectedThreadId,
               let idx = chatThreads.firstIndex(where: { $0.id == threadId }) {
                let stopMessage = ChatMessage(id: UUID(), text: "Query stopped by user.", isUser: false, timestamp: Date())
                chatThreads[idx].messages.append(stopMessage)
                saveChatHistory()
            }
        }
    }
    
    /// Filters and cleans the TUI/progress output from opencode stdout
    private func cleanOpencodeOutput(_ raw: String) -> String {
        var cleaned = raw
        
        // 1. Strip ESC-prefixed ANSI sequences
        if let escRegex = try? NSRegularExpression(pattern: "[\u{001B}\u{009B}][\\[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]", options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = escRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // 2. Strip raw bracket style sequences (like "[0m", "[?25h" that lost their ESC character)
        if let bracketRegex = try? NSRegularExpression(pattern: "\\[\\??[0-9;]*[a-zA-Z]", options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = bracketRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // 3. Line by line cleaning (filter build logs and timestamp logs)
        let lines = cleaned.components(separatedBy: .newlines)
        var filteredLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip build loader blocks and background log prints
            if trimmed.hasPrefix("> build ·") || trimmed.hasPrefix("> build") || trimmed.hasPrefix("timestamp=") {
                continue
            }
            filteredLines.append(line)
        }
        
        let joined = filteredLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "No output." : joined
    }
}

// MARK: - Models

struct TerminalCommand: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var folder: String?
    var tag: String?
}

struct QuickNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var dateCreated: Date
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
}

struct ChatThread: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var activeSessionId: String?
    var messages: [ChatMessage]
    let dateCreated: Date
}
