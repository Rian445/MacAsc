import SwiftUI
import AppKit

@MainActor
class CropSelectionWindow: NSWindow {
    static var shared: CropSelectionWindow?
    
    static func show() {
        if shared == nil {
            shared = CropSelectionWindow()
        }
        shared?.makeKeyAndOrderFront(nil)
    }
    
    static func hide() {
        shared?.orderOut(nil)
    }
    
    static func getCropRect() -> CGRect? {
        return shared?.frame
    }
    
    private init() {
        // Default size: 800x500 centered on screen
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let width: CGFloat = 700
        let height: CGFloat = 450
        let x = screenRect.origin.x + (screenRect.width - width) / 2
        let y = screenRect.origin.y + (screenRect.height - height) / 2
        
        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.level = .statusBar
        self.backgroundColor = NSColor.black.withAlphaComponent(0.01) // Extremely transparent for drag region
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.minSize = NSSize(width: 200, height: 150)
        
        let contentView = NSHostingView(rootView: CropSelectionView())
        self.contentView = contentView
    }
}

struct CropSelectionView: View {
    var body: some View {
        ZStack {
            // Visual border indicating capture region
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.06)) // Subtle tint to see the crop area
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
            
            // Helpful overlay details
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.dashed.and.paperclip")
                            .font(.system(size: 10, weight: .bold))
                        Text("Selected Capture Area")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(6)
                    
                    Spacer()
                }
                .padding(10)
                
                Spacer()
                
                Text("Drag edges to resize • Drag center to move")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(12)
                    .padding(.bottom, 12)
            }
        }
    }
}
