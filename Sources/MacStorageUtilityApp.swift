import SwiftUI
import AppKit
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: StorageViewModel) {
        self.viewModel = viewModel
        
        // Create the Status Item in the Menu Bar (placed right)
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
            button.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Mac ASC")
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopoverNotification(_:)),
            name: Notification.Name("ClosePopover"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPopoverNotification(_:)),
            name: Notification.Name("ShowPopover"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarIcon),
            name: Notification.Name("UpdateMenuBarIcon"),
            object: nil
        )
        
        updateMenuBarIcon()
        
        // Listen to isRecording changes to dynamically update icon
        viewModel.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }
    
    @objc func updateMenuBarIcon() {
        if let button = self.statusItem.button {
            let logoInfo: (name: String, ext: String)
            if viewModel.isRecording {
                logoInfo = viewModel.getRecordLogoFileInfo()
            } else {
                logoInfo = viewModel.getLogoFileInfo()
            }
            
            // Clean up any previously added animated views
            let animatedTag = 999
            button.subviews.first(where: { $0.tag == animatedTag })?.removeFromSuperview()
            button.image = nil
            
            let iconSize: CGFloat = 20
            
            if logoInfo.ext == "system" {
                if let image = NSImage(systemSymbolName: logoInfo.name, accessibilityDescription: "Mac ASC") {
                    image.size = NSSize(width: iconSize, height: iconSize)
                    button.image = image
                }
            } else if let path = Bundle.main.path(forResource: logoInfo.name, ofType: logoInfo.ext),
                      let image = NSImage(contentsOfFile: path) {
                image.size = NSSize(width: iconSize, height: iconSize)
                // Only the Fire active recording icon remains colored; others render as templates
                let isFire = (logoInfo.name == "icons8-fire-40.apng")
                image.isTemplate = !isFire
                
                if logoInfo.ext == "apng" {
                    let btnSize = button.frame.size
                    let x = (btnSize.width - iconSize) / 2
                    let y = (btnSize.height - iconSize) / 2
                    
                    let imageView = NSImageView(frame: NSRect(x: x, y: y, width: iconSize, height: iconSize))
                    imageView.tag = animatedTag
                    imageView.image = image
                    imageView.animates = true
                    imageView.imageScaling = .scaleProportionallyUpOrDown
                    imageView.unregisterDraggedTypes()
                    
                    button.addSubview(imageView)
                } else {
                    button.image = image
                }
            } else {
                if let image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Mac ASC") {
                    image.size = NSSize(width: iconSize, height: iconSize)
                    button.image = image
                }
            }
        }
    }
    
    @objc func closePopoverNotification(_ notification: Notification) {
        self.popover.orderOut(nil)
        viewModel.stopMonitoringRunningCommands()
    }
    
    @objc func showPopoverNotification(_ notification: Notification) {
        showPopover()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if self.popover.isVisible {
            self.popover.orderOut(nil)
            viewModel.stopMonitoringRunningCommands()
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
            
            viewModel.startMonitoringRunningCommands()
        }
    }
    
    @objc func panelDidResignKey(_ notification: Notification) {
        // If the application is still active (e.g. displaying a confirmation dialog,
        // color picker, or open file panel), do not dismiss the popover.
        if NSApp.isActive {
            return
        }
        self.popover.orderOut(nil)
        viewModel.stopMonitoringRunningCommands()
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
