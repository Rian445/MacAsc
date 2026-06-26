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
    @State private var collapsedFolders: Set<String> = []
    
    // Quick Notes State
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var isNoteFormExpanded = false
    @State private var editingNote: QuickNote? = nil
    @State private var noteToDelete: QuickNote? = nil
    @State private var showNoteDeleteConfirmation = false
    @State private var copiedNoteId: UUID? = nil

    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
                .opacity(0.3)
            
            // Top Tab Selector (segmented control)
            HStack(spacing: 4) {
                TabButton(title: "Disk Insight", isSelected: currentTopTab == 0) {
                    currentTopTab = 0
                }
                TabButton(title: "Custom Commands", isSelected: currentTopTab == 1) {
                    currentTopTab = 1
                }
                TabButton(title: "Quick Note", isSelected: currentTopTab == 2) {
                    currentTopTab = 2
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.25))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            // Content based on selected tab
            if currentTopTab == 0 {
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
            } else if currentTopTab == 1 {
                // Custom Terminal Commands View
                ScrollView(.vertical, showsIndicators: false) {
                    customCommandsSection
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.001))
                .contentShape(Rectangle())
            } else {
                // Quick Notes View
                ScrollView(.vertical, showsIndicators: false) {
                    quickNotesSection
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.001))
                .contentShape(Rectangle())
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
        .onAppear {
            viewModel.startMonitoringRunningCommands()
            viewModel.scanAppSelfSizes()
        }
        .onDisappear {
            viewModel.stopMonitoringRunningCommands()
        }
    }
}

// MARK: - Subviews

extension DropdownView {
    
    // Header
    private var headerView: some View {
        ZStack {
            // Left-aligned actions (Info button)
            HStack {
                Button(action: {
                    showAboutPopover.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("About Mac ASC")
                .popover(isPresented: $showAboutPopover, arrowEdge: .bottom) {
                    aboutMePanel
                }
                
                Spacer()
            }

            // Centered Title & Icon
            HStack(spacing: 6) {
                Image(systemName: "externaldrive")
                    .foregroundColor(.blue)
                    .font(.title3)
                
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

    // About Me Popover Panel
    private var aboutMePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 24, height: 24)
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
                Text("Version 1.0.0")
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
        HStack(spacing: 10) {
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
        }
        .padding(.vertical, 6)
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
        HStack(spacing: 10) {
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
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
        }
        .help("Double-click to reveal in Finder")
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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.001))
                )
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
                            
                        TextField("Folder Name (Optional)", text: $newCommandFolder)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12))

                        TextField("Window Tag / Group (Optional)", text: $newCommandTag)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12))
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
                                viewModel.updateCustomCommand(id: cmd.id, name: newCommandName, command: newCommandString, folder: newCommandFolder, tag: newCommandTag)
                            } else {
                                viewModel.addCustomCommand(name: newCommandName, command: newCommandString, folder: newCommandFolder, tag: newCommandTag)
                            }
                            newCommandName = ""
                            newCommandString = ""
                            newCommandFolder = ""
                            newCommandTag = ""
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
                    let folders = Array(Set(viewModel.customCommands.compactMap { $0.folder })).sorted()
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
                        
                        // Folder Groupings
                        ForEach(folders, id: \.self) { folder in
                            let folderCmds = viewModel.customCommands.filter { $0.folder == folder }
                            let isCollapsed = collapsedFolders.contains(folder)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isCollapsed {
                                            collapsedFolders.remove(folder)
                                        } else {
                                            collapsedFolders.insert(folder)
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
                                        
                                        Text(folder)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("\(folderCmds.count)")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(4)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if !isCollapsed {
                                    VStack(spacing: 6) {
                                        ForEach(folderCmds) { cmd in
                                            commandRow(for: cmd)
                                        }
                                    }
                                    .padding(.leading, 12)
                                }
                            }
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
        VStack(alignment: .leading, spacing: 14) {
            // Add/Edit Note Form
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(editingNote == nil ? "Add Quick Note" : "Edit Quick Note")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if isNoteFormExpanded {
                                // Collapse and reset input
                                editingNote = nil
                                newNoteTitle = ""
                                newNoteContent = ""
                            }
                            isNoteFormExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isNoteFormExpanded ? "minus.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if isNoteFormExpanded {
                    VStack(spacing: 8) {
                        TextField("Title (e.g. Snippet, Reminder)", text: $newNoteTitle)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $newNoteContent)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                                .frame(height: 70)
                            
                            if newNoteContent.isEmpty {
                                Text("Content / Text")
                                    .foregroundColor(.white.opacity(0.35))
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 7)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.top, 4)
                    
                    HStack(spacing: 8) {
                        if editingNote != nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    newNoteTitle = ""
                                    newNoteContent = ""
                                    editingNote = nil
                                    isNoteFormExpanded = false
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
                            if let note = editingNote {
                                viewModel.updateQuickNote(id: note.id, title: newNoteTitle, content: newNoteContent)
                            } else {
                                viewModel.addQuickNote(title: newNoteTitle, content: newNoteContent)
                            }
                            newNoteTitle = ""
                            newNoteContent = ""
                            editingNote = nil
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNoteFormExpanded = false
                            }
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: editingNote == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(editingNote == nil ? "Add Note" : "Save Changes")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .background(newNoteTitle.isEmpty || newNoteContent.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(newNoteTitle.isEmpty || newNoteContent.isEmpty)
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
            
            // Saved Notes List
            VStack(alignment: .leading, spacing: 10) {
                Text("Saved Notes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if viewModel.quickNotes.isEmpty {
                    HStack {
                        Spacer()
                        Text("No notes saved yet. Add one above!")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 24)
                        Spacer()
                    }
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(10)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.quickNotes) { note in
                            noteRow(for: note)
                        }
                    }
                }
            }
        }
    }
    
    // Note Row Builder Helper
    private func noteRow(for note: QuickNote) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(note.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Copy Content Button
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
                    Image(systemName: copiedNoteId == note.id ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(copiedNoteId == note.id ? .green : .blue.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Copy content to clipboard")
                
                // Edit Note Button
                Button(action: {
                    editingNote = note
                    newNoteTitle = note.title
                    newNoteContent = note.content
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isNoteFormExpanded = true
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Edit note")
                
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
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}
