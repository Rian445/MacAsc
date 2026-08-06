import SwiftUI
import AppKit

struct DropdownView: View {
    @ObservedObject var viewModel: StorageViewModel
    @State private var selectedTab: Int = 0 // 0 = Apps, 1 = Files & Folders
    @State private var showAllApps = false
    
    @State private var currentTopTab: Int = 0 // 0 = Disk Insight, 1 = Custom Commands
    @State private var newCommandName = ""
    @State private var newCommandString = ""
    @State private var newCommandFolder = ""
    @State private var newCommandTag = ""
    @State private var isAddFormExpanded = false
    
    @State private var commandToDelete: TerminalCommand? = nil
    @State private var showDeleteConfirmation = false
    @State private var showAboutPopover = false
    
    @State private var editingCommand: TerminalCommand? = nil
    @State private var newCommandRunSilent: Bool = false
    @State private var keyMonitor: Any? = nil
    @State private var recordingShortcutTabId: Int? = nil
    @State private var accumulatedScrollX: CGFloat = 0
    @State private var swipeCooldownActive: Bool = false
    @State private var lastSwipeTime: Date = Date.distantPast
    @State private var collapsedFolders: Set<String> = []
    
    // Quick Notes State
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var newNoteFolder = ""
    @State private var isNoteFormExpanded = false
    @State private var isCreatingFullNote = false
    @State private var isNoteEditingMode = false
    @State private var noteSearchQuery = ""
    @State private var editingNote: QuickNote? = nil
    @State private var noteToDelete: QuickNote? = nil
    @State private var showNoteDeleteConfirmation = false
    @State private var copiedNoteId: UUID? = nil
    @State private var collapsedNotesFolders: Set<String> = []
    
    // AI Chat State
    @State private var editingThread: ChatThread? = nil
    @State private var newThreadTitleInput = ""
    @State private var newThreadFolderInput = ""
    @State private var showEditThreadDialog = false
    @State private var showRemoveAttachmentPopover = false
    @State private var showAllModels = false
    
    // AI Chat State
    @State private var tabPageIndex: Int = 0
    @State private var isBackwardSlide: Bool = false
    @State private var chatInputText = ""
    @State private var isChatInputFocused: Bool = true
    @State private var isDraggingFolderOver = false
    
    // Sort Mode State
    @State private var isCommandSortActive = false
    @State private var isNoteSortActive = false
    
    // Folder Delete State
    @State private var folderToDelete: String? = nil
    @State private var isDeletingCommandFolder: Bool = true
    @State private var showDeleteFolderDialog = false
    
    // Settings Navigation State
    @State private var showSettings = false
    @State private var settingsActiveTab = 0 // 0 = About, 1 = Tweak

    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
                .opacity(0.3)
            
            if showSettings {
                settingsView
            } else {
                // Top Tab Selector (segmented control with pagination slider)
                let enabledTabs = activeTabs
                if !enabledTabs.isEmpty {
                    HStack(spacing: 8) {
                        if enabledTabs.count > 2 {
                            Button(action: {
                                isBackwardSlide = true
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    let pageCount = max(1, (enabledTabs.count + 1) / 2)
                                    let newPageIndex = (tabPageIndex - 1 + pageCount) % pageCount
                                    tabPageIndex = newPageIndex
                                    
                                    let pageStart = newPageIndex * 2
                                    let pageTabs = Array(enabledTabs.dropFirst(pageStart).prefix(2))
                                    if !pageTabs.contains(where: { $0.id == currentTopTab }) {
                                        if let firstTab = pageTabs.first {
                                            currentTopTab = firstTab.id
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 4) {
                            if enabledTabs.count > 2 {
                                let pageStart = tabPageIndex * 2
                                let visibleTabs = Array(enabledTabs.dropFirst(pageStart).prefix(2))
                                ForEach(visibleTabs) { tab in
                                    TabButton(title: tab.title, isSelected: safeTopTab == tab.id, accentColor: tab.accentColor) {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            currentTopTab = tab.id
                                        }
                                    }
                                }
                            } else {
                                // If 2 or fewer tabs, just show them in a simple row
                                ForEach(enabledTabs) { tab in
                                    TabButton(title: tab.title, isSelected: safeTopTab == tab.id, accentColor: tab.accentColor) {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            currentTopTab = tab.id
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .id(tabPageIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: isBackwardSlide ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: isBackwardSlide ? .trailing : .leading).combined(with: .opacity)
                        ))
                        
                        if enabledTabs.count > 2 {
                            Button(action: {
                                isBackwardSlide = false
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    let pageCount = max(1, (enabledTabs.count + 1) / 2)
                                    let newPageIndex = (tabPageIndex + 1) % pageCount
                                    tabPageIndex = newPageIndex
                                    
                                    let pageStart = newPageIndex * 2
                                    let pageTabs = Array(enabledTabs.dropFirst(pageStart).prefix(2))
                                    if !pageTabs.contains(where: { $0.id == currentTopTab }) {
                                        if let firstTab = pageTabs.first {
                                            currentTopTab = firstTab.id
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                }
                
                // Content based on selected tab
                let tabToRender = safeTopTab
                if tabToRender == 0 {
                    // Scrollable Content - Disk Insight
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Internal Storage
                            if let internalDrive = viewModel.internalDrive {
                                internalStorageSection(for: internalDrive)
                            }
                            
                            // External Storage
                            externalStorageSection
                            
                            // Pinned Folders
                            pinnedFoldersSection
                            
                            // Breakdown Switcher and Lists
                            breakdownSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                } else if tabToRender == 1 {
                    // Custom Terminal Commands View
                    ScrollView(.vertical, showsIndicators: false) {
                        customCommandsSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                } else if tabToRender == 2 {
                    // Quick Notes View
                    if editingNote != nil || isCreatingFullNote {
                        quickNotesSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.001))
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            quickNotesSection
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .frame(maxHeight: .infinity)
                        .background(Color.black.opacity(0.001))
                        .contentShape(Rectangle())
                    }
                } else if tabToRender == 3 {
                    // Chat with AI View (opencode TUI wrapper)
                    aiChatSection
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxHeight: .infinity)
                        .background(Color.black.opacity(0.001))
                        .onAppear {
                            viewModel.loadAvailableModels()
                        }
                } else if tabToRender == 4 {
                    // Screen Recorder View
                    ScrollView(.vertical, showsIndicators: false) {
                        screenRecorderSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .onAppear {
                        viewModel.loadRecentRecordings()
                        if viewModel.screenRecordCaptureMode == "selected" && !viewModel.isRecording {
                            CropSelectionWindow.show()
                        }
                    }
                    .onDisappear {
                        CropSelectionWindow.hide()
                    }
                } else {
                    // Fallback empty view if all tabs disabled
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("All Tabs Hidden")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Enable dashboard components in settings to view them.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            
            Divider()
                .opacity(0.3)
            
            // Footer
            footerView
        }
        .frame(width: 360, height: 490)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.45) // Reduce background transparency and light bleed
            }
            .cornerRadius(12)
            .ignoresSafeArea()
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .colorScheme(.dark) // Lock drop-down to a dark glass style for premium feel
        .confirmationDialog(
            "Are you sure you want to delete this command?",
            isPresented: $showDeleteConfirmation,
            presenting: commandToDelete
        ) { targetCmd in
            Button("Delete", role: .destructive) {
                viewModel.removeCustomCommand(id: targetCmd.id)
                commandToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                commandToDelete = nil
            }
        } message: { targetCmd in
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            "Are you sure you want to delete this note?",
            isPresented: $showNoteDeleteConfirmation,
            presenting: noteToDelete
        ) { targetNote in
            Button("Delete", role: .destructive) {
                viewModel.removeQuickNote(id: targetNote.id)
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
        } message: { targetNote in
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            "Delete Folder '\(folderToDelete ?? "")'?",
            isPresented: $showDeleteFolderDialog
        ) {
            Button("Uncategorize Items", role: .none) {
                if let folder = folderToDelete {
                    if isDeletingCommandFolder {
                        viewModel.deleteCommandFolder(folder, deleteContents: false)
                    } else {
                        viewModel.deleteNoteFolder(folder, deleteContents: false)
                    }
                }
                folderToDelete = nil
            }
            Button("Delete Folder & All Contents", role: .destructive) {
                if let folder = folderToDelete {
                    if isDeletingCommandFolder {
                        viewModel.deleteCommandFolder(folder, deleteContents: true)
                    } else {
                        viewModel.deleteNoteFolder(folder, deleteContents: true)
                    }
                }
                folderToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
        } message: {
            Text("Choose whether to keep items (uncategorize) or delete all commands/notes inside this folder.")
        }
        .onAppear {
            viewModel.startMonitoringRunningCommands()
            viewModel.scanAppSelfSizes()
            setupKeyboardShortcutMonitor()
        }
        .onDisappear {
            viewModel.stopMonitoringRunningCommands()
            removeKeyboardShortcutMonitor()
        }
    }
    
    // MARK: - Local Keyboard Shortcut & Scroll Swipe Monitor
    
    private func cycleTab(direction: Int) {
        let enabled = self.activeTabs
        guard !enabled.isEmpty else { return }
        
        let currentIndex = enabled.firstIndex(where: { $0.id == currentTopTab }) ?? 0
        let nextIndex = (currentIndex + direction + enabled.count) % enabled.count
        let nextTabId = enabled[nextIndex].id
        
        withAnimation(.easeInOut(duration: 0.22)) {
            currentTopTab = nextTabId
            tabPageIndex = nextIndex / 2
        }
    }
    
    private func setupKeyboardShortcutMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { event in
            if event.type == .keyDown {
                // If actively recording a shortcut in Settings, capture key press!
                if let recordingTabId = self.recordingShortcutTabId {
                    let pressedKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
                    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    if !pressedKey.isEmpty {
                        viewModel.setTabShortcut(tabId: recordingTabId, key: pressedKey, modifiers: flags.rawValue)
                        DispatchQueue.main.async {
                            self.recordingShortcutTabId = nil
                        }
                        return nil // Consume event
                    }
                }
                
                // If user is actively typing text inside a TextField or TextEditor / NSTextView, ignore single key press without Command/Option/Control modifiers
                if let responder = NSApp.keyWindow?.firstResponder {
                    let responderType = String(describing: type(of: responder))
                    if responderType.contains("TextView") || responderType.contains("TextField") {
                        let hasModifier = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) || event.modifierFlags.contains(.control)
                        if !hasModifier {
                            return event
                        }
                    }
                }
                
                let pressedKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
                let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                
                for (tabId, shortcut) in viewModel.tabShortcuts {
                    let targetFlags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers).intersection(.deviceIndependentFlagsMask)
                    if pressedKey == shortcut.key.lowercased() && currentFlags == targetFlags {
                        if isTabEnabled(tabId) {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    currentTopTab = tabId
                                    let enabledTabs = self.activeTabs
                                    if let tabIdx = enabledTabs.firstIndex(where: { $0.id == tabId }) {
                                        tabPageIndex = tabIdx / 2
                                    }
                                }
                            }
                            return nil // Consume event
                        }
                    }
                }
            } else if event.type == .scrollWheel {
                // Ignore scroll events when actively recording a shortcut
                if recordingShortcutTabId != nil {
                    return event
                }
                
                // Ignore momentum/inertia scrolls completely
                if !event.momentumPhase.isEmpty {
                    return event
                }
                
                let deltaX = event.scrollingDeltaX
                let deltaY = event.scrollingDeltaY
                
                // Switch tabs only when horizontal scrolling is dominant (e.g. 2-finger horizontal swipe/scroll)
                if abs(deltaX) > abs(deltaY) * 1.5 {
                    let phase = event.phase
                    
                    // Time-based debounce (minimum 400ms between any tab switches to prevent skipping)
                    let now = Date()
                    guard now.timeIntervalSince(lastSwipeTime) > 0.4 else {
                        return nil // Consume scroll event during cooldown
                    }
                    
                    if phase == .began {
                        accumulatedScrollX = 0
                        swipeCooldownActive = false
                    } else if phase == .changed {
                        if !swipeCooldownActive {
                            accumulatedScrollX += deltaX
                            let threshold: CGFloat = 80 // More responsive threshold
                            
                            if abs(accumulatedScrollX) > threshold {
                                swipeCooldownActive = true
                                lastSwipeTime = now
                                let direction = accumulatedScrollX > 0 ? -1 : 1
                                accumulatedScrollX = 0
                                DispatchQueue.main.async {
                                    self.cycleTab(direction: direction)
                                }
                            }
                        }
                    } else if phase == .ended || phase == .cancelled {
                        accumulatedScrollX = 0
                        swipeCooldownActive = false
                    } else if phase.isEmpty {
                        // Support for mice/momentum scrolling where phase might not be present
                        accumulatedScrollX += deltaX
                        let threshold: CGFloat = 30
                        if abs(accumulatedScrollX) > threshold {
                            lastSwipeTime = now
                            let direction = deltaX > 0 ? -1 : 1
                            accumulatedScrollX = 0
                            DispatchQueue.main.async {
                                self.cycleTab(direction: direction)
                            }
                        }
                    }
                    
                    // Consume the event to prevent parent ScrollViews from horizontal scrolling
                    return nil
                }
            }
            return event
        }
    }
    
    private func removeKeyboardShortcutMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        recordingShortcutTabId = nil
    }
    
    // MARK: - Dynamic Navigation & Tweak Settings Helpers
    
    struct AppTab: Identifiable, Equatable {
        let id: Int
        let title: String
        let icon: String
        let accentColor: Color
    }
    
    var activeTabs: [AppTab] {
        let allTabsMap: [Int: AppTab] = [
            0: AppTab(id: 0, title: "Disk Insight", icon: "chart.pie.fill", accentColor: .cyan),
            1: AppTab(id: 1, title: "Custom Commands", icon: "terminal.fill", accentColor: .blue),
            2: AppTab(id: 2, title: "Quick Note", icon: "note.text", accentColor: .yellow),
            3: AppTab(id: 3, title: "Chat with AI", icon: "cpu.fill", accentColor: .purple),
            4: AppTab(id: 4, title: "Screen Recorder", icon: "record.circle", accentColor: .red)
        ]
        
        var result: [AppTab] = []
        for id in viewModel.tabOrder {
            guard let tab = allTabsMap[id] else { continue }
            if id == 0 && viewModel.enableDiskInsight { result.append(tab) }
            else if id == 1 && viewModel.enableCustomCommands { result.append(tab) }
            else if id == 2 && viewModel.enableQuickNotes { result.append(tab) }
            else if id == 3 && viewModel.enableAiChat { result.append(tab) }
            else if id == 4 && viewModel.enableScreenRecorder { result.append(tab) }
        }
        return result
    }
    
    var safeTopTab: Int {
        let enabled = activeTabs
        if enabled.contains(where: { $0.id == currentTopTab }) {
            return currentTopTab
        }
        return enabled.first?.id ?? 0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hrs = Int(duration) / 3600
        let mins = (Int(duration) % 3600) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
    
    private var screenRecorderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Main Recording Status/Control Card
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                        .animation(
                            viewModel.isRecording ? 
                            Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                            .default, 
                            value: viewModel.isRecording
                        )
                    
                    Text(viewModel.isRecording ? "RECORDING ACTIVE" : "SCREEN RECORDER STANDBY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isRecording {
                        Text(formatDuration(viewModel.recordingDuration))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
                
                if viewModel.isRecording {
                    HStack(spacing: 8) {
                        // Pause / Resume button
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if viewModel.isRecordingPaused {
                                    viewModel.resumeScreenRecording()
                                } else {
                                    viewModel.pauseScreenRecording()
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.isRecordingPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(viewModel.isRecordingPaused ? "Resume" : "Pause")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.85))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Stop button
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.stopScreenRecording()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Stop")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.startScreenRecording()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 12, weight: .bold))
                            Text("Start Recording")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.85))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Preferences section
            VStack(alignment: .leading, spacing: 10) {
                Text("RECORDING PREFERENCES")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                VStack(spacing: 8) {
                    // Resolution selector
                    HStack {
                        Label("Resolution", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { viewModel.screenRecordResolution },
                            set: { viewModel.setScreenRecordResolution($0) }
                        )) {
                            Text("Native").tag("native")
                            Text("1080p").tag("1080p")
                            Text("720p").tag("720p")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 190)
                    }
                    
                    Divider().opacity(0.08)
                    
                    // Capture area selector
                    HStack {
                        Label("Capture Area", systemImage: "rectangle.dashed.and.paperclip")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { viewModel.screenRecordCaptureMode },
                            set: { viewModel.setScreenRecordCaptureMode($0) }
                        )) {
                            Text("Full Screen").tag("fullscreen")
                            Text("Window").tag("selected")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 190)
                    }
                    
                    Divider().opacity(0.08)
                    
                    // Frame rate (FPS)
                    HStack {
                        Label("Frame Rate", systemImage: "clock.arrow.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { viewModel.screenRecordFps },
                            set: { viewModel.setScreenRecordFps($0) }
                        )) {
                            Text("30 FPS").tag(30)
                            Text("60 FPS").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 190)
                    }
                    
                    Divider().opacity(0.08)
                    
                    // Quality / Bitrate selector
                    HStack {
                        Label("Quality", systemImage: "slider.horizontal.3")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { viewModel.screenRecordQuality },
                            set: { viewModel.setScreenRecordQuality($0) }
                        )) {
                            Text("Low").tag("low")
                            Text("Medium").tag("medium")
                            Text("High").tag("high")
                            Text("Ultra").tag("ultra")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 190)
                    }
                    
                    Divider().opacity(0.08)
                    
                    // Mic toggle
                    HStack {
                        Label("Microphone", systemImage: viewModel.screenRecordMicEnabled ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { viewModel.screenRecordMicEnabled },
                            set: { _ in viewModel.toggleScreenRecordMic() }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.7)
                        .frame(width: 28, height: 16)
                    }
                    
                    Divider().opacity(0.08)
                    
                    // Save path
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow.opacity(0.85))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Save Location")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(viewModel.screenRecordSavePath)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.selectScreenRecordSavePath()
                        }) {
                            Text("Browse")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            
            // Recent Recordings listing
            VStack(alignment: .leading, spacing: 8) {
                Text("RECENT RECORDINGS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                if viewModel.recentRecordings.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No recent screen recordings found")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(viewModel.recentRecordings, id: \.self) { fileURL in
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.85))
                                
                                Text(fileURL.lastPathComponent)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                Button(action: {
                                    NSWorkspace.shared.open(fileURL)
                                }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                                }) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private func tweakToggleRow(title: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 11))
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.7)
                .frame(width: 28, height: 16)
        }
    }
    
    private func tabInfoForId(_ id: Int) -> (title: String, icon: String, color: Color) {
        switch id {
        case 0: return ("Disk Insight", "chart.pie.fill", .cyan)
        case 1: return ("Custom Commands", "terminal.fill", .blue)
        case 2: return ("Quick Note", "note.text", .yellow)
        case 3: return ("Chat with AI", "cpu.fill", .purple)
        case 4: return ("Screen Recorder", "record.circle", .red)
        default: return ("Tab", "square.fill", .white)
        }
    }
    
    private func isTabEnabled(_ id: Int) -> Bool {
        switch id {
        case 0: return viewModel.enableDiskInsight
        case 1: return viewModel.enableCustomCommands
        case 2: return viewModel.enableQuickNotes
        case 3: return viewModel.enableAiChat
        case 4: return viewModel.enableScreenRecorder
        default: return false
        }
    }
    
    private func bindingForTabId(_ id: Int) -> Binding<Bool> {
        switch id {
        case 0:
            return Binding(get: { viewModel.enableDiskInsight }, set: { viewModel.setTweak("TweakDiskInsight", value: $0) })
        case 1:
            return Binding(get: { viewModel.enableCustomCommands }, set: { viewModel.setTweak("TweakCustomCommands", value: $0) })
        case 2:
            return Binding(get: { viewModel.enableQuickNotes }, set: { viewModel.setTweak("TweakQuickNote", value: $0) })
        case 3:
            return Binding(get: { viewModel.enableAiChat }, set: { viewModel.setTweak("TweakChatWithAi", value: $0) })
        case 4:
            return Binding(get: { viewModel.enableScreenRecorder }, set: { viewModel.setTweak("TweakScreenRecorder", value: $0) })
        default:
            return .constant(true)
        }
    }
    
    private var settingsView: some View {
        VStack(spacing: 0) {
            Picker("", selection: $settingsActiveTab) {
                Text("About").tag(0)
                Text("Tweak").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            Divider()
                .opacity(0.15)
            
            if settingsActiveTab == 0 {
                ScrollView(.vertical, showsIndicators: true) {
                    aboutMePanel
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Menu Bar Logo Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MENU BAR LOGO CUSTOMIZATION")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Menu Bar Icon", systemImage: "paintpalette.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Picker("", selection: Binding(
                                    get: { viewModel.selectedLogo },
                                    set: { viewModel.setSelectedLogo($0) }
                                )) {
                                    Text("Classic").tag("classic")
                                    Text("Walter").tag("walter")
                                    Text("Spider").tag("spiderman")
                                    Text("Batman").tag("batman")
                                }
                                .pickerStyle(.segmented)
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            
                            // Active Recording Logo Section
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Active Recording Icon", systemImage: "record.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Picker("", selection: Binding(
                                    get: { viewModel.selectedRecordLogo },
                                    set: { viewModel.setSelectedRecordLogo($0) }
                                )) {
                                    Text("Phoenix").tag("phoenix")
                                    Text("Record").tag("recording")
                                    Text("Fire").tag("fire")
                                }
                                .pickerStyle(.segmented)
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        
                        Divider()
                            .opacity(0.12)
                            .padding(.vertical, 4)
                            
                        Text("TAB ORDER & DISPLAY TWEAKS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        Text("Use ▲ and ▼ arrows to reorder navigation tabs, or toggle switches to show/hide them:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(viewModel.tabOrder.enumerated()), id: \.element) { index, tabId in
                                let tabInfo = tabInfoForId(tabId)
                                HStack(spacing: 8) {
                                    Image(systemName: tabInfo.icon)
                                        .foregroundColor(tabInfo.color)
                                        .font(.system(size: 11))
                                        .frame(width: 18)
                                    
                                    Text(tabInfo.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Move Up & Down controls
                                    HStack(spacing: 3) {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                viewModel.moveTabUp(at: index)
                                            }
                                        }) {
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(index > 0 ? .white : .secondary.opacity(0.3))
                                                .padding(4)
                                                .background(Color.white.opacity(index > 0 ? 0.08 : 0.02))
                                                .cornerRadius(4)
                                        }
                                        .disabled(index == 0)
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                viewModel.moveTabDown(at: index)
                                            }
                                        }) {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(index < viewModel.tabOrder.count - 1 ? .white : .secondary.opacity(0.3))
                                                .padding(4)
                                                .background(Color.white.opacity(index < viewModel.tabOrder.count - 1 ? 0.08 : 0.02))
                                                .cornerRadius(4)
                                        }
                                        .disabled(index == viewModel.tabOrder.count - 1)
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Toggle("", isOn: bindingForTabId(tabId))
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                        .scaleEffect(0.7)
                                        .frame(width: 28, height: 16)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(tabInfo.color.opacity(0.08))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(tabInfo.color.opacity(0.25), lineWidth: 1)
                                )
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    viewModel.resetTabOrder()
                                }
                            }) {
                                Label("Reset Tab Order", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text("Disabled features are hidden immediately from navigation tab bar.")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 6)
                        
                        Divider()
                            .opacity(0.12)
                            .padding(.vertical, 4)
                        
                        // Tab Keyboard Shortcuts Section
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("TAB KEYBOARD SHORTCUTS")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        viewModel.resetTabShortcutsToDefault()
                                    }
                                }) {
                                    Label("Reset Shortcuts", systemImage: "arrow.counterclockwise")
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("Shortcuts active when Mac ASC is open. Click any shortcut badge to record a new key combination:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 2)
                            
                            VStack(spacing: 6) {
                                ForEach([0, 1, 2, 3, 4], id: \.self) { tabId in
                                    let tabInfo = tabInfoForId(tabId)
                                    let isEnabled = isTabEnabled(tabId)
                                    let shortcut = viewModel.tabShortcuts[tabId]
                                    let isRecording = recordingShortcutTabId == tabId
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: tabInfo.icon)
                                            .foregroundColor(isEnabled ? tabInfo.color : .secondary)
                                            .font(.system(size: 11))
                                            .frame(width: 18)
                                        
                                        Text(tabInfo.title)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(isEnabled ? .white : .secondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if recordingShortcutTabId == tabId {
                                                recordingShortcutTabId = nil
                                            } else {
                                                recordingShortcutTabId = tabId
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                if isRecording {
                                                    Image(systemName: "keyboard.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.yellow)
                                                    Text("Press Key...")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.yellow)
                                                } else {
                                                    Text(shortcut?.displayString ?? "None")
                                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(isRecording ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                                            .cornerRadius(5)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .strokeBorder(isRecording ? Color.yellow.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!isEnabled)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                        
                        Divider()
                            .opacity(0.12)
                            .padding(.vertical, 4)
                        
                        Text("BACKUP & RESTORE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Text("Export your customized commands, quick notes, pinned folders, and AI chat sessions, or import a previously saved backup file:")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.backupUserSettings()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Export Backup...")
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                viewModel.restoreUserSettings()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.doc.fill")
                                    Text("Import Backup...")
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Subviews

extension DropdownView {
    
    // Header
    private var headerView: some View {
        ZStack {
            // Left-aligned actions (Settings / Back button)
            HStack {
                if showSettings {
                    Button(action: {
                        showSettings = false
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Back")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Back to Main Dashboard")
                } else {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                
                Spacer()
            }

            // Centered Title & Icon
            HStack(spacing: 6) {
                let logoInfo = viewModel.getLogoFileInfo()
                if logoInfo.ext == "system" {
                    Image(systemName: logoInfo.name)
                        .foregroundColor(.blue)
                        .font(.title2)
                } else if let path = Bundle.main.path(forResource: logoInfo.name, ofType: logoInfo.ext),
                          let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 23, height: 23)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                Text("Mac ASC")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if viewModel.isScanning {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .scaleEffect(viewModel.isScanning ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isScanning)
                }
            }
            
            // Right-aligned actions
            HStack {
                Spacer()
                
                Button(action: {
                    viewModel.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isScanning ? 360 : 0))
                        .animation(viewModel.isScanning ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default, value: viewModel.isScanning)
                }
                .buttonStyle(.plain)
                .help("Scan disk spaces")
                .disabled(viewModel.isScanning)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var appLogoImage: NSImage? {
        if let bundleUrl = Bundle.main.url(forResource: "MacASC_logo", withExtension: "png"),
           let img = NSImage(contentsOf: bundleUrl) {
            return img
        }
        let devPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/MacASC_logo.png")
        if let img = NSImage(contentsOf: devPath) {
            return img
        }
        if let mainIcon = NSApplication.shared.applicationIconImage {
            return mainIcon
        }
        return nil
    }

    // About Me Popover Panel
    private var aboutMePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let logo = appLogoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(5)
                } else {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                Text("Mac ASC")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEVELOPED BY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Rian Islam Aornob")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        Link("Portfolio Website", destination: URL(string: "https://portfolio-rian-islams-projects.vercel.app/")!)
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text("rianislam@duck.com")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("LANGUAGES USED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Swift, SwiftUI, AppKit")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("SECURITY & PRIVACY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text("100% Offline (No online footprint)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        } icon: {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                        }
                        
                        Label {
                            Text("ATS Lock (OS rejects internet)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        } icon: {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                        }
                        
                        Label {
                            Text("Zero External Dependencies")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("APPLICATION DISK FOOTPRINT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("App Binary (.app)")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(viewModel.appBundleSize.formattedStorageSize())
                                .font(.system(size: 9))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        Text("USER DATA & CONFIG")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 1)
                        
                        HStack {
                            Text("General Settings & Cache:")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(viewModel.appGeneralSettingsSize.formattedStorageSize())
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Saved Commands:")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(viewModel.appCommandsSize.formattedStorageSize())
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Quick Notes:")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(viewModel.appNotesSize.formattedStorageSize())
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Chat with AI:")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(viewModel.appChatAiSize.formattedStorageSize())
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        HStack {
                            Text("Total Space:")
                                .font(.system(size: 9))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                            Text((viewModel.appBundleSize + viewModel.appSettingsSize).formattedStorageSize())
                                .font(.system(size: 9))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            HStack {
                Spacer()
                Text("Version 1.1.0")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 260)
    }
    
    // Internal Storage Section
    private func internalStorageSection(for drive: DriveInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drive.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Internal SSD")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(drive.formattedUsed) of \(drive.formattedTotal) used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Stacked custom progress bar
            let segments = calculateSegments(for: drive, breakdown: viewModel.storageBreakdown)
            StackedProgressBar(segments: segments)
            
            // Legend grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(segments.filter { $0.name != "Free Space" }) { segment in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)
                        
                        Text(segment.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(segment.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.top, 4)
            
            Divider()
                .opacity(0.15)
                .padding(.vertical, 2)
            
            if viewModel.isMoleInstalled {
                Button(action: {
                    viewModel.runMole()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text("Clean with Mole")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Launch Mole in Terminal to clean your system")
            } else {
                Button(action: {
                    viewModel.downloadMole()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("Wanna clean your Mac? Download Mole 1st")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open official GitHub to download Mole CLI")
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // External Storage Section
    private var externalStorageSection: some View {
        Group {
            if !viewModel.externalDrives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("External Storage")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                    
                    ForEach(viewModel.externalDrives) { drive in
                        let breakdown = viewModel.driveBreakdowns[drive.path] ?? StorageBreakdown()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(drive.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("External Drive")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    viewModel.eject(drive: drive)
                                }) {
                                    Image(systemName: "eject.fill")
                                        .font(.caption2)
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Eject volume")
                            }
                            
                            HStack {
                                Text("\(drive.formattedUsed) of \(drive.formattedTotal) used")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(drive.formattedFree) free")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Stacked custom progress bar for external drive
                            let segments = calculateSegments(for: drive, breakdown: breakdown)
                            StackedProgressBar(segments: segments)
                            
                            // Legend grid for external drive
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(segments.filter { $0.name != "Free Space" && $0.size > 0 }) { segment in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(segment.color)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(segment.name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(segment.formattedSize)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    // Pinned Folders Section
    private var pinnedFoldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pinned Folders")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
                
                Spacer()
                
                Button(action: {
                    viewModel.addPinnedFolder()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Pin a folder")
            }
            
            if viewModel.pinnedFolders.isEmpty {
                HStack {
                    Spacer()
                    Text("No pinned folders. Click + to add.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)
                    Spacer()
                }
                .background(Color.white.opacity(0.02))
                .cornerRadius(10)
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.pinnedFolders) { folder in
                        HStack(spacing: 10) {
                            HStack(spacing: 10) {
                                FileIconView(path: folder.path, fallbackSystemName: "folder.fill")
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(folder.truncatedPath)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(folder.formattedSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                            }
                            .background(Color.white.opacity(0.001))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.openFolder(path: folder.path)
                            }
                            
                            Button(action: {
                                viewModel.removePinnedFolder(id: folder.id)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Unpin folder")
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // Breakdown Section
    private var breakdownSection: some View {
        VStack(spacing: 10) {
            // Tab Switcher
            HStack(spacing: 4) {
                TabButton(title: "Top Apps", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "Largest Files", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            
            // Tab Contents
            if selectedTab == 0 {
                // Apps list
                if viewModel.isScanning && viewModel.appItems.isEmpty {
                    loadingPlaceholder
                } else if viewModel.appItems.isEmpty {
                    emptyPlaceholder(text: "No applications found.")
                } else {
                    VStack(spacing: 2) {
                        if showAllApps {
                            ForEach(viewModel.appItems) { app in
                                AppRow(app: app)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    showAllApps = false
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Show Less")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            let top5 = Array(viewModel.appItems.prefix(5))
                            ForEach(top5) { app in
                                AppRow(app: app)
                            }
                            
                            if viewModel.appItems.count > 5 {
                                let remaining = viewModel.appItems.suffix(from: 5)
                                let remainingSize = remaining.reduce(0) { $0 + $1.size }
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Other Apps")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(remainingSize.formattedStorageSize())
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        showAllApps = true
                                    }
                                }
                                .help("Click to view all apps")
                            }
                        }
                    }
                }
            } else {
                // Files list
                if viewModel.isScanning && viewModel.storageBreakdown.topFiles.isEmpty {
                    loadingPlaceholder
                } else if viewModel.storageBreakdown.topFiles.isEmpty {
                    emptyPlaceholder(text: "No large files found.")
                } else {
                    VStack(spacing: 2) {
                        ForEach(viewModel.storageBreakdown.topFiles) { file in
                            FileRow(file: file)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Footer
    private var footerView: some View {
        HStack {
            if let lastScan = viewModel.lastScanTime {
                Text("Last scan: \(formatDate(lastScan))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Scanning system...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.1))
    }
    
    // Loading/Empty elements
    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Analyzing files...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
    }
    
    private func emptyPlaceholder(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 120)
    }
}

// MARK: - List Rows

struct AppRow: View {
    let app: AppItem
    
    var body: some View {
        HStack(spacing: 8) {
            FileIconView(path: app.path, fallbackSystemName: "app.gift")
            
            Text(app.name)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Text(app.formattedSize)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Button(action: {
                if !app.path.isEmpty {
                    NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                }
            }) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundColor(.blue.opacity(0.85))
                    .padding(5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if !app.path.isEmpty {
                NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
            }
        }
    }
}

struct FileRow: View {
    let file: FileItem
    
    var body: some View {
        HStack(spacing: 8) {
            FileIconView(path: file.path, fallbackSystemName: "doc")
            
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(file.truncatedPath)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Button(action: {
                if !file.path.isEmpty {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                }
            }) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundColor(.blue.opacity(0.85))
                    .padding(5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Reveal file in Finder")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !file.path.isEmpty {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            }
        }
    }
}

struct FileIconView: View {
    let path: String
    let fallbackSystemName: String
    
    var body: some View {
        if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            let image = NSWorkspace.shared.icon(forFile: path)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: fallbackSystemName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Tab Button & Progress Components

struct TabButton: View {
    let title: String
    let isSelected: Bool
    var accentColor: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(accentColor.opacity(0.24))
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(accentColor.opacity(0.5), lineWidth: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.001))
                        }
                    }
                )
                .animation(.easeInOut(duration: 0.22), value: isSelected)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SimpleProgressBar: View {
    let fraction: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, fraction))))
            }
            .cornerRadius(4)
        }
        .frame(height: 6)
    }
}

struct StackedProgressBar: View {
    let segments: [ProgressSegment]
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    if segment.value > 0 {
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: geo.size.width * CGFloat(segment.value))
                    }
                }
            }
            .cornerRadius(6)
        }
        .frame(height: 10)
    }
}

struct ProgressSegment: Identifiable {
    let id = UUID()
    let name: String
    let value: Double // Fraction (0 to 1)
    let color: Color
    let size: Int64
    
    var formattedSize: String {
        return size.formattedStorageSize()
    }
}

// MARK: - Helper Layout Functions

extension DropdownView {
    
    private func calculateSegments(for drive: DriveInfo, breakdown: StorageBreakdown) -> [ProgressSegment] {
        let total = drive.totalSpace
        let free = drive.freeSpace
        let used = drive.usedSpace
        
        let appsSpace = breakdown.appsSize
        let developerSpace = breakdown.developerSize
        let documentsSpace = breakdown.documentsSize
        let mediaSpace = breakdown.mediaSize
        
        // System and miscellaneous is anything left in used space
        let systemSpace = max(0, used - (appsSpace + developerSpace + documentsSpace + mediaSpace))
        
        func fraction(_ val: Int64) -> Double {
            guard total > 0 else { return 0 }
            return Double(val) / Double(total)
        }
        
        return [
            ProgressSegment(name: "Applications", value: fraction(appsSpace), color: .blue, size: appsSpace),
            ProgressSegment(name: "Developer", value: fraction(developerSpace), color: .purple, size: developerSpace),
            ProgressSegment(name: "Documents", value: fraction(documentsSpace), color: .orange, size: documentsSpace),
            ProgressSegment(name: "Media", value: fraction(mediaSpace), color: .teal, size: mediaSpace),
            ProgressSegment(name: "System / Other", value: fraction(systemSpace), color: .gray, size: systemSpace),
            ProgressSegment(name: "Free Space", value: fraction(free), color: .secondary.opacity(0.15), size: free)
        ]
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Custom Commands Section
    private var customCommandsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Add/Edit Command Form
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(editingCommand == nil ? "Add Terminal Command" : "Edit Terminal Command")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if isAddFormExpanded {
                                // Collapse and reset input
                                editingCommand = nil
                                newCommandName = ""
                                newCommandString = ""
                                newCommandFolder = ""
                                newCommandTag = ""
                            }
                            isAddFormExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isAddFormExpanded ? "minus.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if isAddFormExpanded {
                    VStack(spacing: 8) {
                        TextField("Command Name (e.g. Brew Update)", text: $newCommandName)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                        
                        TextField("Terminal Command (e.g. brew update)", text: $newCommandString)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 11, design: .monospaced))
                            
                        HStack(spacing: 6) {
                            TextField("Folder Name (Optional)", text: $newCommandFolder)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                            
                            let folderTree = viewModel.getCommandFolderTree()
                            let formattedFolders = viewModel.getFormattedFolderPaths(folderTree)
                            if !formattedFolders.isEmpty {
                                Menu {
                                    ForEach(formattedFolders, id: \.path) { item in
                                        Button(item.label) {
                                            newCommandFolder = item.path
                                        }
                                    }
                                } label: {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 11))
                                        .foregroundColor(.purple)
                                        .padding(8)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(6)
                                }
                                .menuStyle(.button)
                                .help("Choose from existing folders")
                            }
                        }

                        TextField("Window Tag / Group (Optional)", text: $newCommandTag)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                        
                        Toggle(isOn: $newCommandRunSilent) {
                            HStack(spacing: 5) {
                                Image(systemName: "speaker.slash.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                Text("Run in Silent Mode (Background execution)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.top, 2)
                        .help("Executes script silently in the background without opening Terminal.app")
                    }
                    .padding(.top, 4)
                    
                    HStack(spacing: 8) {
                        if editingCommand != nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    newCommandName = ""
                                    newCommandString = ""
                                    newCommandFolder = ""
                                    newCommandTag = ""
                                    newCommandRunSilent = false
                                    editingCommand = nil
                                    isAddFormExpanded = false
                                }
                            }) {
                                Text("Cancel")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            if let cmd = editingCommand {
                                viewModel.updateCustomCommand(id: cmd.id, name: newCommandName, command: newCommandString, folder: newCommandFolder, tag: newCommandTag, runSilent: newCommandRunSilent)
                            } else {
                                viewModel.addCustomCommand(name: newCommandName, command: newCommandString, folder: newCommandFolder, tag: newCommandTag, runSilent: newCommandRunSilent)
                            }
                            newCommandName = ""
                            newCommandString = ""
                            newCommandFolder = ""
                            newCommandTag = ""
                            newCommandRunSilent = false
                            editingCommand = nil
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAddFormExpanded = false
                            }
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: editingCommand == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(editingCommand == nil ? "Add Command" : "Save Changes")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .background(newCommandName.isEmpty || newCommandString.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(newCommandName.isEmpty || newCommandString.isEmpty)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            
            // Saved Commands list
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Saved Commands")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                    
                    Spacer()
                    
                    if !viewModel.customCommands.isEmpty {
                        let allCommandFolderPaths = getAllFolderPaths(from: viewModel.getCommandFolderTree())
                        let areAllCommandFoldersCollapsed = !allCommandFolderPaths.isEmpty && allCommandFolderPaths.allSatisfy { collapsedFolders.contains($0) }
                        
                        if !allCommandFolderPaths.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if areAllCommandFoldersCollapsed {
                                        collapsedFolders.removeAll()
                                    } else {
                                        collapsedFolders = Set(allCommandFolderPaths)
                                    }
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: areAllCommandFoldersCollapsed ? "chevron.down.circle" : "chevron.up.circle")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(areAllCommandFoldersCollapsed ? "Expand All" : "Collapse")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help(areAllCommandFoldersCollapsed ? "Expand all folders" : "Collapse all folders")
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCommandSortActive.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isCommandSortActive ? "checkmark.circle.fill" : "arrow.up.arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text(isCommandSortActive ? "Done" : "Sort")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(isCommandSortActive ? Color.blue : Color.white.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            viewModel.stopAllRunningCommands()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.octagon.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Stop All")
                                        .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Stop all commands running in Terminal by sending Ctrl+C multiple times")
                    }
                }
                
                if viewModel.customCommands.isEmpty {
                    HStack {
                        Spacer()
                        Text("No commands configured yet. Add one above!")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 24)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(10)
                } else {
                    let folderTree = viewModel.getCommandFolderTree()
                    let uncategorized = viewModel.customCommands.filter { $0.folder == nil || $0.folder?.isEmpty == true }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Uncategorized Saved Commands
                        if !uncategorized.isEmpty {
                            VStack(spacing: 6) {
                                ForEach(uncategorized) { cmd in
                                    commandRow(for: cmd)
                                }
                            }
                        }
                        
                        // Folder Tree Groupings
                        ForEach(folderTree) { rootNode in
                            CommandFolderNodeView(
                                viewModel: viewModel,
                                node: rootNode,
                                level: 0,
                                collapsedFolders: $collapsedFolders,
                                isCommandSortActive: isCommandSortActive,
                                onDeleteFolder: { path in
                                    folderToDelete = path
                                    isDeletingCommandFolder = true
                                    showDeleteFolderDialog = true
                                },
                                commandRowBuilder: { cmd in
                                    commandRow(for: cmd)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Command Row Builder Helper
    private func commandRow(for cmd: TerminalCommand) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cmd.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if let tag = cmd.tag, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 7))
                                Text(tag.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        }
                        
                        if cmd.runSilent == true {
                            HStack(spacing: 2) {
                                Image(systemName: "speaker.slash.fill")
                                    .font(.system(size: 7))
                                Text("Silent")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.18))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                            .help("Executes silently in the background without launching Terminal")
                        }
                    }
                    Text(cmd.command)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .background(Color.white.opacity(0.001))
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.runCustomCommand(cmd)
            }
            
            if isCommandSortActive {
                let groupCmds = viewModel.customCommands.filter { $0.folder == cmd.folder }
                let cmdIdx = groupCmds.firstIndex(where: { $0.id == cmd.id }) ?? 0
                
                HStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.moveCommandUp(id: cmd.id)
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(cmdIdx > 0 ? .white : .secondary.opacity(0.3))
                            .padding(4)
                            .background(Color.white.opacity(cmdIdx > 0 ? 0.1 : 0.02))
                            .cornerRadius(4)
                    }
                    .disabled(cmdIdx == 0)
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.moveCommandDown(id: cmd.id)
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(cmdIdx < groupCmds.count - 1 ? .white : .secondary.opacity(0.3))
                            .padding(4)
                            .background(Color.white.opacity(cmdIdx < groupCmds.count - 1 ? 0.1 : 0.02))
                            .cornerRadius(4)
                    }
                    .disabled(cmdIdx == groupCmds.count - 1)
                    .buttonStyle(.plain)
                }
            }
            
            if viewModel.runningCommandIds.contains(cmd.id) {
                Button(action: {
                    viewModel.stopCustomCommand(id: cmd.id)
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Stop this running command")
            }
            
            // Edit Command Button
            Button(action: {
                editingCommand = cmd
                newCommandName = cmd.name
                newCommandString = cmd.command
                newCommandFolder = cmd.folder ?? ""
                newCommandTag = cmd.tag ?? ""
                newCommandRunSilent = cmd.runSilent ?? false
                withAnimation(.easeInOut(duration: 0.25)) {
                    isAddFormExpanded = true
                }
            }) {
                Image(systemName: "pencil.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Edit command")
            
            // Delete Command Button
            Button(action: {
                commandToDelete = cmd
                showDeleteConfirmation = true
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete command")
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
    
    // Quick Notes Section Builder
    private var quickNotesSection: some View {
        Group {
            if editingNote != nil || isCreatingFullNote {
                fullWindowNoteView
            } else {
                quickNotesListView
            }
        }
    }
    
    // Full Window Note View (Creation & Viewing/Editing)
    private var fullWindowNoteView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full Window Top Navigation & Control Toolbar
            HStack(spacing: 6) {
                // Smaller Icon-only Back Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editingNote = nil
                        isCreatingFullNote = false
                        isNoteEditingMode = false
                        newNoteTitle = ""
                        newNoteContent = ""
                        newNoteFolder = ""
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Back to Notes list")
                
                if !isCreatingFullNote && !isNoteEditingMode {
                    // READ-ONLY VIEWING MODE: Title + Folder Tag on Top Same Line
                    HStack(spacing: 6) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(newNoteTitle.isEmpty ? "Untitled Note" : newNoteTitle)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        if !newNoteFolder.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 9))
                                Text(newNoteFolder)
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.orange.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(4)
                            .fixedSize()
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                if let note = editingNote {
                    // Copy Content Button
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(newNoteContent, forType: .string)
                        withAnimation {
                            copiedNoteId = note.id
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                if copiedNoteId == note.id { copiedNoteId = nil }
                            }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copiedNoteId == note.id ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 10, weight: .bold))
                            if copiedNoteId == note.id {
                                Text("Copied")
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(copiedNoteId == note.id ? .green : .white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 7)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Copy note text")
                    
                    // Delete Note Button
                    Button(action: {
                        noteToDelete = note
                        showNoteDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(6)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Delete note")
                    
                    if !isNoteEditingMode {
                        // EDIT BUTTON (Icon-only compact mode)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNoteEditingMode = true
                            }
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Edit note")
                    } else {
                        // SAVE BUTTON (When in Editing Mode)
                        Button(action: {
                            viewModel.updateQuickNote(id: note.id, title: newNoteTitle, content: newNoteContent, folder: newNoteFolder)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNoteEditingMode = false
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Save")
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 9)
                            .background(newNoteTitle.isEmpty || newNoteContent.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .disabled(newNoteTitle.isEmpty || newNoteContent.isEmpty)
                    }
                } else if isCreatingFullNote {
                    // CREATE BUTTON (When creating a new note)
                    Button(action: {
                        viewModel.addQuickNote(title: newNoteTitle, content: newNoteContent, folder: newNoteFolder)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            editingNote = nil
                            isCreatingFullNote = false
                            isNoteEditingMode = false
                            newNoteTitle = ""
                            newNoteContent = ""
                            newNoteFolder = ""
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Create")
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 9)
                        .background(newNoteTitle.isEmpty || newNoteContent.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .disabled(newNoteTitle.isEmpty || newNoteContent.isEmpty)
                }
            }
            
            // Editable Title & Folder Inputs (Shown ONLY in Edit / Create Mode)
            if isCreatingFullNote || isNoteEditingMode {
                VStack(spacing: 6) {
                    TextField("Note Title...", text: $newNoteTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundColor(.orange.opacity(0.8))
                        
                        TextField("Folder / Subfolder (e.g. Work/Projects)", text: $newNoteFolder)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                        
                        let folderTree = viewModel.getNoteFolderTree()
                        let formattedFolders = viewModel.getFormattedFolderPaths(folderTree)
                        if !formattedFolders.isEmpty {
                            Menu {
                                ForEach(formattedFolders, id: \.path) { item in
                                    Button(item.label) {
                                        newNoteFolder = item.path
                                    }
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 9))
                                    Text("Select")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.orange)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(5)
                            }
                            .menuStyle(.button)
                            .fixedSize()
                            .help("Choose from existing folders")
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                }
            }
            
            // Full Window Text Content / Editor Area (High performance viewport rendering for huge notes)
            if isCreatingFullNote || isNoteEditingMode {
                // EDITABLE MODE: Full TextEditor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $newNoteContent)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    
                    if newNoteContent.isEmpty {
                        Text("Write your note content here...")
                            .foregroundColor(.white.opacity(0.35))
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                // READ-ONLY VIEWING MODE: Smooth native scrolling, selection & 0ms load time for huge files!
                ZStack(alignment: .topLeading) {
                    ReadOnlyNoteTextView(text: newNoteContent)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    
                    if newNoteContent.isEmpty {
                        Text("No content in this note.")
                            .foregroundColor(.white.opacity(0.35))
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Saved Notes List Overview View
    private var quickNotesListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar: "Quick Notes" + "+ Add Note" button
            HStack {
                Text("Saved Notes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
                
                Spacer()
                
                // "+ Add Note" Button (Full Window Mode Trigger)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editingNote = nil
                        newNoteTitle = ""
                        newNoteContent = ""
                        newNoteFolder = ""
                        isCreatingFullNote = true
                        isNoteEditingMode = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Note")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Search / Filter & Sort Controls
            if !viewModel.quickNotes.isEmpty {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        TextField("Filter notes...", text: $noteSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                        if !noteSearchQuery.isEmpty {
                            Button(action: { noteSearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    
                    Spacer()
                    
                    let allNoteFolderPaths = getAllFolderPaths(from: viewModel.getNoteFolderTree())
                    let areAllNoteFoldersCollapsed = !allNoteFolderPaths.isEmpty && allNoteFolderPaths.allSatisfy { collapsedNotesFolders.contains($0) }
                    
                    if !allNoteFolderPaths.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if areAllNoteFoldersCollapsed {
                                    collapsedNotesFolders.removeAll()
                                } else {
                                    collapsedNotesFolders = Set(allNoteFolderPaths)
                                }
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: areAllNoteFoldersCollapsed ? "chevron.down.circle" : "chevron.up.circle")
                                    .font(.system(size: 9, weight: .bold))
                                Text(areAllNoteFoldersCollapsed ? "Expand" : "Collapse")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isNoteSortActive.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isNoteSortActive ? "checkmark.circle.fill" : "arrow.up.arrow.down")
                                .font(.system(size: 9, weight: .bold))
                            Text(isNoteSortActive ? "Done" : "Sort")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(isNoteSortActive ? Color.blue : Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Notes List Content
            if viewModel.quickNotes.isEmpty {
                HStack {
                    Spacer()
                    Text("No notes saved yet. Click '+ Add Note' above!")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color.white.opacity(0.02))
                .cornerRadius(10)
            } else {
                let filteredNotes = noteSearchQuery.isEmpty ? viewModel.quickNotes : viewModel.quickNotes.filter {
                    $0.title.localizedCaseInsensitiveContains(noteSearchQuery) ||
                    $0.content.localizedCaseInsensitiveContains(noteSearchQuery) ||
                    ($0.folder?.localizedCaseInsensitiveContains(noteSearchQuery) ?? false)
                }
                
                if filteredNotes.isEmpty {
                    HStack {
                        Spacer()
                        Text("No matching notes found.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    let folderTree = viewModel.getNoteFolderTree()
                    let uncategorized = filteredNotes.filter { $0.folder == nil || $0.folder?.isEmpty == true }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Uncategorized Notes
                        if !uncategorized.isEmpty {
                            VStack(spacing: 6) {
                                ForEach(uncategorized) { note in
                                    noteRow(for: note)
                                }
                            }
                        }
                        
                        // Folder Tree Groupings
                        ForEach(folderTree) { rootNode in
                            NoteFolderNodeView(
                                viewModel: viewModel,
                                node: rootNode,
                                level: 0,
                                collapsedNotesFolders: $collapsedNotesFolders,
                                isNoteSortActive: isNoteSortActive,
                                onDeleteFolder: { path in
                                    folderToDelete = path
                                    isDeletingCommandFolder = false
                                    showDeleteFolderDialog = true
                                },
                                noteRowBuilder: { note in
                                    noteRow(for: note)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Note Row Builder Helper (Compact List Row)
    private func noteRow(for note: QuickNote) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                editingNote = note
                newNoteTitle = note.title
                newNoteContent = note.content
                newNoteFolder = note.folder ?? ""
                isCreatingFullNote = false
                isNoteEditingMode = false
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue.opacity(0.85))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(note.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if let folder = note.folder, !folder.isEmpty {
                                Text(folder)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.orange.opacity(0.9))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(note.dateCreated.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 6) {
                if isNoteSortActive {
                    let groupNotes = viewModel.quickNotes.filter { $0.folder == note.folder }
                    let noteIdx = groupNotes.firstIndex(where: { $0.id == note.id }) ?? 0
                    
                    HStack(spacing: 2) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.moveNoteUp(id: note.id)
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(noteIdx > 0 ? .white : .secondary.opacity(0.3))
                                .padding(4)
                                .background(Color.white.opacity(noteIdx > 0 ? 0.1 : 0.02))
                                .cornerRadius(4)
                        }
                        .disabled(noteIdx == 0)
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.moveNoteDown(id: note.id)
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(noteIdx < groupNotes.count - 1 ? .white : .secondary.opacity(0.3))
                                .padding(4)
                                .background(Color.white.opacity(noteIdx < groupNotes.count - 1 ? 0.1 : 0.02))
                                .cornerRadius(4)
                        }
                        .disabled(noteIdx == groupNotes.count - 1)
                        .buttonStyle(.plain)
                    }
                }
                
                // Direct Copy Button (Copies note content directly to clipboard with visual feedback)
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(note.content, forType: .string)
                    withAnimation {
                        copiedNoteId = note.id
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            if copiedNoteId == note.id {
                                copiedNoteId = nil
                            }
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copiedNoteId == note.id ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(copiedNoteId == note.id ? .green : .blue.opacity(0.85))
                        if copiedNoteId == note.id {
                            Text("Copied")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Copy content to clipboard")
                
                // Delete Note Button
                Button(action: {
                    noteToDelete = note
                    showNoteDeleteConfirmation = true
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - AI Chat UI Section
    
    /// Extracted thread picker menu to avoid SwiftUI type-checker timeout from inline 'let' bindings
    @ViewBuilder private var threadMenuContent: some View {
        let uncategorized = viewModel.chatThreads.filter { $0.folder == nil || $0.folder?.isEmpty == true }
        ForEach(uncategorized) { thread in
            Button(action: { viewModel.selectChatThread(id: thread.id) }) {
                HStack {
                    Text(thread.title)
                    if thread.id == viewModel.selectedThreadId { Image(systemName: "checkmark") }
                }
            }
        }
        let folders = Array(Set(viewModel.chatThreads.compactMap { $0.folder })).sorted()
        if !folders.isEmpty { Divider() }
        ForEach(folders, id: \.self) { folder in
            let folderThreads = viewModel.chatThreads.filter { $0.folder == folder }
            Menu(folder) {
                ForEach(folderThreads) { thread in
                    Button(action: { viewModel.selectChatThread(id: thread.id) }) {
                        HStack {
                            Text(thread.title)
                            if thread.id == viewModel.selectedThreadId { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }
        Divider()
        Button(action: { viewModel.createNewChatThread() }) {
            Label("New Chat", systemImage: "plus")
        }
    }
    
    private var aiChatSection: some View {
        VStack(spacing: 8) {
            // Thread Selection Control & Model Selection
            HStack(spacing: 6) {
                Menu {
                    threadMenuContent
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 10))
                        Text(viewModel.selectedThread?.title ?? "No Chat Selected")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .menuStyle(.button)
                
                Menu {
                    // Actions on current selected model
                    if !viewModel.selectedModel.isEmpty {
                        let isFav = viewModel.favoriteModels.contains(viewModel.selectedModel)
                        Button(action: {
                            viewModel.toggleFavorite(viewModel.selectedModel)
                        }) {
                            Label(isFav ? "Remove Current from Favorites" : "Add Current to Favorites", systemImage: isFav ? "star.slash" : "star")
                        }
                    }
                    
                    Button(action: {
                        showAllModels.toggle()
                    }) {
                        Label(showAllModels ? "Show Favorites Only" : "See All Models", systemImage: showAllModels ? "star.circle" : "list.bullet")
                    }
                    
                    Divider()
                    
                    if showAllModels {
                        let providers = Array(Set(viewModel.availableModels.compactMap { $0.components(separatedBy: "/").first })).sorted()
                        if providers.isEmpty {
                            Button("No Models Found") {}
                                .disabled(true)
                        } else {
                            ForEach(providers, id: \.self) { provider in
                                Section(header: Text(provider)) {
                                    let providerModels = viewModel.availableModels.filter { $0.hasPrefix(provider + "/") }
                                    ForEach(providerModels, id: \.self) { model in
                                        let isFav = viewModel.favoriteModels.contains(model)
                                        Button(action: {
                                            viewModel.changeSelectedModel(model)
                                        }) {
                                            HStack {
                                                Text(model.components(separatedBy: "/").last ?? model)
                                                if isFav {
                                                    Image(systemName: "star.fill")
                                                }
                                                if model == viewModel.selectedModel {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Favorites section (default view)
                        if viewModel.favoriteModels.isEmpty {
                            Button("No Favorite Models") {}
                                .disabled(true)
                        } else {
                            Section("Favorite Models") {
                                ForEach(viewModel.favoriteModels, id: \.self) { model in
                                    Button(action: {
                                        viewModel.changeSelectedModel(model)
                                    }) {
                                        HStack {
                                            Text(model.components(separatedBy: "/").last ?? model)
                                            if model == viewModel.selectedModel {
                                                Image(systemName: "checkmark")
                                            }
                                            Image(systemName: "star.fill")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
                .menuStyle(.button)
                
                Spacer()
                
                HStack(spacing: 6) {
                    // Attachment Icon Button (Paperclip)
                    let attachments = viewModel.selectedThread?.allAttachments ?? []
                    let hasAttachment = !attachments.isEmpty
                    HStack(spacing: 0) {
                        Button(action: {
                            viewModel.selectDirectoryForActiveThread()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: hasAttachment ? "paperclip.circle.fill" : "paperclip")
                                    .font(.system(size: 10))
                                    .foregroundColor(hasAttachment ? .yellow : .blue)
                                if attachments.count > 1 {
                                    Text("\(attachments.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .help(hasAttachment ? "\(attachments.count) attached item(s) (Click to add more)" : "Attach file/folder context for AI")
                        
                        if hasAttachment {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 1, height: 12)
                            
                            Button(action: {
                                if attachments.count == 1 {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.detachDirectoryFromActiveThread()
                                    }
                                } else {
                                    showRemoveAttachmentPopover = true
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red.opacity(0.85))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .help(attachments.count == 1 ? "Remove attached AI context" : "Manage and remove attached AI context items")
                            .transition(.scale.combined(with: .opacity))
                            .popover(isPresented: $showRemoveAttachmentPopover, arrowEdge: .bottom) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Attached Context Items")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    
                                    Divider()
                                    
                                    ForEach(attachments, id: \.self) { path in
                                        HStack(spacing: 6) {
                                            Image(systemName: (try? FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType == .typeDirectory) ?? false ? "folder.fill" : "doc.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.yellow)
                                            
                                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                                .font(.system(size: 11))
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                viewModel.removeSpecificAttachmentFromActiveThread(path)
                                                if (viewModel.selectedThread?.allAttachments.isEmpty ?? true) {
                                                    showRemoveAttachmentPopover = false
                                                }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.red.opacity(0.8))
                                            }
                                            .buttonStyle(.plain)
                                            .help("Remove \(URL(fileURLWithPath: path).lastPathComponent)")
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        viewModel.detachDirectoryFromActiveThread()
                                        showRemoveAttachmentPopover = false
                                    }) {
                                        HStack {
                                            Image(systemName: "trash")
                                                .font(.system(size: 9))
                                            Text("Remove All")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(10)
                                .frame(width: 220)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    
                    // System Actions Toggle Button
                    Button(action: {
                        viewModel.allowAiSystemActions.toggle()
                        UserDefaults.standard.set(viewModel.allowAiSystemActions, forKey: "AIAllowSystemActions")
                    }) {
                        Image(systemName: viewModel.allowAiSystemActions ? "shield.slash.fill" : "shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.allowAiSystemActions ? .red : .green)
                            .padding(6)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.allowAiSystemActions ? "System Actions: Allowed (Dangerous)" : "System Actions: Blocked (Safe)")
                    
                    // Open in Terminal Button
                    Button(action: {
                        viewModel.openActiveThreadInTerminal()
                    }) {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Continue this chat session interactively in macOS Terminal")
                    
                    // Edit Thread details button
                    if let selectedId = viewModel.selectedThreadId {
                        Button(action: {
                            if let thread = viewModel.selectedThread {
                                newThreadTitleInput = thread.title
                                newThreadFolderInput = thread.folder ?? ""
                                isChatInputFocused = false
                                showEditThreadDialog = true
                            }
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Rename or move this chat thread")
                        .popover(isPresented: $showEditThreadDialog, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Edit Chat Thread")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                
                                TextField("Thread Title", text: $newThreadTitleInput)
                                    .textFieldStyle(.plain)
                                    .padding(6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(4)
                                    .font(.system(size: 11))
                                
                                TextField("Folder (Optional)", text: $newThreadFolderInput)
                                    .textFieldStyle(.plain)
                                    .padding(6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(4)
                                    .font(.system(size: 11))
                                
                                HStack {
                                    Button("Cancel") {
                                        showEditThreadDialog = false
                                        isChatInputFocused = true
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption2)
                                    
                                    Spacer()
                                    
                                    Button("Save") {
                                        viewModel.updateChatThread(id: selectedId, title: newThreadTitleInput, folder: newThreadFolderInput)
                                        showEditThreadDialog = false
                                        isChatInputFocused = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.caption2)
                                    .disabled(newThreadTitleInput.isEmpty)
                                }
                            }
                            .padding(10)
                            .frame(width: 180)
                        }
                    }
                    
                    // Delete Active Thread Button
                    if let selectedId = viewModel.selectedThreadId {
                        Button(action: {
                            viewModel.deleteChatThread(id: selectedId)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(6)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Delete this chat thread")
                    }
                }
            }
            .padding(.bottom, 4)
            
            let messages = viewModel.selectedThread?.messages ?? []
            
            // Chat history area
            if messages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue.opacity(0.8))
                    Text("Chat with AI")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("This interface runs your queries through multi-agent CLI engines (opencode, codex, antigravity) on your Mac.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    let activeModel = viewModel.selectedModel
                    let isCodexSelected = activeModel.hasPrefix("codex/") || activeModel == "codex"
                    let isAntigravitySelected = activeModel.hasPrefix("antigravity/") || activeModel == "antigravity"
                    let isOpencodeSelected = activeModel.hasPrefix("opencode/") || activeModel == "opencode"
                    
                    let isMissingSelectedCLI = (isCodexSelected && !viewModel.isCodexInstalled) ||
                                              (isAntigravitySelected && !viewModel.isAntigravityInstalled) ||
                                              (isOpencodeSelected && !viewModel.isOpencodeInstalled)
                    
                    if isMissingSelectedCLI {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 10))
                                Text(isCodexSelected ? "codex CLI not detected" : (isAntigravitySelected ? "antigravity CLI not detected" : "opencode CLI not detected"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                            Text("To query models with this provider, install the CLI agent by running:")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.8))
                            Text(isCodexSelected ? "npm i -g @openai/codex-cli" : (isAntigravitySelected ? "curl -sSL https://antigravity.ai/install.sh" : "brew install opencode"))
                                .font(.system(size: 9, design: .monospaced))
                                .padding(4)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                                .foregroundColor(.blue)
                        }
                        .padding(10)
                        .background(Color.yellow.opacity(0.08))
                        .cornerRadius(8)
                        .padding(.top, 10)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                // Messages log
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 10) {
                            ForEach(messages) { msg in
                                ChatBubble(message: msg) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(msg.text, forType: .string)
                                }
                                .id(msg.id)
                            }
                            
                            // Add a loading bubble if responding
                            if viewModel.isAiResponding {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            DotLoadingView()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(8)
                                    }
                                    Spacer()
                                }
                                .id("loading_bubble")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: .infinity)
                    .onChange(of: viewModel.selectedThread?.messages) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isAiResponding) { newValue in
                        if newValue {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            
            // Visual Attachment Chips Bar
            let currentAttachments = viewModel.selectedThread?.allAttachments ?? []
            if !currentAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(currentAttachments, id: \.self) { path in
                            HStack(spacing: 4) {
                                Image(systemName: (try? FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType == .typeDirectory) ?? false ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow)
                                
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.removeSpecificAttachmentFromActiveThread(path)
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Remove \(URL(fileURLWithPath: path).lastPathComponent)")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.12))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.yellow.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 22)
            }
            
            // Input Bar & Stop Control
            HStack(spacing: 8) {
                MacChatInputTextView(
                    text: $chatInputText,
                    isFocused: $isChatInputFocused,
                    isDisabled: viewModel.isAiResponding,
                    isPopoverActive: showEditThreadDialog,
                    onCommit: {
                        submitChatMessage()
                    }
                )
                .frame(height: 32)
                .padding(.horizontal, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                
                if viewModel.isAiResponding {
                    // STOP AI Button
                    Button(action: {
                        viewModel.stopAiMessageQuery()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Stop AI")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Stop current AI generation")
                } else {
                    Button(action: {
                        submitChatMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                // Clear button (always available, but disabled if responding)
                if !messages.isEmpty && !viewModel.isAiResponding {
                    Button(action: {
                        viewModel.clearChatHistory()
                    }) {
                        Image(systemName: "clear")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.8))
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Clear active chat messages")
                }
            }
            .onChange(of: viewModel.isAiResponding) { isResponding in
                if !isResponding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isChatInputFocused = true
                    }
                }
            }
            .padding(.top, 4)
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isDraggingFolderOver) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        viewModel.attachDirectoryToActiveThread(url.path)
                    }
                }
            }
            return true
        }
        .overlay(dragFolderOverlayView)
        .animation(.easeInOut, value: isDraggingFolderOver)
    }
    
    @ViewBuilder
    private var dragFolderOverlayView: some View {
        if isDraggingFolderOver {
            ZStack {
                Color.blue.opacity(0.12)
                
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                    Text("Drop folder to attach context")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
            }
            .transition(.opacity)
        }
    }
    
    private func submitChatMessage() {
        let trimmed = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        viewModel.sendChatMessage(trimmed)
        
        // Clear input text and retain focus for next message
        DispatchQueue.main.async {
            self.chatInputText = ""
            self.isChatInputFocused = true
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                if viewModel.isAiResponding {
                    proxy.scrollTo("loading_bubble", anchor: .bottom)
                } else if let last = viewModel.selectedThread?.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Dot Loading View
struct DotLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Chat Bubble View
struct ChatBubble: View {
    let message: ChatMessage
    let onCopy: () -> Void
    @State private var showCopied = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.system(size: 11, design: message.isUser ? .default : .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(message.isUser ? Color.blue.opacity(0.65) : Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                
                HStack(spacing: 6) {
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        onCopy()
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    }) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 8))
                            .foregroundColor(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Nested Folder Tree View Helpers

private func getAllFolderPaths(from nodes: [FolderNode]) -> [String] {
    var result: [String] = []
    for n in nodes {
        result.append(n.fullPath)
        result.append(contentsOf: getAllFolderPaths(from: n.subfolders))
    }
    return result
}

struct CommandFolderNodeView<CommandRow: View>: View {
    @ObservedObject var viewModel: StorageViewModel
    let node: FolderNode
    let level: Int
    @Binding var collapsedFolders: Set<String>
    let isCommandSortActive: Bool
    let onDeleteFolder: (String) -> Void
    let commandRowBuilder: (TerminalCommand) -> CommandRow
    
    @State private var isDropTargeted = false

    var body: some View {
        let isCollapsed = collapsedFolders.contains(node.fullPath)
        let folderCmds = viewModel.customCommands.filter { $0.folder == node.fullPath }
        let totalCount = countTotalItems(node)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isCollapsed {
                            collapsedFolders.remove(node.fullPath)
                        } else {
                            collapsedFolders.insert(node.fullPath)
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow.opacity(0.85))
                        
                        Text(node.name)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(totalCount)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onDeleteFolder(node.fullPath)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete folder '\(node.name)'")
                
                if isCommandSortActive {
                    HStack(spacing: 2) {
                        if level > 0 {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.unnestCommandFolder(node.fullPath)
                                }
                            }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.yellow)
                                    .padding(4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Move out of parent folder")
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.moveCommandFolderUp(name: node.fullPath)
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.moveCommandFolderDown(name: node.fullPath)
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(isDropTargeted ? 0.15 : 0.02))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDropTargeted ? Color.blue : Color.clear, lineWidth: 1.5)
            )
            .onDrag {
                guard isCommandSortActive else { return NSItemProvider() }
                return NSItemProvider(object: node.fullPath as NSString)
            }
            .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
                guard isCommandSortActive else { return false }
                for provider in providers {
                    _ = provider.loadObject(ofClass: String.self) { sourcePath, _ in
                        if let sourcePath = sourcePath, sourcePath != node.fullPath {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.nestCommandFolder(sourcePath: sourcePath, targetParentPath: node.fullPath)
                                }
                            }
                        }
                    }
                }
                return true
            }
            
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(folderCmds) { cmd in
                        commandRowBuilder(cmd)
                    }
                    
                    ForEach(node.subfolders) { childNode in
                        CommandFolderNodeView(
                            viewModel: viewModel,
                            node: childNode,
                            level: level + 1,
                            collapsedFolders: $collapsedFolders,
                            isCommandSortActive: isCommandSortActive,
                            onDeleteFolder: onDeleteFolder,
                            commandRowBuilder: commandRowBuilder
                        )
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private func countTotalItems(_ n: FolderNode) -> Int {
        let direct = viewModel.customCommands.filter { $0.folder == n.fullPath }.count
        let sub = n.subfolders.reduce(0) { $0 + countTotalItems($1) }
        return direct + sub
    }
}

struct NoteFolderNodeView<NoteRow: View>: View {
    @ObservedObject var viewModel: StorageViewModel
    let node: FolderNode
    let level: Int
    @Binding var collapsedNotesFolders: Set<String>
    let isNoteSortActive: Bool
    let onDeleteFolder: (String) -> Void
    let noteRowBuilder: (QuickNote) -> NoteRow
    
    @State private var isDropTargeted = false

    var body: some View {
        let isCollapsed = collapsedNotesFolders.contains(node.fullPath)
        let folderNotes = viewModel.quickNotes.filter { $0.folder == node.fullPath }
        let totalCount = countTotalItems(node)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isCollapsed {
                            collapsedNotesFolders.remove(node.fullPath)
                        } else {
                            collapsedNotesFolders.insert(node.fullPath)
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.85))
                        
                        Text(node.name)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(totalCount)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onDeleteFolder(node.fullPath)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete folder '\(node.name)'")
                
                if isNoteSortActive {
                    HStack(spacing: 2) {
                        if level > 0 {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.unnestNoteFolder(node.fullPath)
                                }
                            }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Move out of parent folder")
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.moveNoteFolderUp(name: node.fullPath)
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.moveNoteFolderDown(name: node.fullPath)
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(isDropTargeted ? 0.15 : 0.02))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDropTargeted ? Color.blue : Color.clear, lineWidth: 1.5)
            )
            .onDrag {
                guard isNoteSortActive else { return NSItemProvider() }
                return NSItemProvider(object: node.fullPath as NSString)
            }
            .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
                guard isNoteSortActive else { return false }
                for provider in providers {
                    _ = provider.loadObject(ofClass: String.self) { sourcePath, _ in
                        if let sourcePath = sourcePath, sourcePath != node.fullPath {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.nestNoteFolder(sourcePath: sourcePath, targetParentPath: node.fullPath)
                                }
                            }
                        }
                    }
                }
                return true
            }
            
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(folderNotes) { note in
                        noteRowBuilder(note)
                    }
                    
                    ForEach(node.subfolders) { childNode in
                        NoteFolderNodeView(
                            viewModel: viewModel,
                            node: childNode,
                            level: level + 1,
                            collapsedNotesFolders: $collapsedNotesFolders,
                            isNoteSortActive: isNoteSortActive,
                            onDeleteFolder: onDeleteFolder,
                            noteRowBuilder: noteRowBuilder
                        )
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private func countTotalItems(_ n: FolderNode) -> Int {
        let direct = viewModel.quickNotes.filter { $0.folder == n.fullPath }.count
        let sub = n.subfolders.reduce(0) { $0 + countTotalItems($1) }
        return direct + sub
    }
}

// MARK: - Native Chat Input TextView (Shift+Enter support & focus retention)

struct MacChatInputTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var isDisabled: Bool
    var isPopoverActive: Bool = false
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = CommandTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 11.5)
        textView.textColor = NSColor.white
        textView.insertionPointColor = NSColor.white
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 7)
        textView.textContainer?.lineFragmentPadding = 0
        textView.onCommit = onCommit
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CommandTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        textView.isEditable = !isDisabled
        textView.onCommit = onCommit

        if isFocused && !isDisabled && !isPopoverActive {
            DispatchQueue.main.async {
                if let window = textView.window, window.firstResponder != textView {
                    window.makeFirstResponder(textView)
                }
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacChatInputTextView

        init(_ parent: MacChatInputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

class CommandTextView: NSTextView {
    var onCommit: (() -> Void)?

    override func doCommand(by aSelector: Selector) {
        if aSelector == #selector(insertNewline(_:)) {
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                super.insertNewline(self)
            } else {
                onCommit?()
            }
            return
        }
        super.doCommand(by: aSelector)
    }
}

// Native Read-Only Text View for High Performance Viewing & Scrolling of Large Notes
struct ReadOnlyNoteTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = NSColor.white
        textView.string = text
        textView.textContainerInset = NSSize(width: 4, height: 4)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
}
