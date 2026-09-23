import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

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
    @Published var appChatAiSize: Int64 = 0
    @Published var appGeneralSettingsSize: Int64 = 0
    @Published var chatThreads: [ChatThread] = []
    @Published var selectedThreadId: UUID? = nil
    @Published var isAiResponding = false
    @Published var isOpencodeInstalled = false
    @Published var isCodexInstalled = false
    @Published var isAntigravityInstalled = false
    @Published var allowAiSystemActions = false
    @Published var enableDiskInsight = true
    @Published var enableCustomCommands = true
    @Published var enableQuickNotes = true
    @Published var enableAiChat = true
    @Published var enableScreenRecorder = true
    @Published var enableTimeTracker = true
    @Published var isNotificationAuthorized: Bool = true
    @Published var tabOrder: [Int] = [0, 1, 2, 3, 4, 5]
    @Published var timeEvents: [TimeEvent] = []
    @Published var timeEventFolderOrder: [String] = []
    @Published var tabShortcuts: [Int: TabShortcut] = [:]
    @Published var customCommandFolderOrder: [String] = []
    @Published var quickNoteFolderOrder: [String] = []
    @Published var availableModels: [String] = []
    @Published var selectedModel: String = ""
    @Published var favoriteModels: [String] = []
    @Published var selectedLogo: String = "walter"
    @Published var selectedRecordLogo: String = "phoenix"
    
    // Antigravity Usage Quotas
    @Published var agyUsageGroups: [AgyUsageGroup] = []
    @Published var agyUsageQuotas: [AgyUsageQuota] = []
    @Published var isFetchingAgyUsage: Bool = false
    @Published var agyUsageLastFetched: Date? = nil
    @Published var agyUsageError: String? = nil
    
    // Screen Recorder state variables
    @Published var screenRecordResolution: String = "native"
    @Published var screenRecordCaptureMode: String = "fullscreen"
    @Published var screenRecordSavePath: String = "~/Desktop"
    @Published var screenRecordMicEnabled: Bool = false
    @Published var screenRecordFps: Int = 60
    @Published var screenRecordQuality: String = "medium"
    @Published var isRecording: Bool = false
    @Published var isRecordingPaused: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recentRecordings: [URL] = []
    
    private let recorder = ScreenRecorder()
    private var recordingTimer: AnyCancellable? = nil
    private var recordingStartTime: Date? = nil
    private var accumulatedDuration: TimeInterval = 0
    private var activeAiProcess: Process? = nil
    private var cachedOpencodePath: String? = nil
    private var cachedCodexPath: String? = nil
    private var cachedAntigravityPath: String? = nil
    
    var selectedThread: ChatThread? {
        chatThreads.first(where: { $0.id == selectedThreadId })
    }
    
    
    // MARK: - Dependencies & Listeners
    private let storageManager = StorageManager()
    private var cancellables = Set<AnyCancellable>()
    private var runningCommandsTimer: AnyCancellable? = nil
    
    init() {
        // Load tweak settings
        loadTweakSettings()
        // Load selected AI model
        loadSelectedModel()
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
    
    /// Loads the Tweak settings for enabling/disabling dashboard tabs, custom tab ordering, and sort preferences
    private func loadTweakSettings() {
        self.enableDiskInsight = UserDefaults.standard.object(forKey: "TweakDiskInsight") as? Bool ?? true
        self.enableCustomCommands = UserDefaults.standard.object(forKey: "TweakCustomCommands") as? Bool ?? true
        self.enableQuickNotes = UserDefaults.standard.object(forKey: "TweakQuickNote") as? Bool ?? true
        self.enableAiChat = UserDefaults.standard.object(forKey: "TweakChatWithAi") as? Bool ?? true
        self.enableScreenRecorder = UserDefaults.standard.object(forKey: "TweakScreenRecorder") as? Bool ?? true
        self.enableTimeTracker = UserDefaults.standard.object(forKey: "TweakTimeTracker") as? Bool ?? true
        
        self.customCommandFolderOrder = UserDefaults.standard.stringArray(forKey: "CustomCommandFolderOrder") ?? []
        self.quickNoteFolderOrder = UserDefaults.standard.stringArray(forKey: "QuickNoteFolderOrder") ?? []
        
        if let savedOrder = UserDefaults.standard.array(forKey: "DashboardTabOrder") as? [Int], !savedOrder.isEmpty {
            var order = savedOrder.filter { [0, 1, 2, 3, 4, 5].contains($0) }
            for id in [0, 1, 2, 3, 4, 5] {
                if !order.contains(id) { order.append(id) }
            }
            self.tabOrder = order
        } else {
            self.tabOrder = [0, 1, 2, 3, 4, 5]
        }
        
        self.selectedLogo = UserDefaults.standard.string(forKey: "SelectedLogo") ?? "walter"
        self.selectedRecordLogo = UserDefaults.standard.string(forKey: "SelectedRecordLogo") ?? "phoenix"
        NotificationCenter.default.post(name: Notification.Name("UpdateMenuBarIcon"), object: nil)
        
        loadTabShortcuts()
        loadScreenRecorderPreferences()
        loadTimeEvents()
    }
    
    // MARK: - Folder Tree & Reordering Helpers
    
    func buildFolderTree(from rawPaths: [String], customOrder: [String]) -> [FolderNode] {
        var allPathsSet = Set<String>()
        for rawPath in rawPaths {
            let components = rawPath.split(separator: "/").map(String.init)
            var currentPath = ""
            for (idx, comp) in components.enumerated() {
                currentPath = idx == 0 ? comp : "\(currentPath)/\(comp)"
                allPathsSet.insert(currentPath)
            }
        }
        
        func buildNodes(parentPath: String?) -> [FolderNode] {
            let candidatePaths: [String]
            if let parent = parentPath {
                let prefix = parent + "/"
                candidatePaths = allPathsSet.filter { path in
                    path.hasPrefix(prefix) && !path.dropFirst(prefix.count).contains("/")
                }
            } else {
                candidatePaths = allPathsSet.filter { !$0.contains("/") }
            }
            
            var ordered = customOrder.filter { candidatePaths.contains($0) }
            for p in candidatePaths.sorted() {
                if !ordered.contains(p) {
                    ordered.append(p)
                }
            }
            
            return ordered.map { path in
                let name = String(path.split(separator: "/").last ?? "")
                let children = buildNodes(parentPath: path)
                return FolderNode(name: name, fullPath: path, subfolders: children)
            }
        }
        
        return buildNodes(parentPath: nil)
    }
    
    func getCommandFolderTree() -> [FolderNode] {
        let rawFolders = Array(Set(customCommands.compactMap { $0.folder })).filter { !$0.isEmpty }
        return buildFolderTree(from: rawFolders, customOrder: customCommandFolderOrder)
    }
    
    func getNoteFolderTree() -> [FolderNode] {
        let rawFolders = Array(Set(quickNotes.compactMap { $0.folder })).filter { !$0.isEmpty }
        return buildFolderTree(from: rawFolders, customOrder: quickNoteFolderOrder)
    }
    
    func getFormattedFolderPaths(_ nodes: [FolderNode], depth: Int = 0) -> [(path: String, label: String)] {
        var result: [(path: String, label: String)] = []
        let indent = String(repeating: "   ", count: depth)
        let prefixStr = depth == 0 ? "" : "└── "
        for node in nodes {
            let label = "\(indent)\(prefixStr)\(node.name)"
            result.append((path: node.fullPath, label: label))
            result.append(contentsOf: getFormattedFolderPaths(node.subfolders, depth: depth + 1))
        }
        return result
    }
    
    func moveCommandFolderUp(name: String) {
        let siblings = getSiblingFolderPaths(for: name, in: getCommandFolderTree())
        guard let idx = siblings.firstIndex(of: name), idx > 0 else { return }
        var order = customCommandFolderOrder
        let target = siblings[idx - 1]
        if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
            order.swapAt(idxA, idxB)
        } else {
            if !order.contains(name) { order.append(name) }
            if !order.contains(target) { order.append(target) }
            if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
                order.swapAt(idxA, idxB)
            }
        }
        customCommandFolderOrder = order
        UserDefaults.standard.set(order, forKey: "CustomCommandFolderOrder")
        self.objectWillChange.send()
    }
    
    func moveCommandFolderDown(name: String) {
        let siblings = getSiblingFolderPaths(for: name, in: getCommandFolderTree())
        guard let idx = siblings.firstIndex(of: name), idx < siblings.count - 1 else { return }
        var order = customCommandFolderOrder
        let target = siblings[idx + 1]
        if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
            order.swapAt(idxA, idxB)
        } else {
            if !order.contains(name) { order.append(name) }
            if !order.contains(target) { order.append(target) }
            if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
                order.swapAt(idxA, idxB)
            }
        }
        customCommandFolderOrder = order
        UserDefaults.standard.set(order, forKey: "CustomCommandFolderOrder")
        self.objectWillChange.send()
    }
    
    func moveNoteFolderUp(name: String) {
        let siblings = getSiblingFolderPaths(for: name, in: getNoteFolderTree())
        guard let idx = siblings.firstIndex(of: name), idx > 0 else { return }
        var order = quickNoteFolderOrder
        let target = siblings[idx - 1]
        if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
            order.swapAt(idxA, idxB)
        } else {
            if !order.contains(name) { order.append(name) }
            if !order.contains(target) { order.append(target) }
            if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
                order.swapAt(idxA, idxB)
            }
        }
        quickNoteFolderOrder = order
        UserDefaults.standard.set(order, forKey: "QuickNoteFolderOrder")
        self.objectWillChange.send()
    }
    
    func moveNoteFolderDown(name: String) {
        let siblings = getSiblingFolderPaths(for: name, in: getNoteFolderTree())
        guard let idx = siblings.firstIndex(of: name), idx < siblings.count - 1 else { return }
        var order = quickNoteFolderOrder
        let target = siblings[idx + 1]
        if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
            order.swapAt(idxA, idxB)
        } else {
            if !order.contains(name) { order.append(name) }
            if !order.contains(target) { order.append(target) }
            if let idxA = order.firstIndex(of: name), let idxB = order.firstIndex(of: target) {
                order.swapAt(idxA, idxB)
            }
        }
        quickNoteFolderOrder = order
        UserDefaults.standard.set(order, forKey: "QuickNoteFolderOrder")
        self.objectWillChange.send()
    }
    
    private func getSiblingFolderPaths(for name: String, in tree: [FolderNode]) -> [String] {
        let parentPath: String? = name.contains("/") ? String(name.prefix(upTo: name.lastIndex(of: "/")!)) : nil
        if let parent = parentPath {
            func findSiblings(_ nodes: [FolderNode]) -> [FolderNode]? {
                for node in nodes {
                    if node.fullPath == parent {
                        return node.subfolders
                    }
                    if let found = findSiblings(node.subfolders) {
                        return found
                    }
                }
                return nil
            }
            return (findSiblings(tree) ?? []).map { $0.fullPath }
        } else {
            return tree.map { $0.fullPath }
        }
    }
    
    // MARK: - Folder Deletion & Drag-and-Drop Nesting Logic
    
    func deleteCommandFolder(_ folderPath: String, deleteContents: Bool) {
        if deleteContents {
            customCommands.removeAll { cmd in
                guard let f = cmd.folder else { return false }
                return f == folderPath || f.hasPrefix(folderPath + "/")
            }
        } else {
            for i in customCommands.indices {
                if let f = customCommands[i].folder, f == folderPath || f.hasPrefix(folderPath + "/") {
                    if f == folderPath {
                        customCommands[i].folder = nil
                    } else {
                        let remaining = String(f.dropFirst(folderPath.count + 1))
                        customCommands[i].folder = remaining.isEmpty ? nil : remaining
                    }
                }
            }
        }
        saveCustomCommands()
        customCommandFolderOrder.removeAll { $0 == folderPath || $0.hasPrefix(folderPath + "/") }
        UserDefaults.standard.set(customCommandFolderOrder, forKey: "CustomCommandFolderOrder")
        self.objectWillChange.send()
    }
    
    func deleteNoteFolder(_ folderPath: String, deleteContents: Bool) {
        if deleteContents {
            quickNotes.removeAll { note in
                guard let f = note.folder else { return false }
                return f == folderPath || f.hasPrefix(folderPath + "/")
            }
        } else {
            for i in quickNotes.indices {
                if let f = quickNotes[i].folder, f == folderPath || f.hasPrefix(folderPath + "/") {
                    if f == folderPath {
                        quickNotes[i].folder = nil
                    } else {
                        let remaining = String(f.dropFirst(folderPath.count + 1))
                        quickNotes[i].folder = remaining.isEmpty ? nil : remaining
                    }
                }
            }
        }
        saveQuickNotes()
        quickNoteFolderOrder.removeAll { $0 == folderPath || $0.hasPrefix(folderPath + "/") }
        UserDefaults.standard.set(quickNoteFolderOrder, forKey: "QuickNoteFolderOrder")
        self.objectWillChange.send()
    }
    
    func nestCommandFolder(sourcePath: String, targetParentPath: String) {
        guard sourcePath != targetParentPath && !targetParentPath.hasPrefix(sourcePath + "/") else { return }
        let sourceFolderName = String(sourcePath.split(separator: "/").last ?? "")
        let newFolderPath = targetParentPath.isEmpty ? sourceFolderName : "\(targetParentPath)/\(sourceFolderName)"
        
        for i in customCommands.indices {
            if let f = customCommands[i].folder {
                if f == sourcePath {
                    customCommands[i].folder = newFolderPath
                } else if f.hasPrefix(sourcePath + "/") {
                    let suffix = String(f.dropFirst(sourcePath.count))
                    customCommands[i].folder = newFolderPath + suffix
                }
            }
        }
        saveCustomCommands()
        
        var order = customCommandFolderOrder
        if let idx = order.firstIndex(of: sourcePath) {
            order.remove(at: idx)
        }
        if !order.contains(newFolderPath) {
            order.append(newFolderPath)
        }
        customCommandFolderOrder = order
        UserDefaults.standard.set(customCommandFolderOrder, forKey: "CustomCommandFolderOrder")
        self.objectWillChange.send()
    }
    
    func nestNoteFolder(sourcePath: String, targetParentPath: String) {
        guard sourcePath != targetParentPath && !targetParentPath.hasPrefix(sourcePath + "/") else { return }
        let sourceFolderName = String(sourcePath.split(separator: "/").last ?? "")
        let newFolderPath = targetParentPath.isEmpty ? sourceFolderName : "\(targetParentPath)/\(sourceFolderName)"
        
        for i in quickNotes.indices {
            if let f = quickNotes[i].folder {
                if f == sourcePath {
                    quickNotes[i].folder = newFolderPath
                } else if f.hasPrefix(sourcePath + "/") {
                    let suffix = String(f.dropFirst(sourcePath.count))
                    quickNotes[i].folder = newFolderPath + suffix
                }
            }
        }
        saveQuickNotes()
        
        var order = quickNoteFolderOrder
        if let idx = order.firstIndex(of: sourcePath) {
            order.remove(at: idx)
        }
        if !order.contains(newFolderPath) {
            order.append(newFolderPath)
        }
        quickNoteFolderOrder = order
        UserDefaults.standard.set(quickNoteFolderOrder, forKey: "QuickNoteFolderOrder")
        self.objectWillChange.send()
    }
    
    func unnestCommandFolder(_ sourcePath: String) {
        guard sourcePath.contains("/") else { return }
        let components = sourcePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }
        
        let parentComponents = components.dropLast(2)
        let newParentPath = parentComponents.joined(separator: "/")
        nestCommandFolder(sourcePath: sourcePath, targetParentPath: newParentPath)
    }

    func unnestNoteFolder(_ sourcePath: String) {
        guard sourcePath.contains("/") else { return }
        let components = sourcePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }
        
        let parentComponents = components.dropLast(2)
        let newParentPath = parentComponents.joined(separator: "/")
        nestNoteFolder(sourcePath: sourcePath, targetParentPath: newParentPath)
    }
    
    func moveCommandUp(id: UUID) {
        guard let currentIdx = customCommands.firstIndex(where: { $0.id == id }) else { return }
        let targetFolder = customCommands[currentIdx].folder
        let groupIndices = customCommands.indices.filter { customCommands[$0].folder == targetFolder }
        guard let posInGroup = groupIndices.firstIndex(of: currentIdx), posInGroup > 0 else { return }
        let swapWithIdx = groupIndices[posInGroup - 1]
        customCommands.swapAt(currentIdx, swapWithIdx)
        saveCustomCommands()
    }

    func moveCommandDown(id: UUID) {
        guard let currentIdx = customCommands.firstIndex(where: { $0.id == id }) else { return }
        let targetFolder = customCommands[currentIdx].folder
        let groupIndices = customCommands.indices.filter { customCommands[$0].folder == targetFolder }
        guard let posInGroup = groupIndices.firstIndex(of: currentIdx), posInGroup < groupIndices.count - 1 else { return }
        let swapWithIdx = groupIndices[posInGroup + 1]
        customCommands.swapAt(currentIdx, swapWithIdx)
        saveCustomCommands()
    }

    func moveNoteUp(id: UUID) {
        guard let currentIdx = quickNotes.firstIndex(where: { $0.id == id }) else { return }
        let targetFolder = quickNotes[currentIdx].folder
        let groupIndices = quickNotes.indices.filter { quickNotes[$0].folder == targetFolder }
        guard let posInGroup = groupIndices.firstIndex(of: currentIdx), posInGroup > 0 else { return }
        let swapWithIdx = groupIndices[posInGroup - 1]
        quickNotes.swapAt(currentIdx, swapWithIdx)
        saveQuickNotes()
    }

    func moveNoteDown(id: UUID) {
        guard let currentIdx = quickNotes.firstIndex(where: { $0.id == id }) else { return }
        let targetFolder = quickNotes[currentIdx].folder
        let groupIndices = quickNotes.indices.filter { quickNotes[$0].folder == targetFolder }
        guard let posInGroup = groupIndices.firstIndex(of: currentIdx), posInGroup < groupIndices.count - 1 else { return }
        let swapWithIdx = groupIndices[posInGroup + 1]
        quickNotes.swapAt(currentIdx, swapWithIdx)
        saveQuickNotes()
    }
    
    /// Moves a tab up in the display order
    func moveTabUp(at index: Int) {
        guard index > 0 && index < tabOrder.count else { return }
        tabOrder.swapAt(index, index - 1)
        saveTabOrder()
    }
    
    /// Moves a tab down in the display order
    func moveTabDown(at index: Int) {
        guard index >= 0 && index < tabOrder.count - 1 else { return }
        tabOrder.swapAt(index, index + 1)
        saveTabOrder()
    }
    
    /// Resets tab display order to default [0, 1, 2, 3, 4, 5]
    func resetTabOrder() {
        tabOrder = [0, 1, 2, 3, 4, 5]
        saveTabOrder()
    }
    
    /// Persists tabOrder to UserDefaults
    func saveTabOrder() {
        UserDefaults.standard.set(tabOrder, forKey: "DashboardTabOrder")
        self.objectWillChange.send()
    }

    // MARK: - Tab Keyboard Shortcuts
    
    /// Loads saved tab keyboard shortcuts or initializes defaults (Cmd+1..4)
    func loadTabShortcuts() {
        if let data = UserDefaults.standard.data(forKey: "TabKeyboardShortcuts"),
           let saved = try? JSONDecoder().decode([String: TabShortcut].self, from: data) {
            var map: [Int: TabShortcut] = [:]
            for (k, v) in saved {
                if let id = Int(k) { map[id] = v }
            }
            // Self-healing default shortcut injection for Screen Recorder and Time Tracker tabs
            if map[4] == nil {
                let cmdModifier = NSEvent.ModifierFlags.command.rawValue
                map[4] = TabShortcut(key: "5", modifiers: cmdModifier)
            }
            if map[5] == nil {
                let cmdModifier = NSEvent.ModifierFlags.command.rawValue
                map[5] = TabShortcut(key: "6", modifiers: cmdModifier)
            }
            self.tabShortcuts = map
        } else {
            resetTabShortcutsToDefault()
        }
    }
    
    /// Resets tab shortcuts to default (Cmd+1 for Disk, Cmd+2 for Commands, Cmd+3 for Notes, Cmd+4 for AI, Cmd+5 for Recorder, Cmd+6 for Time Tracker)
    func resetTabShortcutsToDefault() {
        let cmdModifier = NSEvent.ModifierFlags.command.rawValue
        self.tabShortcuts = [
            0: TabShortcut(key: "1", modifiers: cmdModifier),
            1: TabShortcut(key: "2", modifiers: cmdModifier),
            2: TabShortcut(key: "3", modifiers: cmdModifier),
            3: TabShortcut(key: "4", modifiers: cmdModifier),
            4: TabShortcut(key: "5", modifiers: cmdModifier),
            5: TabShortcut(key: "6", modifiers: cmdModifier)
        ]
        saveTabShortcuts()
    }
    
    /// Saves tab keyboard shortcuts to UserDefaults
    func saveTabShortcuts() {
        var strMap: [String: TabShortcut] = [:]
        for (k, v) in tabShortcuts {
            strMap[String(k)] = v
        }
        if let encoded = try? JSONEncoder().encode(strMap) {
            UserDefaults.standard.set(encoded, forKey: "TabKeyboardShortcuts")
        }
        self.objectWillChange.send()
    }
    
    /// Sets or updates the shortcut for a tab
    func setTabShortcut(tabId: Int, key: String, modifiers: UInt) {
        let cleanKey = key.lowercased()
        self.tabShortcuts[tabId] = TabShortcut(key: cleanKey, modifiers: modifiers)
        saveTabShortcuts()
    }

    /// Loads the selected AI model and starts loading all available models
    private func loadSelectedModel() {
        let savedModel = UserDefaults.standard.string(forKey: "AISelectedModel") ?? ""
        if savedModel.isEmpty || savedModel.contains("Gemma") || savedModel.contains("270M") || savedModel.contains("1B") || savedModel.contains("Local LLM") || savedModel.contains("deepseek-v4-flash-free") {
            self.selectedModel = ""
        } else {
            self.selectedModel = savedModel
        }
        
        self.favoriteModels = UserDefaults.standard.stringArray(forKey: "AIFavoriteModels") ?? []
        
        // Remove legacy models and deepseek-v4-flash-free from favorites
        self.favoriteModels.removeAll {
            $0.contains("Gemma") ||
            $0.contains("Local LLM") ||
            $0.contains("gemini-3.5-flash") ||
            $0.contains("deepseek-v4-flash-free")
        }
        
        UserDefaults.standard.set(self.favoriteModels, forKey: "AIFavoriteModels")
        self.availableModels = self.favoriteModels
        loadAvailableModels()
    }
    
    /// Toggles a model inside the favorites list
    func toggleFavorite(_ model: String) {
        if favoriteModels.contains(model) {
            favoriteModels.removeAll { $0 == model }
        } else {
            favoriteModels.append(model)
        }
        UserDefaults.standard.set(favoriteModels, forKey: "AIFavoriteModels")
    }

    /// Queries installed CLI agents (opencode, codex, antigravity) in background to list available models
    func loadAvailableModels() {
        Task {
            // Ensure fresh detection of installed CLIs
            let (opencodePath, codexPath, antigravityPath) = await MainActor.run { () -> (String?, String?, String?) in
                self.checkCLIInstallations()
                return (self.getOpencodeBinaryPath(), self.getCodexBinaryPath(), self.getAntigravityBinaryPath())
            }
            
            async let opencodeTask: [String] = {
                guard let path = opencodePath else { return [] }
                return await self.fetchModelsFromCLI(path: path, args: ["models"])
            }()
            
            async let codexTask: [String] = {
                guard let path = codexPath else { return [] }
                return await self.fetchCodexDynamicModels(path: path)
            }()
            
            async let antigravityTask: [String] = {
                guard let path = antigravityPath else { return [] }
                return await self.fetchAntigravityDynamicModels(path: path)
            }()
            
            let (opencodeModels, codexModels, antigravityModels) = await (opencodeTask, codexTask, antigravityTask)
            
            var combinedModels: [String] = []
            
            for m in opencodeModels {
                let formatted = m.hasPrefix("opencode/") ? m : "opencode/\(m)"
                if !combinedModels.contains(formatted) {
                    combinedModels.append(formatted)
                }
            }
            
            for m in codexModels {
                let formatted = m.hasPrefix("codex/") ? m : "codex/\(m)"
                if !combinedModels.contains(formatted) {
                    combinedModels.append(formatted)
                }
            }
            
            for m in antigravityModels {
                let formatted = m.hasPrefix("antigravity/") ? m : "antigravity/\(m)"
                if !combinedModels.contains(formatted) {
                    combinedModels.append(formatted)
                }
            }
            
            await MainActor.run {
                self.availableModels = combinedModels
                if self.selectedModel.isEmpty || self.selectedModel.contains("Gemma") || self.selectedModel.contains("Local LLM") || self.selectedModel.contains("deepseek-v4-flash-free") {
                    if let firstFav = self.favoriteModels.first, !firstFav.isEmpty {
                        self.selectedModel = firstFav
                    } else if let first = combinedModels.first {
                        self.selectedModel = first
                    } else {
                        self.selectedModel = ""
                    }
                    UserDefaults.standard.set(self.selectedModel, forKey: "AISelectedModel")
                }
            }
        }
    }
    
    /// Cached CLI environment with full PATH — built once on first use, reused for every process launch
    private var _cliEnvironmentCache: [String: String]? = nil
    
    private func makeCLIEnvironment() -> [String: String] {
        if let cached = _cliEnvironmentCache { return cached }
        
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        
        // Resolve nvm active node version dynamically (avoids stale /current symlink)
        var nvmNodeBin = ""
        let nvmVersionsDir = NSString(string: "~/.nvm/versions/node").expandingTildeInPath
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsDir),
           let latest = versions.sorted().last {
            nvmNodeBin = "\(nvmVersionsDir)/\(latest)/bin"
        }
        
        var extraPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            NSString(string: "~/.npm-global/bin").expandingTildeInPath,
            NSString(string: "~/.cargo/bin").expandingTildeInPath,
            NSString(string: "~/.bun/bin").expandingTildeInPath,
            NSString(string: "~/.local/bin").expandingTildeInPath,
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        if !nvmNodeBin.isEmpty { extraPaths.insert(nvmNodeBin, at: 0) }
        
        var pathComponents = currentPath.components(separatedBy: ":").filter { !$0.isEmpty }
        for p in extraPaths where !pathComponents.contains(p) {
            pathComponents.insert(p, at: 0)
        }
        env["PATH"] = pathComponents.joined(separator: ":")
        _cliEnvironmentCache = env
        return env
    }
    
    private func fetchModelsFromCLI(path: String, args: [String]) async -> [String] {
        let capturedEnv = makeCLIEnvironment()
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                process.environment = capturedEnv
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let lines = output.components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .compactMap { line -> String? in
                                guard !line.isEmpty else { return nil }
                                let token = line.components(separatedBy: .whitespaces).first ?? ""
                                return (!token.isEmpty && (token.contains("/") || token.contains("-")) && !token.contains("...")) ? token : nil
                            }
                        continuation.resume(returning: lines)
                        return
                    }
                } catch {
                    NSLog("Failed to query models from \(path): \(error.localizedDescription)")
                }
                continuation.resume(returning: [])
            }
        }
    }
    
    /// Dynamically parses available/active models from Codex CLI output and user configuration (~/.codex/config.toml)
    private func fetchCodexDynamicModels(path: String) async -> [String] {
        var models = await fetchModelsFromCLI(path: path, args: ["models"])
        
        let configPath = NSString(string: "~/.codex/config.toml").expandingTildeInPath
        if let content = try? String(contentsOfFile: configPath, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("model =") || trimmed.hasPrefix("model=") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let rawModel = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                        if !rawModel.isEmpty && !models.contains(rawModel) {
                            models.append(rawModel)
                        }
                    }
                } else if trimmed.contains("gpt-") || trimmed.contains("o1") || trimmed.contains("o3") || trimmed.contains("codex-") {
                    let matches = trimmed.components(separatedBy: CharacterSet(charactersIn: " \"'=:,\n"))
                        .filter { $0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("codex-") }
                    for m in matches {
                        if !models.contains(m) {
                            models.append(m)
                        }
                    }
                }
            }
        }
        
        return models
    }
    
    /// Dynamically parses available models from Antigravity / Agy CLI output
    private func fetchAntigravityDynamicModels(path: String) async -> [String] {
        let capturedEnv = makeCLIEnvironment()
        let rawOutput: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = ["models"]
                process.environment = capturedEnv
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    NSLog("Failed to query antigravity models: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
        
        var models: [String] = []
        if let output = rawOutput {
            let rawLines = output.replacingOccurrences(of: "\r", with: "\n").components(separatedBy: .newlines)
            for line in rawLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if trimmed.contains("Fetching") || trimmed.contains("available models") || trimmed.hasPrefix("Usage:") {
                    continue
                }
                let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let firstToken = tokens.first {
                    if (firstToken.contains("-") || firstToken.contains("/")) && !firstToken.contains("...") {
                        if !models.contains(firstToken) {
                            models.append(firstToken)
                        }
                    }
                }
            }
        }
        
        // Built-in fallback list of standard Antigravity models if CLI query timed out or had no network
        if models.isEmpty {
            models = [
                "gemini-3.8-flash-high",
                "gemini-3.8-flash-medium",
                "gemini-3.8-flash-low",
                "gemini-3.7-flash-high",
                "gemini-3.7-flash-medium",
                "gemini-3.7-flash-low",
                "gemini-3.6-flash-high",
                "gemini-3.6-flash-medium",
                "gemini-3.6-flash-low",
                "gemini-3.1-pro-high",
                "gemini-3.1-pro-low",
                "claude-sonnet-4-6",
                "claude-opus-4-6-thinking",
                "gpt-oss-120b-medium"
            ]
        }
        
        return models
    }
    
    /// Runs `agy --output-format json -p /usage` and parses the exact decimal quota percentages and reset countdowns
    func fetchAgyUsage() {
        guard let binaryPath = getAntigravityBinaryPath() else {
            self.agyUsageError = "Antigravity CLI (agy) not found."
            return
        }
        
        self.isFetchingAgyUsage = true
        self.agyUsageError = nil
        
        Task.detached(priority: .userInitiated) {
            let capturedEnv = await self.makeCLIEnvironment()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = ["--output-format", "json", "-p", "/usage"]
            process.environment = capturedEnv
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            var output = ""
            var rawData = Data()
            do {
                try process.run()
                process.waitUntilExit()
                rawData = pipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: rawData, encoding: .utf8) ?? ""
            } catch {
                await MainActor.run {
                    self.isFetchingAgyUsage = false
                    self.agyUsageError = "Failed to run agy /usage: \(error.localizedDescription)"
                }
                return
            }
            
            var parsedGroups: [AgyUsageGroup] = []
            var flatQuotas: [AgyUsageQuota] = []
            
            // Try decoding structured JSON from agy
            struct AgyUsageJSONResponse: Decodable {
                struct Command: Decodable {
                    let name: String?
                    let data: UsageData?
                }
                struct UsageData: Decodable {
                    let description: String?
                    let groups: [UsageGroup]?
                }
                struct UsageGroup: Decodable {
                    let name: String
                    let description: String?
                    let buckets: [UsageBucket]?
                }
                struct UsageBucket: Decodable {
                    let id: String?
                    let name: String
                    let description: String?
                    let window: String?
                    let remaining_fraction: Double?
                    let reset_time: String?
                }
                let command: Command?
            }
            
            let isoFormatter = ISO8601DateFormatter()
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            
            if let decoded = try? JSONDecoder().decode(AgyUsageJSONResponse.self, from: rawData),
               let groups = decoded.command?.data?.groups, !groups.isEmpty {
                for g in groups {
                    var groupQuotas: [AgyUsageQuota] = []
                    let groupDesc = g.description ?? ""
                    for b in g.buckets ?? [] {
                        let fraction = max(0.0, min(1.0, b.remaining_fraction ?? 1.0))
                        let pctString = String(format: "%.2f%%", fraction * 100.0)
                        let intPct = Int(round(fraction * 100.0))
                        
                        var refreshText = "Quota available"
                        var formattedReset = ""
                        
                        if fraction >= 0.99999 {
                            refreshText = "Quota available"
                        } else if let resetStr = b.reset_time, !resetStr.isEmpty {
                            var parsedDate = isoFormatter.date(from: resetStr)
                            if parsedDate == nil {
                                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                parsedDate = isoFormatter.date(from: resetStr)
                            }
                            if let date = parsedDate {
                                let diff = date.timeIntervalSince(Date())
                                if diff <= 0 {
                                    refreshText = "Quota available"
                                } else {
                                    let totalMins = Int(diff) / 60
                                    let hours = totalMins / 60
                                    let mins = totalMins % 60
                                    if hours > 0 {
                                        refreshText = "Refreshes in \(hours)h \(mins)m"
                                    } else {
                                        refreshText = "Refreshes in \(mins)m"
                                    }
                                }
                                formattedReset = "Resets " + df.string(from: date)
                            } else {
                                refreshText = "Quota available"
                                formattedReset = resetStr
                            }
                        }
                        
                        let quota = AgyUsageQuota(
                            category: g.name,
                            limitType: b.name,
                            fraction: fraction,
                            percent: intPct,
                            percentageString: pctString,
                            refreshString: refreshText,
                            resetTime: formattedReset
                        )
                        groupQuotas.append(quota)
                        flatQuotas.append(quota)
                    }
                    parsedGroups.append(AgyUsageGroup(name: g.name, description: groupDesc, quotas: groupQuotas))
                }
            }
            
            // Fallback to text parsing if JSON didn't yield groups
            if parsedGroups.isEmpty {
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("Quota:"), trimmed.contains("%") else { continue }
                    
                    let parts = trimmed.components(separatedBy: "%")
                    guard parts.count >= 2 else { continue }
                    let left = parts[0]
                    let right = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let leftTokens = left.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard let pctToken = leftTokens.last, let floatVal = Double(pctToken) else { continue }
                    
                    let fullLabel = leftTokens.dropLast().joined(separator: " ")
                    var category = fullLabel
                    var limitType = "Limit"
                    
                    if fullLabel.contains("Weekly Limit Remaining") {
                        category = fullLabel.replacingOccurrences(of: "Weekly Limit Remaining", with: "").trimmingCharacters(in: .whitespaces)
                        limitType = "Weekly Limit Remaining"
                    } else if fullLabel.contains("Five Hour Limit Remaining") {
                        category = fullLabel.replacingOccurrences(of: "Five Hour Limit Remaining", with: "").trimmingCharacters(in: .whitespaces)
                        limitType = "Five Hour Limit Remaining"
                    } else if fullLabel.contains("Limit Remaining") {
                        category = fullLabel.replacingOccurrences(of: "Limit Remaining", with: "").trimmingCharacters(in: .whitespaces)
                        limitType = "Limit Remaining"
                    }
                    
                    let fraction = floatVal / 100.0
                    let pctString = String(format: "%.2f%%", floatVal)
                    var formattedReset = right
                    var refreshText = floatVal >= 99.999 ? "Quota available" : right
                    
                    if let date = isoFormatter.date(from: right) {
                        let diff = date.timeIntervalSince(Date())
                        if diff <= 0 {
                            refreshText = "Quota available"
                        } else {
                            let totalMins = Int(diff) / 60
                            let hours = totalMins / 60
                            let mins = totalMins % 60
                            if hours > 0 {
                                refreshText = "Refreshes in \(hours)h \(mins)m"
                            } else {
                                refreshText = "Refreshes in \(mins)m"
                            }
                        }
                        formattedReset = "Resets " + df.string(from: date)
                    }
                    
                    let q = AgyUsageQuota(
                        category: category,
                        limitType: limitType,
                        fraction: fraction,
                        percent: Int(round(floatVal)),
                        percentageString: pctString,
                        refreshString: refreshText,
                        resetTime: formattedReset
                    )
                    flatQuotas.append(q)
                }
            }
            
            let finalGroups = parsedGroups
            let finalQuotas = flatQuotas
            let finalOutput = output
            
            await MainActor.run {
                self.isFetchingAgyUsage = false
                if finalGroups.isEmpty && finalQuotas.isEmpty {
                    if finalOutput.contains("unexpected argument") || finalOutput.contains("Error") {
                        self.agyUsageError = finalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        self.agyUsageError = "No quota limits returned by agy."
                    }
                } else {
                    self.agyUsageGroups = finalGroups
                    self.agyUsageQuotas = finalQuotas
                    self.agyUsageLastFetched = Date()
                }
            }
        }
    }
    
    /// Persists a Tweak setting toggle and reloads preferences
    func setTweak(_ key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        loadTweakSettings()
    }
    
    // MARK: - Intent Methods
    
    /// Triggers a full storage and file scan asynchronously
    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        
        // Check for mo/mole installation
        checkMoleInstallation()
        // Check for CLI agent installations and reload available models
        checkCLIInstallations()
        loadAvailableModels()
        
        // Refresh agy quota if Antigravity CLI is installed
        if isAntigravityInstalled {
            fetchAgyUsage()
        }
        
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
    
    /// Active background processes for silent custom commands
    private var silentProcessMap: [UUID: Process] = [:]
    
    /// Adds a new terminal command and persists it
    func addCustomCommand(name: String, command: String, folder: String?, tag: String?, runSilent: Bool = false) {
        guard !name.isEmpty, !command.isEmpty else { return }
        let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderValue = cleanFolder?.isEmpty == true ? nil : cleanFolder
        let cleanTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagValue = cleanTag?.isEmpty == true ? nil : cleanTag
        let newCmd = TerminalCommand(id: UUID(), name: name, command: command, folder: folderValue, tag: tagValue, runSilent: runSilent)
        self.customCommands.append(newCmd)
        saveCustomCommands()
    }
    
    /// Updates an existing terminal command details and persists it
    func updateCustomCommand(id: UUID, name: String, command: String, folder: String?, tag: String?, runSilent: Bool = false) {
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
            customCommands[idx].runSilent = runSilent
            saveCustomCommands()
        }
    }
    
    /// Removes a custom command by ID
    func removeCustomCommand(id: UUID) {
        customCommands.removeAll { $0.id == id }
        saveCustomCommands()
    }
    
    /// Executes a custom command inside a temporary shell script in Terminal or silently in background
    func runCustomCommand(_ cmd: TerminalCommand) {
        // If configured to run in Silent Mode, execute in background via Process without opening Terminal
        if cmd.runSilent == true {
            if silentProcessMap[cmd.id] != nil { return } // Already running
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", cmd.command]
            process.environment = makeCLIEnvironment()
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            
            process.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.runningCommandIds.remove(cmd.id)
                    self?.silentProcessMap.removeValue(forKey: cmd.id)
                }
            }
            
            self.silentProcessMap[cmd.id] = process
            self.runningCommandIds.insert(cmd.id)
            
            do {
                try process.run()
            } catch {
                self.runningCommandIds.remove(cmd.id)
                self.silentProcessMap.removeValue(forKey: cmd.id)
                NSLog("Failed to run silent command \(cmd.name): \(error.localizedDescription)")
            }
            return
        }
        
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
    
    /// Launches an interactive macOS Terminal window to update Mac ASC via Homebrew
    func runUpdateInTerminal() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("macasc_update.command")
        
        let scriptContent = """
        #!/bin/bash
        clear
        echo "🚀 ======================================="
        echo "   Updating Mac ASC via Homebrew"
        echo "   ======================================="
        echo ""
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        
        if ! command -v brew &> /dev/null; then
            echo "❌ Error: Homebrew ('brew') was not found on your system."
            echo "Please install Homebrew from https://brew.sh to use this updater."
            echo ""
            exec $SHELL
            exit 1
        fi
        
        echo "📦 Step 1/3: Tapping repository..."
        brew tap Rian445/MacAsc https://github.com/Rian445/MacAsc.git
        echo ""
        
        echo "🔐 Step 2/3: Trusting tap..."
        brew trust rian445/macasc 2>/dev/null || true
        echo ""
        
        echo "⚡ Step 3/3: Installing / Upgrading Mac ASC Cask..."
        brew upgrade --cask --force macasc 2>/dev/null || brew install --cask --force macasc || brew reinstall --cask macasc
        echo ""
        
        echo "✅ ======================================="
        echo "   Mac ASC update completed!"
        echo "   You can now launch the updated app."
        echo "   ======================================="
        echo ""
        exec $SHELL
        """
        
        do {
            try scriptContent.write(to: fileURL, atomically: true, encoding: .utf8)
            let attributes = [FileAttributeKey.posixPermissions: NSNumber(value: 0o755)]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
            NSWorkspace.shared.open(fileURL)
        } catch {
            NSLog("Failed to launch update script in Terminal: \(error.localizedDescription)")
        }
    }
    
    /// Scans for and terminates a specific terminal command by its unique ID using SIGINT (Ctrl+C) 4 times
    func stopCustomCommand(id: UUID) {
        // Remove from running IDs immediately
        self.runningCommandIds.remove(id)
        
        // If running as a silent background process, terminate it directly
        if let proc = silentProcessMap[id] {
            if proc.isRunning {
                proc.terminate()
            }
            silentProcessMap.removeValue(forKey: id)
        }
        
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
        
        for (_, proc) in silentProcessMap {
            if proc.isRunning {
                proc.terminate()
            }
        }
        silentProcessMap.removeAll()
        
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
        let activeSilentIds = Set(self.silentProcessMap.filter { $0.value.isRunning }.keys)
        
        Task {
            // Run the blocking process execution on a global background queue
            let activeTerminalIds = await withCheckedContinuation { continuation in
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
            await MainActor.run {
                self.runningCommandIds = activeTerminalIds.union(activeSilentIds)
            }
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
            
            let chatAiData = UserDefaults.standard.data(forKey: "ChatThreads")
            let computedChatAiSize = Int64(chatAiData?.count ?? 0)
            
            let computedGeneralSettingsSize = max(0, computedSettingsSize - computedCommandsSize - computedNotesSize - computedChatAiSize)
            
            // Create immutable copies to capture safely in Sendable closure
            let finalBundleSize = computedBundleSize
            let finalSettingsSize = computedSettingsSize
            let finalCommandsSize = computedCommandsSize
            let finalNotesSize = computedNotesSize
            let finalChatAiSize = computedChatAiSize
            let finalGeneralSettingsSize = computedGeneralSettingsSize
            
            // Post update back to the main thread
            await MainActor.run {
                self.appBundleSize = finalBundleSize
                self.appSettingsSize = finalSettingsSize
                self.appCommandsSize = finalCommandsSize
                self.appNotesSize = finalNotesSize
                self.appChatAiSize = finalChatAiSize
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
    func addQuickNote(title: String, content: String, folder: String?) {
        guard !title.isEmpty, !content.isEmpty else { return }
        let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderValue = cleanFolder?.isEmpty == true ? nil : cleanFolder
        let newNote = QuickNote(id: UUID(), title: title, content: content, dateCreated: Date(), folder: folderValue)
        self.quickNotes.append(newNote)
        saveQuickNotes()
    }
    
    /// Updates an existing quick note details and persists it
    func updateQuickNote(id: UUID, title: String, content: String, folder: String?) {
        guard !title.isEmpty, !content.isEmpty else { return }
        if let idx = quickNotes.firstIndex(where: { $0.id == id }) {
            let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderValue = cleanFolder?.isEmpty == true ? nil : cleanFolder
            quickNotes[idx].title = title
            quickNotes[idx].content = content
            quickNotes[idx].folder = folderValue
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
    
    /// Checks all supported CLI agents (opencode, codex, antigravity) installation status and remaps paths
    func checkCLIInstallations() {
        // Invalidate all cached paths and environment so refresh forces a full re-scan
        self.cachedOpencodePath = nil
        self.cachedCodexPath = nil
        self.cachedAntigravityPath = nil
        self._cliEnvironmentCache = nil
        
        self.isOpencodeInstalled = (getOpencodeBinaryPath() != nil)
        self.isCodexInstalled = (getCodexBinaryPath() != nil)
        self.isAntigravityInstalled = (getAntigravityBinaryPath() != nil)
    }
    
    /// Backward compatible helper
    func checkOpencodeInstallation() {
        checkCLIInstallations()
    }
    
    /// Universal binary path resolver that checks standard paths and falls back to dynamic shell environment lookup
    private func findBinaryPath(names: [String], candidatePaths: [String]) -> String? {
        let fileManager = FileManager.default
        
        // 1. Check known candidate paths first (fastest)
        for path in candidatePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if fileManager.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }
        
        // 2. Dynamic ZSH shell fallback: query `which <name>` using user's environment PATH
        for name in names {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "which \(name)"]
            process.environment = self.makeCLIEnvironment()
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty, fileManager.fileExists(atPath: output) {
                    return output
                }
            } catch {
                // Ignore shell lookup errors
            }
        }
        
        return nil
    }
    
    /// Finds the location of the opencode binary on any Mac (cached for instant performance)
    func getOpencodeBinaryPath() -> String? {
        if let cached = cachedOpencodePath, FileManager.default.fileExists(atPath: cached) {
            return cached
        }
        let path = findBinaryPath(
            names: ["opencode"],
            candidatePaths: [
                "/opt/homebrew/bin/opencode",
                "/usr/local/bin/opencode",
                "~/.local/bin/opencode",
                "~/.nvm/versions/node/current/bin/opencode",
                "~/.bun/bin/opencode"
            ]
        )
        cachedOpencodePath = path
        return path
    }
    
    /// Finds the location of the codex binary on any Mac (cached for instant performance)
    func getCodexBinaryPath() -> String? {
        if let cached = cachedCodexPath, FileManager.default.fileExists(atPath: cached) {
            return cached
        }
        let path = findBinaryPath(
            names: ["codex"],
            candidatePaths: [
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex",
                "~/.npm-global/bin/codex",
                "~/.cargo/bin/codex",
                "~/.local/bin/codex",
                "~/.nvm/versions/node/current/bin/codex",
                "~/.bun/bin/codex"
            ]
        )
        cachedCodexPath = path
        return path
    }
    
    /// Finds the location of the antigravity binary on any Mac (cached for instant performance)
    func getAntigravityBinaryPath() -> String? {
        if let cached = cachedAntigravityPath, FileManager.default.fileExists(atPath: cached) {
            return cached
        }
        let path = findBinaryPath(
            names: ["agy", "antigravity"],
            candidatePaths: [
                "/opt/homebrew/bin/agy",
                "/usr/local/bin/agy",
                "/opt/homebrew/bin/antigravity",
                "/usr/local/bin/antigravity",
                "~/.gemini/bin/agy",
                "~/.gemini/bin/antigravity",
                "~/.antigravity/bin/antigravity",
                "~/.local/bin/agy",
                "~/.local/bin/antigravity"
            ]
        )
        cachedAntigravityPath = path
        return path
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
        
        self.allowAiSystemActions = UserDefaults.standard.bool(forKey: "AIAllowSystemActions")
        
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
                    attachedDirectory: nil,
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
        UserDefaults.standard.set(allowAiSystemActions, forKey: "AIAllowSystemActions")
    }
    
    /// Updates the selected model and persists it to thread and global preferences
    func changeSelectedModel(_ model: String) {
        self.selectedModel = model
        UserDefaults.standard.set(model, forKey: "AISelectedModel")
        if let threadId = selectedThreadId,
           let idx = chatThreads.firstIndex(where: { $0.id == threadId }) {
            self.chatThreads[idx].selectedModel = model
            saveChatHistory()
        }
    }
    
    /// Creates a new chat thread and selects it
    func createNewChatThread() {
        // If there is already an empty thread, select it instead of creating a duplicate
        if let existingEmpty = chatThreads.first(where: { $0.messages.isEmpty && $0.title == "New Chat" }) {
            self.selectedThreadId = existingEmpty.id
            if let threadModel = existingEmpty.selectedModel, !threadModel.isEmpty {
                self.selectedModel = threadModel
            }
            saveChatHistory()
            return
        }
        
        let newThread = ChatThread(
            id: UUID(),
            title: "New Chat",
            activeSessionId: nil,
            attachedDirectory: nil,
            attachedDirectories: nil,
            selectedModel: self.selectedModel.isEmpty ? "MacASC Local LLM" : self.selectedModel,
            messages: [],
            dateCreated: Date()
        )
        self.chatThreads.append(newThread)
        self.selectedThreadId = newThread.id
        saveChatHistory()
    }
    
    /// Updates details (title and folder) of a chat thread
    func updateChatThread(id: UUID, title: String, folder: String?) {
        guard !title.isEmpty else { return }
        if let idx = chatThreads.firstIndex(where: { $0.id == id }) {
            chatThreads[idx].title = title
            let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
            chatThreads[idx].folder = cleanFolder?.isEmpty == true ? nil : cleanFolder
            saveChatHistory()
        }
    }
    
    /// Selects an existing chat thread
    func selectChatThread(id: UUID) {
        stopAiMessageQuery()
        self.selectedThreadId = id
        if let idx = chatThreads.firstIndex(where: { $0.id == id }),
           let threadModel = chatThreads[idx].selectedModel, !threadModel.isEmpty {
            self.selectedModel = threadModel
        }
        saveChatHistory()
    }
    
    /// Deletes a chat thread by ID and removes its server-side session from the provider
    func deleteChatThread(id: UUID) {
        // Capture session info before removing the thread
        if let thread = chatThreads.first(where: { $0.id == id }),
           let sessionId = thread.activeSessionId, !sessionId.isEmpty {
            let model = thread.selectedModel ?? selectedModel
            deleteRemoteSession(sessionId: sessionId, model: model)
        }
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
    
    /// Clears messages in the active chat thread and removes its server-side session
    func clearChatHistory() {
        stopAiMessageQuery()
        if let threadId = selectedThreadId,
           let idx = chatThreads.firstIndex(where: { $0.id == threadId }) {
            // Delete the remote session before clearing
            if let sessionId = chatThreads[idx].activeSessionId, !sessionId.isEmpty {
                let model = chatThreads[idx].selectedModel ?? selectedModel
                deleteRemoteSession(sessionId: sessionId, model: model)
            }
            self.chatThreads[idx].messages.removeAll()
            self.chatThreads[idx].activeSessionId = nil
            self.chatThreads[idx].title = "New Chat"
            saveChatHistory()
        }
    }
    
    /// Fires a background process to delete a remote session from the provider CLI
    private func deleteRemoteSession(sessionId: String, model: String) {
        Task.detached(priority: .background) {
            let cliType: String
            let binaryPath: String?
            
            if model.hasPrefix("codex/") || model == "codex" {
                cliType = "codex"
                binaryPath = await self.getCodexBinaryPath()
            } else if model.hasPrefix("antigravity/") || model == "antigravity"
                        || model.hasPrefix("agy/") || model == "agy" {
                cliType = "antigravity"
                binaryPath = await self.getAntigravityBinaryPath()
            } else if model == "MacASC Local LLM" {
                return // Local LLM has no remote session to delete
            } else {
                cliType = "opencode"
                binaryPath = await self.getOpencodeBinaryPath()
            }
            
            guard let path = binaryPath else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.environment = await self.makeCLIEnvironment()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            
            // Each CLI has its own session deletion command
            switch cliType {
            case "opencode":
                process.arguments = ["session", "delete", sessionId]
            case "antigravity":
                // agy does not expose a delete command; conversations expire on their own
                return
            case "codex":
                // codex does not expose a session delete command; sessions expire on their own
                return
            default:
                return
            }
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                NSLog("Failed to delete remote session \(sessionId): \(error.localizedDescription)")
            }
        }
    }
    
    /// Sends a query message to the AI (opencode binary) in the background
    func sendChatMessage(_ text: String) {
        guard !text.isEmpty, let threadId = selectedThreadId else { return }
        
        // Terminate any active process first to avoid orphan/overlapping tasks
        if activeAiProcess != nil {
            stopAiMessageQuery()
        }
        
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
        
        executeAICLIInBackground(text: text, threadId: threadId)
    }
    
    /// Executes the AI query using the appropriate CLI agent (opencode, codex, antigravity) in the background
    private func executeAICLIInBackground(text: String, threadId: UUID) {
        Task.detached(priority: .userInitiated) {
            let model = await self.selectedModel
            
            var binaryPath: String? = nil
            var cliType: String = "opencode"
            var targetModelArg = model
            
            if model.hasPrefix("codex/") || model == "codex" {
                cliType = "codex"
                binaryPath = await self.getCodexBinaryPath()
                targetModelArg = model.replacingOccurrences(of: "codex/", with: "")
            } else if model.hasPrefix("antigravity/") || model == "antigravity" || model.hasPrefix("agy/") || model == "agy" {
                cliType = "antigravity"
                binaryPath = await self.getAntigravityBinaryPath()
                targetModelArg = model.replacingOccurrences(of: "antigravity/", with: "").replacingOccurrences(of: "agy/", with: "")
            } else {
                cliType = "opencode"
                binaryPath = await self.getOpencodeBinaryPath()
                targetModelArg = model
            }
            
            let capturedCliType = cliType
            guard let validBinary = binaryPath else {
                await MainActor.run {
                    if let threadIdx = self.chatThreads.firstIndex(where: { $0.id == threadId }) {
                        let installCmd = capturedCliType == "codex" ? "npm i -g @openai/codex-cli" :
                                        (capturedCliType == "antigravity" ? "curl -sSL https://antigravity.ai/install.sh" : "brew install opencode")
                        let errorMessage = ChatMessage(
                            id: UUID(),
                            text: "Error: Could not find '\(capturedCliType)' binary. Please install '\(capturedCliType)' by running:\n\(installCmd)",
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
            process.executableURL = URL(fileURLWithPath: validBinary)
            process.environment = await self.makeCLIEnvironment()
            
            // Prepend context info to query if attached to thread
            var textToSend = text
            let attachedDir = await self.chatThreads.first(where: { $0.id == threadId })?.attachedDirectory
            if let path = attachedDir {
                textToSend = "Context Path: \(path)\n\n\(text)"
            }
            
            var arguments: [String] = []
            let allowActions = await self.allowAiSystemActions
            let threadSessionId = await self.chatThreads.first(where: { $0.id == threadId })?.activeSessionId
            
            if cliType == "codex" {
                // codex exec reads the prompt from stdin.
                // Use the thread's attached directory as the working dir if available (may be a git repo),
                // otherwise fall back to the user's home directory. Always pass --skip-git-repo-check
                // so codex doesn't refuse to run when outside a trusted repo.
                let codexWorkDir: String
                if let dir = attachedDir {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: dir, isDirectory: &isDirectory), isDirectory.boolValue {
                        codexWorkDir = dir
                    } else {
                        codexWorkDir = URL(fileURLWithPath: dir).deletingLastPathComponent().path
                    }
                } else {
                    codexWorkDir = FileManager.default.homeDirectoryForCurrentUser.path
                }
                arguments = ["exec", "-C", codexWorkDir, "--skip-git-repo-check"]
                if !targetModelArg.isEmpty && targetModelArg != "codex" {
                    arguments.append("-m")
                    arguments.append(targetModelArg)
                }
                if allowActions {
                    arguments.append("--dangerously-bypass-approvals-and-sandbox")
                }
            } else if cliType == "antigravity" {
                arguments = ["-p", textToSend]
                if !targetModelArg.isEmpty && targetModelArg != "antigravity" && targetModelArg != "agy" {
                    arguments.append("--model")
                    arguments.append(targetModelArg)
                }
                if allowActions {
                    arguments.append("--dangerously-skip-permissions")
                }
                if let sessionId = threadSessionId, !sessionId.isEmpty {
                    arguments.append("--conversation=\(sessionId)")
                }
            } else {
                arguments = ["run", textToSend, "--dir", "/tmp"]
                if !targetModelArg.isEmpty && targetModelArg != "opencode" {
                    arguments.append("-m")
                    arguments.append(targetModelArg)
                }
                if allowActions {
                    arguments.append("--auto")
                }
                if let sessionId = threadSessionId, !sessionId.isEmpty {
                    arguments.append("--session")
                    arguments.append(sessionId)
                } else {
                    arguments.append("--print-logs")
                }
            }
            
            process.arguments = arguments
            
            // For codex: pipe the prompt text via stdin since codex exec reads from stdin
            // For other CLIs: use null device since prompt is passed as a CLI argument
            if cliType == "codex" {
                let stdinPipe = Pipe()
                process.standardInput = stdinPipe
                let promptData = textToSend.data(using: .utf8) ?? Data()
                stdinPipe.fileHandleForWriting.write(promptData)
                stdinPipe.fileHandleForWriting.closeFile()
            } else {
                process.standardInput = FileHandle.nullDevice
            }
            
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
                let baseCleanedOutput = await self.cleanOpencodeOutput(rawOutput)
                
                await MainActor.run {
                    // Check if this was the active process we expected (not cancelled)
                    if self.activeAiProcess === process {
                        if let threadIdx = self.chatThreads.firstIndex(where: { $0.id == threadId }) {
                            var textToDisplay = baseCleanedOutput
                            
                            // Check if opencode or CLI returned a server/session error
                            let isServerError = rawOutput.contains("UnknownError") || rawOutput.contains("Unexpected server error")
                            if isServerError {
                                // Clear broken session ID so subsequent retries start fresh
                                self.chatThreads[threadIdx].activeSessionId = nil
                                
                                // Extract error ref code if present
                                var errorRef = ""
                                if let refRange = rawOutput.range(of: "\"ref\":\\s*\"([^\"]+)\"", options: .regularExpression) {
                                    let match = String(rawOutput[refRange])
                                    errorRef = match.replacingOccurrences(of: "\"ref\":", with: "").replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
                                }
                                let refNotice = errorRef.isEmpty ? "" : " (Ref: \(errorRef))"
                                textToDisplay = "⚠️ Opencode Server Error: The model provider returned a temporary server error\(refNotice). Your session has been reset — please try sending your message again."
                            } else {
                                // Extract or update session ID for this thread
                                if capturedCliType == "antigravity" {
                                    if let match = rawOutput.range(of: "--conversation=([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|[a-zA-Z0-9_-]+)", options: .regularExpression) {
                                        let fullMatch = String(rawOutput[match])
                                        let extracted = fullMatch.replacingOccurrences(of: "--conversation=", with: "")
                                        self.chatThreads[threadIdx].activeSessionId = extracted
                                    } else if let uuidRange = rawOutput.range(of: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", options: .regularExpression) {
                                        let matchedId = String(rawOutput[uuidRange])
                                        self.chatThreads[threadIdx].activeSessionId = matchedId
                                    }
                                } else if capturedCliType == "codex" {
                                    if let sessionRange = rawOutput.range(of: "ses_[a-zA-Z0-9]+", options: .regularExpression) {
                                        let matchedId = String(rawOutput[sessionRange])
                                        self.chatThreads[threadIdx].activeSessionId = matchedId
                                    } else if let uuidRange = rawOutput.range(of: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", options: .regularExpression) {
                                        let matchedId = String(rawOutput[uuidRange])
                                        self.chatThreads[threadIdx].activeSessionId = matchedId
                                    }
                                } else {
                                    if let sessionRange = rawOutput.range(of: "ses_[a-zA-Z0-9]+", options: .regularExpression) {
                                        let matchedId = String(rawOutput[sessionRange])
                                        self.chatThreads[threadIdx].activeSessionId = matchedId
                                    }
                                }
                            }
                            
                            let aiMessage = ChatMessage(id: UUID(), text: textToDisplay, isUser: false, timestamp: Date())
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
    
    /// Launches macOS Terminal and resumes the active thread's session ID in an interactive session
    func openActiveThreadInTerminal() {
        let model = selectedModel
        var binaryPath: String? = nil
        var cliName = "opencode"
        var cleanModelName = model
        
        if model.hasPrefix("codex/") || model == "codex" {
            binaryPath = getCodexBinaryPath()
            cliName = "codex"
            cleanModelName = model.replacingOccurrences(of: "codex/", with: "")
        } else if model.hasPrefix("antigravity/") || model == "antigravity" || model.hasPrefix("agy/") || model == "agy" {
            binaryPath = getAntigravityBinaryPath()
            cliName = "antigravity"
            cleanModelName = model.replacingOccurrences(of: "antigravity/", with: "").replacingOccurrences(of: "agy/", with: "")
        } else {
            binaryPath = getOpencodeBinaryPath()
            cliName = "opencode"
            cleanModelName = model
        }
        
        guard let validBinary = binaryPath else { return }
        
        var execCommand = "\"\(validBinary)\""
        var sessionDesc = "New Session"
        var dirDesc = "None"
        
        // 1. Attached Directory & cd location formatting
        var cdDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let attachments: [String]
        if let threadId = selectedThreadId,
           let thread = chatThreads.first(where: { $0.id == threadId }) {
            attachments = thread.allAttachments
        } else {
            attachments = []
        }
        
        if !attachments.isEmpty {
            dirDesc = attachments.joined(separator: ", ")
            
            // Primary cd directory is the first attached path (or its parent directory if it's a file)
            if let firstPath = attachments.first {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: firstPath, isDirectory: &isDir) && isDir.boolValue {
                    cdDirectory = firstPath
                } else {
                    cdDirectory = URL(fileURLWithPath: firstPath).deletingLastPathComponent().path
                }
            }
            
            if cliName == "antigravity" {
                for path in attachments {
                    var targetPath = path
                    var isDir: ObjCBool = false
                    if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) || !isDir.boolValue {
                        targetPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
                    }
                    execCommand += " --add-dir \"\(targetPath)\""
                }
            } else if cliName == "codex" {
                execCommand += " -C \"\(cdDirectory)\""
            }
        } else if cliName == "codex" {
            execCommand += " -C \"\(cdDirectory)\""
        }
        
        // 2. Session ID flag formatting
        if let threadId = selectedThreadId,
           let thread = chatThreads.first(where: { $0.id == threadId }),
           let sessionId = thread.activeSessionId, !sessionId.isEmpty {
            sessionDesc = sessionId
            if cliName == "antigravity" {
                execCommand += " --conversation=\(sessionId)"
            } else if cliName == "codex" {
                execCommand += " resume \(sessionId)"
            } else {
                execCommand += " --session \(sessionId)"
            }
        } else {
            if cliName == "antigravity" {
                execCommand += " --continue"
            } else if cliName == "opencode" {
                execCommand += " --continue"
            }
        }
        
        // 3. Model flag formatting
        if !cleanModelName.isEmpty && cleanModelName != cliName {
            if cliName == "antigravity" {
                execCommand += " --model \(cleanModelName)"
            } else {
                execCommand += " -m \(cleanModelName)"
            }
        }
        
        // 4. Auto-approve permissions flag if enabled
        if allowAiSystemActions {
            if cliName == "codex" {
                execCommand += " --dangerously-bypass-approvals-and-sandbox"
            } else if cliName == "antigravity" {
                execCommand += " --dangerously-skip-permissions"
            } else if cliName == "opencode" {
                execCommand += " --auto"
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("resume_\(cliName)_session.command")
        
        let scriptContent = """
        #!/bin/bash
        clear
        echo "=== Resuming Mac ASC AI (\(cliName)) Session in Terminal ==="
        echo "Session ID: \(sessionDesc)"
        echo "Attached Dir: \(dirDesc)"
        echo "Selected Model: \(cleanModelName.isEmpty ? "Default" : cleanModelName)"
        echo "================================================="
        cd "\(cdDirectory)"
        \(execCommand)
        exec $SHELL
        """
        
        do {
            try scriptContent.write(to: fileURL, atomically: true, encoding: .utf8)
            let attributes = [FileAttributeKey.posixPermissions: NSNumber(value: 0o755)]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
            NSWorkspace.shared.open(fileURL)
        } catch {
            NSLog("Failed to launch \(cliName) in Terminal: \(error.localizedDescription)")
        }
    }
    
    /// Associates a file or directory path with the active chat thread
    func attachDirectoryToActiveThread(_ path: String) {
        guard let threadId = selectedThreadId,
              let idx = chatThreads.firstIndex(where: { $0.id == threadId }) else { return }
        var current = self.chatThreads[idx].allAttachments
        if !current.contains(path) {
            current.append(path)
        }
        self.chatThreads[idx].attachedDirectories = current
        self.chatThreads[idx].attachedDirectory = current.joined(separator: ", ")
        saveChatHistory()
    }
    
    /// Attaches multiple file or directory paths to the active chat thread
    func attachDirectoriesToActiveThread(_ paths: [String]) {
        guard let threadId = selectedThreadId,
              let idx = chatThreads.firstIndex(where: { $0.id == threadId }) else { return }
        var current = self.chatThreads[idx].allAttachments
        for path in paths {
            if !current.contains(path) {
                current.append(path)
            }
        }
        self.chatThreads[idx].attachedDirectories = current
        self.chatThreads[idx].attachedDirectory = current.joined(separator: ", ")
        saveChatHistory()
    }
    
    /// Removes a specific file or directory path from the active chat thread's attachments
    func removeSpecificAttachmentFromActiveThread(_ path: String) {
        guard let threadId = selectedThreadId,
              let idx = chatThreads.firstIndex(where: { $0.id == threadId }) else { return }
        var current = self.chatThreads[idx].allAttachments
        current.removeAll { $0 == path }
        self.chatThreads[idx].attachedDirectories = current.isEmpty ? nil : current
        self.chatThreads[idx].attachedDirectory = current.isEmpty ? nil : current.joined(separator: ", ")
        saveChatHistory()
    }
    
    /// Clears all associated directory paths from the active chat thread
    func detachDirectoryFromActiveThread() {
        guard let threadId = selectedThreadId,
              let idx = chatThreads.firstIndex(where: { $0.id == threadId }) else { return }
        self.chatThreads[idx].attachedDirectories = nil
        self.chatThreads[idx].attachedDirectory = nil
        saveChatHistory()
    }
    
    /// Triggers standard picker panel to attach files or directories manually
    func selectDirectoryForActiveThread() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Files or Folders for AI Context"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = true
        
        if openPanel.runModal() == .OK {
            let paths = openPanel.urls.map { $0.path }
            if !paths.isEmpty {
                attachDirectoriesToActiveThread(paths)
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
    
    /// Filters and cleans the TUI/progress output from opencode/codex/antigravity stdout
    private func cleanOpencodeOutput(_ raw: String) -> String {
        var cleaned = raw
        
        // 1. Strip ESC-prefixed ANSI sequences
        if let escRegex = try? NSRegularExpression(pattern: "[\u{001B}\u{009B}][\\[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]", options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = escRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // 2. Strip raw bracket-style sequences (e.g. "[0m", "[?25h" that lost their ESC byte)
        if let bracketRegex = try? NSRegularExpression(pattern: "\\[\\??[0-9;]*[a-zA-Z]", options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = bracketRegex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // 3. Role-aware line-by-line filtering
        //
        // Codex output structure after the header block:
        //   user
        //   <prompt sent by user>   ← SKIP — this is what we sent, not the AI response
        //
        //   codex
        //   <AI response>           ← KEEP
        //   tokens used             ← STOP — everything below is metadata + duplicate
        //   12,180
        //   <AI response again>
        
        let lines = cleaned.components(separatedBy: .newlines)
        var filteredLines: [String] = []
        var skipHeader = false        // true while inside the '--------' banner block
        var inUserSection = false     // true while reading the echoed user prompt lines
        var inCodexSection = false    // true while reading the actual AI response lines
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip opencode build / log lines
            if trimmed.hasPrefix("> build ·") || trimmed.hasPrefix("> build") || trimmed.hasPrefix("timestamp=") {
                continue
            }
            
            // Toggle skip inside the codex banner block (between '--------' delimiters)
            if trimmed == "--------" {
                skipHeader.toggle()
                continue
            }
            if skipHeader { continue }
            
            // Stop at "tokens used" — codex duplicates the response below this line
            if trimmed == "tokens used" { break }
            
            // Skip meta lines that appear before/outside the banner
            if trimmed.hasPrefix("Reading prompt from stdin")
                || trimmed.hasPrefix("OpenAI Codex v")
                || trimmed.hasPrefix("session id:")
                || trimmed.hasPrefix("workdir:")
                || trimmed.hasPrefix("model:")
                || trimmed.hasPrefix("provider:")
                || trimmed.hasPrefix("approval:")
                || trimmed.hasPrefix("sandbox:")
                || trimmed.hasPrefix("reasoning effort:")
                || trimmed.hasPrefix("reasoning summaries:") {
                continue
            }
            
            // Detect role section transitions
            if trimmed == "user" {
                inUserSection = true
                inCodexSection = false
                continue
            }
            if trimmed == "codex" {
                inUserSection = false
                inCodexSection = true
                continue
            }
            
            // Skip lines that belong to the echoed user prompt section
            if inUserSection { continue }
            
            // Collect lines only when we are inside the codex response section
            if inCodexSection {
                filteredLines.append(line)
            }
        }
        
        // If no role sections found (opencode / antigravity output), use all non-filtered lines
        if !inCodexSection && filteredLines.isEmpty {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("> build ·") || trimmed.hasPrefix("> build") || trimmed.hasPrefix("timestamp=") { continue }
                filteredLines.append(line)
            }
        }
        
        let joined = filteredLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "No output." : joined
    }
    
    // MARK: - Settings Backup & Restore Utility
    
    private let backupKeys = [
        "TweakDiskInsight",
        "TweakCustomCommands",
        "TweakQuickNote",
        "TweakChatWithAi",
        "TweakScreenRecorder",
        "DashboardTabOrder",
        "TabKeyboardShortcuts",
        "CustomCommandFolderOrder",
        "QuickNoteFolderOrder",
        "PinnedFolders",
        "CustomCommands",
        "QuickNotes",
        "AIChatThreads",
        "AISelectedThreadId",
        "AISelectedModel",
        "AIFavoriteModels",
        "AIAllowSystemActions",
        "CachedStorageBreakdown",
        "ScreenRecordResolution",
        "ScreenRecordCaptureMode",
        "ScreenRecordSavePath",
        "ScreenRecordMicEnabled",
        "ScreenRecordFps",
        "ScreenRecordQuality",
        "SelectedLogo",
        "SelectedRecordLogo",
        "SavedTimeEvents",
        "TimeEventFolderOrder",
        "TweakTimeTracker"
    ]
    
    /// Exports all user settings, tab sorting order, folder sorting orders, pinned folders, commands, notes, tweaks, and AI history to a JSON file
    func backupUserSettings() {
        var exportDict: [String: String] = [:]
        
        for key in backupKeys {
            if let data = UserDefaults.standard.data(forKey: key) {
                exportDict[key] = "DATA:" + data.base64EncodedString()
            } else if let intArr = UserDefaults.standard.array(forKey: key) as? [Int] {
                if let encoded = try? JSONEncoder().encode(intArr) {
                    exportDict[key] = "INTARR:" + encoded.base64EncodedString()
                }
            } else if let stringArray = UserDefaults.standard.stringArray(forKey: key) {
                if let encoded = try? JSONEncoder().encode(stringArray) {
                    exportDict[key] = "STRARR:" + encoded.base64EncodedString()
                }
            } else if let stringVal = UserDefaults.standard.string(forKey: key) {
                if let strData = stringVal.data(using: .utf8) {
                    exportDict[key] = "STR:" + strData.base64EncodedString()
                }
            } else if let boolVal = UserDefaults.standard.object(forKey: key) as? Bool {
                exportDict[key] = "BOOL:" + (boolVal ? "true" : "false")
            } else if let obj = UserDefaults.standard.object(forKey: key) {
                if let propertyList = try? PropertyListSerialization.data(fromPropertyList: obj, format: .binary, options: 0) {
                    exportDict[key] = "PLIST:" + propertyList.base64EncodedString()
                }
            }
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Settings Backup"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "macasc_backup.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(exportDict)
                try jsonData.write(to: url)
            } catch {
                NSLog("Failed to write settings backup: \(error.localizedDescription)")
            }
        }
    }
    
    /// Imports a JSON settings backup file, decoding and updating Preferences, tab ordering, folder ordering, and UI state
    func restoreUserSettings() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Settings Backup"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let importDict = try decoder.decode([String: String].self, from: data)
                
                for (key, val) in importDict {
                    if val.hasPrefix("BOOL:") {
                        let boolStr = String(val.dropFirst(5))
                        UserDefaults.standard.set(boolStr == "true", forKey: key)
                    } else if val.hasPrefix("STR:") {
                        let base64Str = String(val.dropFirst(4))
                        if let decodedData = Data(base64Encoded: base64Str),
                           let strVal = String(data: decodedData, encoding: .utf8) {
                            UserDefaults.standard.set(strVal, forKey: key)
                        }
                    } else if val.hasPrefix("INTARR:") {
                        let base64Str = String(val.dropFirst(7))
                        if let decodedData = Data(base64Encoded: base64Str),
                           let intArr = try? JSONDecoder().decode([Int].self, from: decodedData) {
                            UserDefaults.standard.set(intArr, forKey: key)
                        }
                    } else if val.hasPrefix("STRARR:") {
                        let base64Str = String(val.dropFirst(7))
                        if let decodedData = Data(base64Encoded: base64Str),
                           let strArr = try? JSONDecoder().decode([String].self, from: decodedData) {
                            UserDefaults.standard.set(strArr, forKey: key)
                        }
                    } else if val.hasPrefix("DATA:") {
                        let base64Str = String(val.dropFirst(5))
                        if let decodedData = Data(base64Encoded: base64Str) {
                            UserDefaults.standard.set(decodedData, forKey: key)
                        }
                    } else if val.hasPrefix("PLIST:") {
                        let base64Str = String(val.dropFirst(6))
                        if let decodedData = Data(base64Encoded: base64Str),
                           let plistObj = try? PropertyListSerialization.propertyList(from: decodedData, options: [], format: nil) {
                            UserDefaults.standard.set(plistObj, forKey: key)
                        }
                    } else {
                        if let decodedData = Data(base64Encoded: val) {
                            UserDefaults.standard.set(decodedData, forKey: key)
                        }
                    }
                }
                
                // Reload preferences, tab orders, folder orders, and cache into memory
                loadTweakSettings()
                loadSelectedModel()
                loadPinnedFolders()
                loadCustomCommands()
                loadQuickNotes()
                loadChatHistory()
                
                // Signal UI refresh
                self.objectWillChange.send()
                
            } catch {
                NSLog("Failed to restore settings backup: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Screen Recorder Methods
    
    func loadScreenRecorderPreferences() {
        self.enableScreenRecorder = UserDefaults.standard.object(forKey: "TweakScreenRecorder") as? Bool ?? true
        self.screenRecordResolution = UserDefaults.standard.string(forKey: "ScreenRecordResolution") ?? "native"
        self.screenRecordCaptureMode = UserDefaults.standard.string(forKey: "ScreenRecordCaptureMode") ?? "fullscreen"
        self.screenRecordSavePath = UserDefaults.standard.string(forKey: "ScreenRecordSavePath") ?? "~/Desktop"
        self.screenRecordMicEnabled = UserDefaults.standard.bool(forKey: "ScreenRecordMicEnabled")
        self.screenRecordFps = UserDefaults.standard.object(forKey: "ScreenRecordFps") as? Int ?? 60
        self.screenRecordQuality = UserDefaults.standard.string(forKey: "ScreenRecordQuality") ?? "medium"
        loadRecentRecordings()
    }
    
    func saveScreenRecorderPreferences() {
        UserDefaults.standard.set(enableScreenRecorder, forKey: "TweakScreenRecorder")
        UserDefaults.standard.set(screenRecordResolution, forKey: "ScreenRecordResolution")
        UserDefaults.standard.set(screenRecordCaptureMode, forKey: "ScreenRecordCaptureMode")
        UserDefaults.standard.set(screenRecordSavePath, forKey: "ScreenRecordSavePath")
        UserDefaults.standard.set(screenRecordMicEnabled, forKey: "ScreenRecordMicEnabled")
        UserDefaults.standard.set(screenRecordFps, forKey: "ScreenRecordFps")
        UserDefaults.standard.set(screenRecordQuality, forKey: "ScreenRecordQuality")
    }
    
    func setScreenRecordResolution(_ val: String) {
        self.screenRecordResolution = val
        saveScreenRecorderPreferences()
    }
    
    func setScreenRecordCaptureMode(_ val: String) {
        self.screenRecordCaptureMode = val
        saveScreenRecorderPreferences()
        if val == "selected" {
            CropSelectionWindow.show()
        } else {
            CropSelectionWindow.hide()
        }
    }
    
    func setScreenRecordFps(_ val: Int) {
        self.screenRecordFps = val
        saveScreenRecorderPreferences()
    }
    
    func setScreenRecordQuality(_ val: String) {
        self.screenRecordQuality = val
        saveScreenRecorderPreferences()
    }
    
    func toggleScreenRecordMic() {
        self.screenRecordMicEnabled.toggle()
        saveScreenRecorderPreferences()
    }
    
    func selectScreenRecordSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Save Directory"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                self.screenRecordSavePath = url.path
                saveScreenRecorderPreferences()
                loadRecentRecordings()
            }
        }
    }
    
    func setSelectedLogo(_ val: String) {
        self.selectedLogo = val
        UserDefaults.standard.set(val, forKey: "SelectedLogo")
        NotificationCenter.default.post(name: Notification.Name("UpdateMenuBarIcon"), object: nil)
    }
    
    func getLogoFileInfo() -> (name: String, ext: String) {
        switch selectedLogo {
        case "spiderman":
            return ("icons8-spider-man-new-25", "png")
        case "batman":
            return ("icons8-batman-logo-25", "png")
        case "classic":
            return ("externaldrive", "system")
        default:
            return ("icons8-walter-white", "svg")
        }
    }
    
    func setSelectedRecordLogo(_ val: String) {
        self.selectedRecordLogo = val
        UserDefaults.standard.set(val, forKey: "SelectedRecordLogo")
        NotificationCenter.default.post(name: Notification.Name("UpdateMenuBarIcon"), object: nil)
    }
    
    func getRecordLogoFileInfo() -> (name: String, ext: String) {
        switch selectedRecordLogo {
        case "recording":
            return ("icons8-recording-50.apng", "apng")
        case "fire":
            return ("icons8-fire-40.apng", "apng")
        default:
            return ("icons8-phoenix-30.apng", "apng")
        }
    }
    
    // MARK: - Time Tracker Folders & Auto-Restart Logic
    
    func saveTimeEventFolderOrder() {
        UserDefaults.standard.set(timeEventFolderOrder, forKey: "TimeEventFolderOrder")
        self.objectWillChange.send()
    }
    
    func loadTimeEventFolderOrder() {
        if let saved = UserDefaults.standard.stringArray(forKey: "TimeEventFolderOrder") {
            self.timeEventFolderOrder = saved
        } else {
            self.timeEventFolderOrder = []
            saveTimeEventFolderOrder()
        }
    }
    
    func addTimeEventFolder(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty && !timeEventFolderOrder.contains(clean) else { return }
        timeEventFolderOrder.append(clean)
        saveTimeEventFolderOrder()
    }
    
    func deleteTimeEventFolder(name: String) {
        timeEventFolderOrder.removeAll { $0 == name }
        for i in 0..<timeEvents.count {
            if timeEvents[i].folder == name {
                timeEvents[i].folder = "" // Re-assign to root/uncategorized
            }
        }
        saveTimeEventFolderOrder()
        saveTimeEvents()
    }
    
    func moveTimeEventFolderUp(name: String) {
        guard let idx = timeEventFolderOrder.firstIndex(of: name), idx > 0 else { return }
        timeEventFolderOrder.swapAt(idx, idx - 1)
        saveTimeEventFolderOrder()
    }
    
    func moveTimeEventFolderDown(name: String) {
        guard let idx = timeEventFolderOrder.firstIndex(of: name), idx < timeEventFolderOrder.count - 1 else { return }
        timeEventFolderOrder.swapAt(idx, idx + 1)
        saveTimeEventFolderOrder()
    }
    
    /// Auto-restarts recurring timers and auto-closes One-Time timers when targetDate <= now
    func checkAndProcessRestartTimers(now: Date = Date()) {
        var updated = false
        let calendar = Calendar.current
        
        for i in 0..<timeEvents.count {
            guard !timeEvents[i].isClosed else { continue }
            
            if timeEvents[i].timerType == .oneTime && timeEvents[i].targetDate <= now {
                timeEvents[i].isClosed = true
                updated = true
                continue
            }
            
            if timeEvents[i].timerType == .restart {
                var loopCount = 0
                while timeEvents[i].targetDate <= now && loopCount < 500 {
                    loopCount += 1
                    updated = true
                    timeEvents[i].restartCount += 1
                    timeEvents[i].lastNotified24hDate = nil
                    let oldTarget = timeEvents[i].targetDate
                    
                    switch timeEvents[i].restartFrequency {
                    case .daily:
                        timeEvents[i].targetDate = calendar.date(byAdding: .day, value: 1, to: oldTarget) ?? oldTarget.addingTimeInterval(86400)
                    case .weekly:
                        timeEvents[i].targetDate = calendar.date(byAdding: .day, value: 7, to: oldTarget) ?? oldTarget.addingTimeInterval(86400 * 7)
                    case .monthly:
                        timeEvents[i].targetDate = calendar.date(byAdding: .month, value: 1, to: oldTarget) ?? oldTarget.addingTimeInterval(86400 * 30)
                    case .yearly:
                        timeEvents[i].targetDate = calendar.date(byAdding: .year, value: 1, to: oldTarget) ?? oldTarget.addingTimeInterval(86400 * 365)
                    }
                }
            }
        }
        
        if updated {
            saveTimeEvents()
        }
    }
    
    func addTimeEvent(title: String, folder: String, targetDate: Date, timerType: TimerType, restartFrequency: RestartFrequency) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? "Untitled Event" : cleanTitle
        let cleanFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        comps.second = 0
        let normalizedDate = calendar.date(from: comps) ?? targetDate
        
        let newEvent = TimeEvent(
            id: UUID(),
            title: finalTitle,
            folder: cleanFolder,
            targetDate: normalizedDate,
            createdAt: Date(),
            timerType: timerType,
            restartFrequency: restartFrequency,
            isClosed: false,
            restartCount: 0,
            lastNotified24hDate: nil
        )
        timeEvents.append(newEvent)
        saveTimeEvents()
        checkAndNotifyUpcomingEvents()
    }
    
    func updateTimeEvent(id: UUID, title: String, folder: String, targetDate: Date, timerType: TimerType, restartFrequency: RestartFrequency, isClosed: Bool) {
        if let index = timeEvents.firstIndex(where: { $0.id == id }) {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let calendar = Calendar.current
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
            comps.second = 0
            let normalizedDate = calendar.date(from: comps) ?? targetDate
            
            // If target date changed, reset notification flag so user gets notified for the new deadline
            if timeEvents[index].targetDate != normalizedDate {
                timeEvents[index].lastNotified24hDate = nil
            }
            
            timeEvents[index].title = cleanTitle.isEmpty ? "Untitled Event" : cleanTitle
            timeEvents[index].folder = cleanFolder
            timeEvents[index].targetDate = normalizedDate
            timeEvents[index].timerType = timerType
            timeEvents[index].restartFrequency = restartFrequency
            timeEvents[index].isClosed = isClosed
            saveTimeEvents()
            checkAndNotifyUpcomingEvents()
        }
    }
    
    func toggleTimeEventClosed(id: UUID) {
        if let index = timeEvents.firstIndex(where: { $0.id == id }) {
            timeEvents[index].isClosed.toggle()
            saveTimeEvents()
            checkAndNotifyUpcomingEvents()
        }
    }
    
    func deleteTimeEvent(id: UUID) {
        timeEvents.removeAll(where: { $0.id == id })
        saveTimeEvents()
    }
    
    func saveTimeEvents() {
        if let encoded = try? JSONEncoder().encode(timeEvents) {
            UserDefaults.standard.set(encoded, forKey: "SavedTimeEvents")
        }
        self.objectWillChange.send()
    }
    
    func loadTimeEvents() {
        loadTimeEventFolderOrder()
        if let data = UserDefaults.standard.data(forKey: "SavedTimeEvents"),
           var decoded = try? JSONDecoder().decode([TimeEvent].self, from: data) {
            
            let calendar = Calendar.current
            for i in 0..<decoded.count {
                var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: decoded[i].targetDate)
                comps.second = 0
                if let normalized = calendar.date(from: comps) {
                    decoded[i].targetDate = normalized
                }
            }
            self.timeEvents = decoded
        } else {
            // Default initial example events if none exist
            let calendar = Calendar.current
            let futureDate = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            let pastDate = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            
            var futureComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: futureDate)
            futureComps.second = 0
            let normFuture = calendar.date(from: futureComps) ?? futureDate
            
            var pastComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: pastDate)
            pastComps.second = 0
            let normPast = calendar.date(from: pastComps) ?? pastDate
            
            self.timeEvents = [
                TimeEvent(id: UUID(), title: "Project Milestone", folder: "", targetDate: normFuture, createdAt: Date(), timerType: .unlimited, restartFrequency: .daily, isClosed: false, restartCount: 0, lastNotified24hDate: nil),
                TimeEvent(id: UUID(), title: "Mac ASC Release", folder: "", targetDate: normPast, createdAt: Date(), timerType: .unlimited, restartFrequency: .daily, isClosed: false, restartCount: 0, lastNotified24hDate: nil)
            ]
            saveTimeEvents()
        }
        checkAndProcessRestartTimers()
        checkAndNotifyUpcomingEvents()
        startTimeTrackerBackgroundNotificationTimer()
    }
    
    // MARK: - Time Tracker Notification Checker
    private var timeTrackerNotificationCancellable: AnyCancellable?
    
    func startTimeTrackerBackgroundNotificationTimer() {
        guard timeTrackerNotificationCancellable == nil else { return }
        timeTrackerNotificationCancellable = Timer.publish(every: 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.enableTimeTracker else { return }
                self.checkAndProcessRestartTimers()
                self.checkAndNotifyUpcomingEvents()
            }
    }
    
    /// Scans all active time tracker events and triggers a system notification
    /// if any event has less than 24 hours remaining until its targetDate.
    func checkAndNotifyUpcomingEvents(now: Date = Date()) {
        guard enableTimeTracker else { return }
        var updated = false
        
        for i in 0..<timeEvents.count {
            let event = timeEvents[i]
            guard !event.isClosed else { continue }
            guard event.targetDate > now else { continue }
            
            let timeRemaining = event.targetDate.timeIntervalSince(now)
            // If remaining time is <= 24 hours (86,400 seconds)
            if timeRemaining <= 86400 {
                // Check if already notified for this exact target date
                let alreadyNotified: Bool
                if let lastNotified = event.lastNotified24hDate {
                    alreadyNotified = abs(lastNotified.timeIntervalSince(event.targetDate)) < 60
                } else {
                    alreadyNotified = false
                }
                
                if !alreadyNotified {
                    timeEvents[i].lastNotified24hDate = event.targetDate
                    updated = true
                    
                    let totalMinutes = max(1, Int(ceil(timeRemaining / 60)))
                    let hours = totalMinutes / 60
                    let minutes = totalMinutes % 60
                    let remainingStr: String
                    if hours > 0 && minutes > 0 {
                        remainingStr = "\(hours)h \(minutes)m"
                    } else if hours > 0 {
                        remainingStr = "\(hours)h"
                    } else {
                        remainingStr = "\(minutes)m"
                    }
                    
                    let title = "Mac ASC • Time Tracker"
                    let subtitle = "\(event.title) - Less than 1 day left!"
                    let body = "\"\(event.title)\" has less than 24 hours remaining (\(remainingStr) left). Due: \(event.targetDate.formatted(date: .numeric, time: .shortened))."
                    
                    sendSystemNotification(title: title, subtitle: subtitle, message: body, eventId: event.id)
                }
            }
        }
        
        if updated {
            saveTimeEvents()
        }
    }
    
    func checkNotificationSettings() {
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                DispatchQueue.main.async {
                    self?.isNotificationAuthorized = (settings.authorizationStatus == .authorized)
                }
            }
        }
    }
    
    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func sendSystemNotification(title: String, subtitle: String, message: String, eventId: UUID? = nil) {
        if #available(macOS 10.14, *) {
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = title
            if !subtitle.isEmpty {
                content.subtitle = subtitle
            }
            content.body = message
            content.sound = .default
            if let id = eventId {
                content.userInfo = ["eventId": id.uuidString]
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request) { [weak self] error in
                if let error = error {
                    print("[Mac ASC] Notification delivery error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.checkNotificationSettings()
                    }
                }
            }
        }
    }
    
    func startScreenRecording() {
        guard !isRecording else { return }
        
        let path = (screenRecordSavePath as NSString).expandingTildeInPath
        let folderURL = URL(fileURLWithPath: path)
        
        // Ensure destination folder exists
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let fileURL = folderURL.appendingPathComponent("recording_\(timestamp).mov")
        
        var cropRect: CGRect? = nil
        if screenRecordCaptureMode == "selected" {
            cropRect = CropSelectionWindow.getCropRect()
            CropSelectionWindow.hide()
        }
        
        recorder.onStart = { [weak self] in
            guard let self = self else { return }
            self.isRecording = true
            self.isRecordingPaused = false
            self.recordingStartTime = Date()
            self.recordingDuration = 0
            self.accumulatedDuration = 0
            
            // Start duration timer
            self.recordingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if !self.isRecordingPaused, let start = self.recordingStartTime {
                        self.recordingDuration = self.accumulatedDuration + Date().timeIntervalSince(start)
                    }
                }
            
            // Close utility window immediately when recording starts
            NotificationCenter.default.post(name: Notification.Name("ClosePopover"), object: nil)
        }
        
        recorder.start(
            destinationURL: fileURL,
            resolution: screenRecordResolution,
            captureMode: screenRecordCaptureMode,
            micEnabled: screenRecordMicEnabled,
            fps: screenRecordFps,
            quality: screenRecordQuality,
            cropRect: cropRect
        ) { [weak self] outputURL, error in
            guard let self = self else { return }
            self.isRecording = false
            self.isRecordingPaused = false
            self.recordingTimer?.cancel()
            self.recordingTimer = nil
            self.recordingStartTime = nil
            self.recordingDuration = 0
            self.accumulatedDuration = 0
            
            if let err = error {
                print("Recording failed: \(err.localizedDescription)")
            }
            
            self.loadRecentRecordings()
            
            // Show custom crop area window overlay again after recording completes
            if self.screenRecordCaptureMode == "selected" {
                CropSelectionWindow.show()
            }
        }
    }
    
    func pauseScreenRecording() {
        guard isRecording && !isRecordingPaused else { return }
        recorder.pause()
        isRecordingPaused = true
        
        if let start = recordingStartTime {
            accumulatedDuration += Date().timeIntervalSince(start)
        }
        recordingStartTime = nil
        
        // Show utility window when recording is paused
        NotificationCenter.default.post(name: Notification.Name("ShowPopover"), object: nil)
    }
    
    func resumeScreenRecording() {
        guard isRecording && isRecordingPaused else { return }
        recorder.resume()
        isRecordingPaused = false
        recordingStartTime = Date()
        
        // Close window immediately when recording resumes
        NotificationCenter.default.post(name: Notification.Name("ClosePopover"), object: nil)
    }
    
    func stopScreenRecording() {
        guard isRecording else { return }
        recorder.stop()
    }
    
    func loadRecentRecordings() {
        let path = (screenRecordSavePath as NSString).expandingTildeInPath
        let folderURL = URL(fileURLWithPath: path)
        
        let fileKeys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: fileKeys,
            options: .skipsHiddenFiles
        ) else {
            self.recentRecordings = []
            return
        }
        
        // Filter for video files (mp4 and mov) and sort by modification date descending (newest first)
        let sortedVideos = files
            .filter { ["mp4", "mov"].contains($0.pathExtension.lowercased()) }
            .sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: Set(fileKeys)).contentModificationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: Set(fileKeys)).contentModificationDate) ?? Date.distantPast
                return date1 > date2
            }
        
        self.recentRecordings = Array(sortedVideos.prefix(5))
    }
}

// MARK: - Models

struct TabShortcut: Codable, Equatable {
    var key: String
    var modifiers: UInt
    
    var displayString: String {
        var str = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        str += key.uppercased()
        return str
    }
}

struct FolderNode: Identifiable, Equatable {
    var id: String { fullPath }
    let name: String
    let fullPath: String
    var subfolders: [FolderNode]
}

struct TerminalCommand: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var folder: String?
    var tag: String?
    var runSilent: Bool? = false
}

struct QuickNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var dateCreated: Date
    var folder: String?
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let isUser: Bool
    let timestamp: Date
}

struct ChatThread: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var activeSessionId: String?
    var attachedDirectory: String?
    var attachedDirectories: [String]?
    var selectedModel: String?
    var messages: [ChatMessage]
    let dateCreated: Date
    var folder: String?
    
    var allAttachments: [String] {
        if let list = attachedDirectories, !list.isEmpty {
            return list
        } else if let single = attachedDirectory, !single.isEmpty {
            return [single]
        }
        return []
    }
}

enum TimerType: String, Codable, CaseIterable {
    case unlimited = "Unlimited"
    case restart = "Restart"
    case oneTime = "One-Time"
}

enum RestartFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct TimeEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var folder: String = ""
    var targetDate: Date
    var createdAt: Date = Date()
    
    var timerType: TimerType = .unlimited
    var restartFrequency: RestartFrequency = .daily
    
    var isClosed: Bool = false
    var restartCount: Int = 0
    var lastNotified24hDate: Date? = nil
}

struct AgyUsageGroup: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var quotas: [AgyUsageQuota]
}

struct AgyUsageQuota: Identifiable, Codable {
    var id: UUID = UUID()
    var category: String = ""
    var limitType: String = ""
    var fraction: Double = 1.0
    var percent: Int = 100
    var percentageString: String = "100.00%"
    var refreshString: String = "Quota available"
    var resetTime: String = ""
}


