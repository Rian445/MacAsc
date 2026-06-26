import SwiftUI
import AppKit

@MainActor
class KeyPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: KeyPanel
    private var viewModel: StorageViewModel
    
    init(viewModel: StorageViewModel) {
        self.viewModel = viewModel
        
        // Create the Status Item in the Menu Bar
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create the NSPanel (translucent dropdown window)
        self.popover = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 490),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.popover.isFloatingPanel = true
        self.popover.level = .statusBar
        self.popover.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.popover.backgroundColor = .clear
        self.popover.hasShadow = true
        self.popover.isMovable = false
        self.popover.isReleasedWhenClosed = false
        
        // Embed the SwiftUI view inside the NSPanel
        let contentView = NSHostingView(rootView: DropdownView(viewModel: viewModel))
        self.popover.contentView = contentView
        
        super.init()
        
        // Set the button icon after calling super.init() to allow self reference
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Storage Utility")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Observe when the window loses focus to dismiss it
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: self.popover
        )
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if self.popover.isVisible {
            self.popover.orderOut(nil)
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        guard let button = statusItem.button,
              let window = button.window else { return }
        
        // Get the frame of the status bar item in screen coordinates
        let buttonFrame = window.convertToScreen(button.frame)
        
        // Calculate the centered coordinates for the popover
        let popoverWidth = self.popover.frame.width
        let popoverHeight = self.popover.frame.height
        
        // Get screen bounds to prevent the window from spilling off the left/right screen edges
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonFrame.origin) }) ?? NSScreen.main {
            let screenWidth = screen.visibleFrame.width
            let screenOriginX = screen.visibleFrame.origin.x
            
            // Clamp x to stay within the screen boundaries
            let minX = screenOriginX + 10
            let maxX = screenOriginX + screenWidth - popoverWidth - 10
            let x = max(minX, min(maxX, buttonFrame.origin.x + (buttonFrame.width / 2) - (popoverWidth / 2)))
            let y = buttonFrame.origin.y - popoverHeight - 5
            
            self.popover.setFrameOrigin(NSPoint(x: x, y: y))
            self.popover.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func panelDidResignKey(_ notification: Notification) {
        // If the application is still active (e.g. displaying a confirmation dialog,
        // color picker, or open file panel), do not dismiss the popover.
        if NSApp.isActive {
            return
        }
        self.popover.orderOut(nil)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var viewModel = StorageViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(viewModel: viewModel)
    }
}

@main
struct MacStorageUtilityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // A dummy Settings scene so the app doesn't create any default window at launch
        Settings {
            EmptyView()
        }
    }
}
