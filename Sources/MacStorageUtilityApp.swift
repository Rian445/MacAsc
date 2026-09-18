import SwiftUI
import AppKit
import Combine
@preconcurrency import UserNotifications

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
    private var globalEventMonitor: Any?
    private var lastResignKeyCloseTime: TimeInterval = 0
    
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
            button.sendAction(on: [.leftMouseDown])
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
        hidePopover()
    }
    
    @objc func showPopoverNotification(_ notification: Notification) {
        showPopover()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        let now = ProcessInfo.processInfo.systemUptime
        if self.popover.isVisible {
            hidePopover()
        } else {
            // Guard against race condition on macOS 15+ / 27 where clicking the status item
            // causes the system menu bar to steal focus, triggering panelDidResignKey right
            // before button.action is received. If recently closed, keep it closed.
            if (now - lastResignKeyCloseTime) < 0.35 {
                return
            }
            showPopover()
        }
    }
    
    func hidePopover() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        self.popover.orderOut(nil)
        viewModel.stopMonitoringRunningCommands()
    }
    
    func showPopover() {
        guard let button = statusItem.button,
              let window = button.window else { return }
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        // Get the frame of the status bar item in screen coordinates
        let rectInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = window.convertToScreen(rectInWindow)
        
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
            
            // Add global monitor to catch outside clicks on other windows/apps/desktop
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self = self else { return }
                // If user clicked our menu bar status item, let togglePopover handle closing it
                if self.isMouseInStatusButton() {
                    return
                }
                self.hidePopover()
            }
        }
    }
    
    private func isMouseInStatusButton() -> Bool {
        guard let button = statusItem.button,
              let window = button.window else { return false }
        let mouseLocation = NSEvent.mouseLocation
        let rectInWindow = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(rectInWindow)
        return screenRect.insetBy(dx: -6, dy: -6).contains(mouseLocation)
    }
    
    @objc func panelDidResignKey(_ notification: Notification) {
        // If the user clicked on the menu bar status item button, let togglePopover handle the toggle
        if isMouseInStatusButton() {
            return
        }
        
        // If another window within the application became key (e.g. confirmation dialog,
        // color picker, or open file panel), do not dismiss the popover.
        if NSApp.isActive, let keyWindow = NSApp.keyWindow, keyWindow !== self.popover {
            return
        }
        
        lastResignKeyCloseTime = ProcessInfo.processInfo.systemUptime
        hidePopover()
    }
    
    deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusBarController: StatusBarController?
    var viewModel = StorageViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.viewModel.checkNotificationSettings()
                self?.viewModel.checkAndNotifyUpcomingEvents()
            }
        }
        statusBarController = StatusBarController(viewModel: viewModel)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "macasc" {
                let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value
                handleNotificationClick(eventIdString: idString)
            }
        }
    }
    
    // UNUserNotificationCenterDelegate: show banner in foreground
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // UNUserNotificationCenterDelegate: user clicked the notification banner!
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let eventIdString = response.notification.request.content.userInfo["eventId"] as? String
        DispatchQueue.main.async { [weak self] in
            self?.handleNotificationClick(eventIdString: eventIdString)
        }
        completionHandler()
    }
    
    private func handleNotificationClick(eventIdString: String?) {
        statusBarController?.showPopover()
        var eventUUID: UUID? = nil
        if let idString = eventIdString {
            eventUUID = UUID(uuidString: idString)
        }
        // Dispatch immediately and with a small delay to guarantee view subscription is active
        NotificationCenter.default.post(name: Notification.Name("OpenTimeTrackerTab"), object: eventUUID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: Notification.Name("OpenTimeTrackerTab"), object: eventUUID)
        }
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
