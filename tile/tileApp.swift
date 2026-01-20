import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let leftHalf = Self("leftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    static let rightHalf = Self("rightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let topHalf = Self("topHalf", default: .init(.upArrow, modifiers: [.control, .option]))
    static let bottomHalf = Self("bottomHalf", default: .init(.downArrow, modifiers: [.control, .option]))
    static let maximize = Self("maximize", default: .init(.return, modifiers: [.control, .option]))
}

// MARK: - Direction

enum Direction {
    case left, right, up, down, maximize
}

// MARK: - Window Position

struct WindowPosition: Equatable {
    let origin: CGPoint
    let size: CGSize
    let screenIndex: Int

    func matches(_ other: WindowPosition, tolerance: CGFloat = 10) -> Bool {
        abs(origin.x - other.origin.x) < tolerance &&
        abs(origin.y - other.origin.y) < tolerance &&
        abs(size.width - other.size.width) < tolerance &&
        abs(size.height - other.size.height) < tolerance
    }

    /// Check if a window rect matches this position
    /// Uses tighter tolerance for origin (20px) and looser tolerance for size (100px)
    /// because some apps (like Xcode) have minimum sizes and don't resize perfectly
    func matchesRect(_ rect: CGRect, positionTolerance: CGFloat = 20, sizeTolerance: CGFloat = 100) -> Bool {
        abs(origin.x - rect.origin.x) < positionTolerance &&
        abs(origin.y - rect.origin.y) < positionTolerance &&
        abs(size.width - rect.size.width) < sizeTolerance &&
        abs(size.height - rect.size.height) < sizeTolerance
    }
}

// MARK: - Screen Grid

struct ScreenGrid {
    let screen: NSScreen
    let screenIndex: Int
    let frame: CGRect          // Cocoa coordinates (for internal use)
    let screenFrame: CGRect    // Screen coordinates (for matching with AX API)

    // Precomputed positions for this screen
    let leftHalf: WindowPosition
    let rightHalf: WindowPosition
    let topHalf: WindowPosition
    let bottomHalf: WindowPosition
    let leftThird: WindowPosition
    let centerThird: WindowPosition
    let rightThird: WindowPosition
    let leftTwoThirds: WindowPosition
    let rightTwoThirds: WindowPosition
    let topLeft: WindowPosition
    let topRight: WindowPosition
    let bottomLeft: WindowPosition
    let bottomRight: WindowPosition
    let full: WindowPosition

    // Convert Cocoa coordinates (origin bottom-left, Y up) to screen coordinates (origin top-left, Y down)
    private static func screenY(cocoaY: CGFloat, height: CGFloat) -> CGFloat {
        guard let primaryScreen = NSScreen.screens.first else { return cocoaY }
        return primaryScreen.frame.height - cocoaY - height
    }

    init(screen: NSScreen, index: Int) {
        self.screen = screen
        self.screenIndex = index
        self.frame = screen.visibleFrame

        // Store frame in screen coordinates for matching
        let screenY = ScreenGrid.screenY(cocoaY: screen.visibleFrame.origin.y, height: screen.visibleFrame.height)
        self.screenFrame = CGRect(origin: CGPoint(x: screen.visibleFrame.origin.x, y: screenY),
                                   size: screen.visibleFrame.size)

        let f = frame
        let w = f.width
        let h = f.height
        let x = f.origin.x
        let cocoaY = f.origin.y

        // Helper to create position with coordinate conversion
        func pos(_ originX: CGFloat, cocoaOriginY: CGFloat, width: CGFloat, height: CGFloat) -> WindowPosition {
            let screenOriginY = ScreenGrid.screenY(cocoaY: cocoaOriginY, height: height)
            return WindowPosition(origin: CGPoint(x: originX, y: screenOriginY), size: CGSize(width: width, height: height), screenIndex: index)
        }

        // Halves
        leftHalf = pos(x, cocoaOriginY: cocoaY, width: w/2, height: h)
        rightHalf = pos(x + w/2, cocoaOriginY: cocoaY, width: w/2, height: h)
        topHalf = pos(x, cocoaOriginY: cocoaY + h/2, width: w, height: h/2)
        bottomHalf = pos(x, cocoaOriginY: cocoaY, width: w, height: h/2)

        // Thirds
        leftThird = pos(x, cocoaOriginY: cocoaY, width: w/3, height: h)
        centerThird = pos(x + w/3, cocoaOriginY: cocoaY, width: w/3, height: h)
        rightThird = pos(x + 2*w/3, cocoaOriginY: cocoaY, width: w/3, height: h)
        leftTwoThirds = pos(x, cocoaOriginY: cocoaY, width: 2*w/3, height: h)
        rightTwoThirds = pos(x + w/3, cocoaOriginY: cocoaY, width: 2*w/3, height: h)

        // Quarters
        topLeft = pos(x, cocoaOriginY: cocoaY + h/2, width: w/2, height: h/2)
        topRight = pos(x + w/2, cocoaOriginY: cocoaY + h/2, width: w/2, height: h/2)
        bottomLeft = pos(x, cocoaOriginY: cocoaY, width: w/2, height: h/2)
        bottomRight = pos(x + w/2, cocoaOriginY: cocoaY, width: w/2, height: h/2)

        // Full
        full = pos(x, cocoaOriginY: cocoaY, width: w, height: h)
    }
}

// MARK: - Window Mover

final class WindowMover {
    static let shared = WindowMover()

    private var grids: [ScreenGrid] = []

    /// Cached sorted positions per direction (computed once in rebuildGrids)
    private struct PositionCache {
        var left: [WindowPosition] = []
        var right: [WindowPosition] = []
        var up: [WindowPosition] = []
        var down: [WindowPosition] = []
        var maximize: [WindowPosition] = []
    }
    private var cache = PositionCache()

    /// Track last applied position for each window: [windowID: (direction, positionIndex)]
    private var windowHistory: [String: (direction: Direction, index: Int)] = [:]

    init() {
        rebuildGrids()

        // Observe screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildGrids),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc func rebuildGrids() {
        grids = NSScreen.screens.enumerated().map { ScreenGrid(screen: $1, index: $0) }
        windowHistory.removeAll()

        // Precompute and cache sorted position arrays
        let halves = grids.flatMap { [$0.leftHalf, $0.rightHalf] }
        cache.left  = halves.sorted { $0.origin.x > $1.origin.x }
        cache.right = halves.sorted { $0.origin.x < $1.origin.x }

        let verticals = grids.flatMap { [$0.topHalf, $0.bottomHalf] }
        cache.up   = verticals.sorted { $0.origin.y < $1.origin.y }
        cache.down = verticals.sorted { $0.origin.y > $1.origin.y }

        cache.maximize = grids.sorted { $0.frame.origin.x < $1.frame.origin.x }.map { $0.full }
    }

    /// Get a unique identifier for a window using pid + window number (stable)
    /// Falls back to title if window number unavailable
    private func getWindowIdentifier(_ window: AXUIElement, pid: pid_t) -> String {
        // Prefer window number (stable across title changes)
        // Note: kAXWindowNumberAttribute is private, use raw string "AXWindowNumber"
        if let windowNum = copyAXInt(window, attr: "AXWindowNumber") {
            return "\(pid):\(windowNum)"
        }
        // Fallback to title
        let title = copyAXString(window, attr: kAXTitleAttribute as String) ?? "untitled"
        return "\(pid):\(title)"
    }

    private func copyAXInt(_ element: AXUIElement, attr: String) -> Int? {
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success else { return nil }
        return ref as? Int
    }

    private func copyAXString(_ element: AXUIElement, attr: String) -> String? {
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    /// Get cached positions for a direction (precomputed in rebuildGrids)
    func positionsForDirection(_ direction: Direction) -> [WindowPosition] {
        switch direction {
        case .left:     return cache.left
        case .right:    return cache.right
        case .up:       return cache.up
        case .down:     return cache.down
        case .maximize: return cache.maximize
        }
    }

    func moveWindow(_ direction: Direction) {
        guard let (window, pid) = getFocusedWindow() else {
            print("[WindowMover] ERROR: No focused window found")
            return
        }

        guard let currentRect = getWindowRect(window) else {
            print("[WindowMover] ERROR: Could not get window rect")
            return
        }

        let windowID = getWindowIdentifier(window, pid: pid)

        let positions = positionsForDirection(direction)
        guard !positions.isEmpty else {
            print("[WindowMover] ERROR: No positions available")
            return
        }

        var targetIndex: Int

        // Check if we have history for this window AND same direction
        if let last = windowHistory[windowID], last.direction == direction {
            // Same direction pressed again → cycle to next position
            targetIndex = (last.index + 1) % positions.count
            print("[WindowMover] \(windowID): cycling \(direction) → position[\(targetIndex)]")
        } else {
            // Different direction or first time → find primary position for current screen
            targetIndex = findPrimaryPositionIndex(for: currentRect, in: positions, direction: direction)
            print("[WindowMover] \(windowID): starting \(direction) → position[\(targetIndex)]")
        }

        // Update history
        windowHistory[windowID] = (direction, targetIndex)

        // Apply the position
        let result = applyPosition(positions[targetIndex], to: window)
        if !result {
            print("[WindowMover] WARNING: applyPosition may have failed for \(windowID)")
        }
    }

    private func findPrimaryPositionIndex(for rect: CGRect, in positions: [WindowPosition], direction: Direction) -> Int {
        // Find which screen the window is currently on
        let windowCenter = CGPoint(x: rect.midX, y: rect.midY)

        // Find the grid that contains this window (using screen coordinates)
        if let currentGrid = grids.first(where: { $0.screenFrame.contains(windowCenter) }) {
            // Find the primary position for this direction on the current screen
            let primaryPosition: WindowPosition
            switch direction {
            case .left:
                primaryPosition = currentGrid.leftHalf
            case .right:
                primaryPosition = currentGrid.rightHalf
            case .up:
                primaryPosition = currentGrid.topHalf
            case .down:
                primaryPosition = currentGrid.bottomHalf
            case .maximize:
                primaryPosition = currentGrid.full
            }

            // Find the index of this position in the sorted positions array
            if let index = positions.firstIndex(where: { $0.origin == primaryPosition.origin && $0.size == primaryPosition.size }) {
                return index
            }
        }

        // Fallback to first position
        return 0
    }

    @discardableResult
    private func applyPosition(_ position: WindowPosition, to window: AXUIElement) -> Bool {
        var pos = position.origin
        var size = position.size

        guard let posVal = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize, &size) else {
            print("[WindowMover] ERROR: Failed to create AXValue for position/size")
            return false
        }

        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)

        if posResult != .success {
            print("[WindowMover] Failed to set position: \(posResult.rawValue)")
        }
        if sizeResult != .success {
            print("[WindowMover] Failed to set size: \(sizeResult.rawValue)")
        }

        return posResult == .success && sizeResult == .success
    }
}

// MARK: - Accessibility Helpers

/// Returns the focused window and its pid, or nil if unavailable
func getFocusedWindow() -> (window: AXUIElement, pid: pid_t)? {
    // Use NSWorkspace to get frontmost app (more reliable than AX system-wide)
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
        print("[AX] No frontmost application")
        return nil
    }

    let pid = frontApp.processIdentifier
    let appName = frontApp.localizedName ?? "unknown"
    let bundleID = frontApp.bundleIdentifier ?? "unknown"

    // Skip if our own app is frontmost (shouldn't happen but just in case)
    if bundleID == Bundle.main.bundleIdentifier {
        print("[AX] Our app is frontmost, skipping")
        return nil
    }

    let axApp = AXUIElementCreateApplication(pid)

    // Try focused window first
    var window: AnyObject?
    let windowResult = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &window)
    if windowResult == .success, let axWindow = window {
        // swiftlint:disable:next force_cast
        return (axWindow as! AXUIElement, pid)
    }

    print("[AX] App '\(appName)' (\(bundleID)) - kAXFocusedWindowAttribute failed: \(windowResult.rawValue)")

    // Fallback: try getting all windows
    var windows: AnyObject?
    let windowsResult = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windows)
    if windowsResult == .success, let windowList = windows as? [AXUIElement], let first = windowList.first {
        print("[AX] Found \(windowList.count) windows via kAXWindowsAttribute, using first")
        return (first, pid)
    }

    print("[AX] kAXWindowsAttribute also failed: \(windowsResult.rawValue)")
    return nil
}

func getWindowRect(_ window: AXUIElement) -> CGRect? {
    var posValue: AnyObject?
    var sizeValue: AnyObject?

    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
          AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success else {
        return nil
    }

    var position = CGPoint.zero
    var size = CGSize.zero

    AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

    return CGRect(origin: position, size: size)
}

// MARK: - Debug / Test

struct TilingTest {
    static func runDiagnostics() {
        print("\n" + String(repeating: "=", count: 60))
        print("WINDOW TILING DIAGNOSTICS")
        print(String(repeating: "=", count: 60))

        let mover = WindowMover.shared
        mover.rebuildGrids()

        // Screen info
        print("\nScreens (\(NSScreen.screens.count) total):")
        for (i, screen) in NSScreen.screens.enumerated() {
            print("  [\(i)] frame: \(screen.frame)")
            print("       visible: \(screen.visibleFrame)")
        }

        // Position info
        print("\nLEFT positions (sorted by X descending - rightmost first):")
        let leftPositions = mover.positionsForDirection(.left)
        for (i, pos) in leftPositions.enumerated() {
            print("  [\(i)] x=\(Int(pos.origin.x)), y=\(Int(pos.origin.y)), " +
                  "size=\(Int(pos.size.width))x\(Int(pos.size.height)), screen=\(pos.screenIndex)")
        }

        // Current window info
        if let (window, _) = getFocusedWindow(), let rect = getWindowRect(window) {
            print("\nFocused window: x=\(Int(rect.origin.x)), y=\(Int(rect.origin.y)), " +
                  "size=\(Int(rect.size.width))x\(Int(rect.size.height))")

            if let matchIndex = leftPositions.firstIndex(where: { $0.matchesRect(rect) }) {
                print("  Matches position[\(matchIndex)]")
            } else {
                print("  No position match (will snap to primary position on next move)")
            }
        } else {
            print("\nNo focused window or unable to get window rect")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }

    static func runCycleTest(direction: Direction, presses: Int = 6) {
        let mover = WindowMover.shared
        let positions = mover.positionsForDirection(direction)

        print("\n--- Cycle Test: \(direction) (\(presses) presses) ---")

        for i in 1...presses {
            mover.moveWindow(direction)

            // Small delay to let the window settle
            usleep(100_000) // 100ms

            if let (window, _) = getFocusedWindow(), let rect = getWindowRect(window) {
                let matchIndex = positions.firstIndex(where: { $0.matchesRect(rect) })
                let matchStr = matchIndex.map { "position[\($0)]" } ?? "no match"
                print("  Press \(i): x=\(Int(rect.origin.x)) -> \(matchStr)")
            }
        }
    }
}

// MARK: - Tile Icons

enum TileIcon {
    case left, right, top, bottom, full

    static func image(_ icon: TileIcon, size: CGFloat = 16) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset: CGFloat = 1.5
            let frame = rect.insetBy(dx: inset, dy: inset)

            // Fill region
            let fillRect: NSRect
            switch icon {
            case .left:
                fillRect = NSRect(x: frame.minX, y: frame.minY, width: frame.width / 2, height: frame.height)
            case .right:
                fillRect = NSRect(x: frame.midX, y: frame.minY, width: frame.width / 2, height: frame.height)
            case .top:
                fillRect = NSRect(x: frame.minX, y: frame.midY, width: frame.width, height: frame.height / 2)
            case .bottom:
                fillRect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height / 2)
            case .full:
                fillRect = frame
            }

            // Draw filled region
            NSColor.labelColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(rect: fillRect).fill()

            // Draw thin frame
            NSColor.labelColor.setStroke()
            let path = NSBezierPath(rect: frame)
            path.lineWidth = 0.5
            path.stroke()

            // Draw divider for halves
            if icon != .full {
                let divider = NSBezierPath()
                switch icon {
                case .left, .right:
                    divider.move(to: NSPoint(x: frame.midX, y: frame.minY))
                    divider.line(to: NSPoint(x: frame.midX, y: frame.maxY))
                case .top, .bottom:
                    divider.move(to: NSPoint(x: frame.minX, y: frame.midY))
                    divider.line(to: NSPoint(x: frame.maxX, y: frame.midY))
                case .full:
                    break
                }
                divider.lineWidth = 0.5
                divider.stroke()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}

// MARK: - Accessibility Authorization View

struct AccessibilityAuthorizationView: View {
    @Environment(\.dismiss) private var dismiss

    private let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    var body: some View {
        VStack(spacing: 22) {
            Text("Authorize Tile")
                .font(.title)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 60, height: 60)

            Text("Tile needs your permission to control your window positions.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Go to System Settings → Privacy & Security → Accessibility")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                NSWorkspace.shared.open(accessibilitySettingsURL)
//                if !AXIsProcessTrusted() {
//                            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary)
//                            return
//                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

//            Text("Enable Tile.app")
//                .font(.body)
        }
        .padding(20)
        .frame(width: 350)
        .onAppear {
            // Dismiss immediately if we already have permissions
            if AXIsProcessTrusted() {
                dismiss()
            }
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            // Open the accessibility window after a brief delay to ensure the window is registered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "accessibility" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}

// MARK: - App

@main
struct tileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        setupShortcuts()
    }

    private func bind(_ name: KeyboardShortcuts.Name, _ direction: Direction) {
        KeyboardShortcuts.onKeyUp(for: name) { WindowMover.shared.moveWindow(direction) }
    }

    func setupShortcuts() {
        bind(.leftHalf, .left)
        bind(.rightHalf, .right)
        bind(.topHalf, .up)
        bind(.bottomHalf, .down)
        bind(.maximize, .maximize)
    }

    var body: some Scene {
        Window("Accessibility", id: "accessibility") {
            AccessibilityAuthorizationView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra {
            let hasAccess = AXIsProcessTrusted()

            Button(action: { WindowMover.shared.moveWindow(.left) }) {
                Label { Text("Left") } icon: { Image(nsImage: TileIcon.image(.left)) }
            }
            .keyboardShortcut(.leftArrow, modifiers: [.control, .option])
            .disabled(!hasAccess)

            Button(action: { WindowMover.shared.moveWindow(.right) }) {
                Label { Text("Right") } icon: { Image(nsImage: TileIcon.image(.right)) }
            }
            .keyboardShortcut(.rightArrow, modifiers: [.control, .option])
            .disabled(!hasAccess)

            Button(action: { WindowMover.shared.moveWindow(.up) }) {
                Label { Text("Top") } icon: { Image(nsImage: TileIcon.image(.top)) }
            }
            .keyboardShortcut(.upArrow, modifiers: [.control, .option])
            .disabled(!hasAccess)

            Button(action: { WindowMover.shared.moveWindow(.down) }) {
                Label { Text("Bottom") } icon: { Image(nsImage: TileIcon.image(.bottom)) }
            }
            .keyboardShortcut(.downArrow, modifiers: [.control, .option])
            .disabled(!hasAccess)

            Button(action: { WindowMover.shared.moveWindow(.maximize) }) {
                Label { Text("Full") } icon: { Image(nsImage: TileIcon.image(.full)) }
            }
            .keyboardShortcut(.return, modifiers: [.control, .option])
            .disabled(!hasAccess)

            Divider()

            if !hasAccess {
                Label("Tile needs accessibility permissions", systemImage: "exclamationmark.triangle")

                Button("Grant Accessibility...") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }

                Divider()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: TileIcon.image(.full, size: 18))
        }
        .menuBarExtraStyle(.menu)
    }
}
