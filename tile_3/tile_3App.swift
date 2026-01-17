import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let leftHalf = Self("leftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    static let rightHalf = Self("rightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let topHalf = Self("topHalf", default: .init(.upArrow, modifiers: [.control, .option]))
    static let bottomHalf = Self("bottomHalf", default: .init(.downArrow, modifiers: [.control, .option]))
    static let maximize = Self("maximize", default: .init(.return, modifiers: [.control, .option]))
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

// MARK: - Window Mover Factory

class WindowMover {
    static let shared = WindowMover()

    private var grids: [ScreenGrid] = []

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
        // Clear history when screens change since positions are invalidated
        windowHistory.removeAll()
    }

    /// Get a unique identifier for a window (bundleID + window title)
    private func getWindowIdentifier(_ window: AXUIElement) -> String? {
        // Get the frontmost app via NSWorkspace (matches getFocusedWindow approach)
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let bundleID = frontApp.bundleIdentifier ?? "unknown"

        // Get window title for uniqueness (in case app has multiple windows)
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? "untitled"

        return "\(bundleID):\(title)"
    }

    // Get all positions in a direction across all monitors, sorted by spatial position
    func positionsForDirection(_ direction: Direction) -> [WindowPosition] {
        switch direction {
        case .left:
            // All halves sorted by X descending (rightmost first → leftmost last)
            // Pressing LEFT cycles: high X → low X → wrap to high X
            let positions = grids.flatMap { [$0.leftHalf, $0.rightHalf] }
            return positions.sorted { $0.origin.x > $1.origin.x }
        case .right:
            // All halves sorted by X ascending (leftmost first → rightmost last)
            // Pressing RIGHT cycles: low X → high X → wrap to low X
            let positions = grids.flatMap { [$0.leftHalf, $0.rightHalf] }
            return positions.sorted { $0.origin.x < $1.origin.x }
        case .up:
            // All halves sorted by Y ascending (topmost first in screen coords where low Y = top)
            let positions = grids.flatMap { [$0.topHalf, $0.bottomHalf] }
            return positions.sorted { $0.origin.y < $1.origin.y }
        case .down:
            // All halves sorted by Y descending (bottommost first in screen coords where high Y = bottom)
            let positions = grids.flatMap { [$0.topHalf, $0.bottomHalf] }
            return positions.sorted { $0.origin.y > $1.origin.y }
        case .maximize:
            return grids.sorted { $0.frame.origin.x < $1.frame.origin.x }.map { $0.full }
        }
    }

    func moveWindow(_ direction: Direction) {
        guard let window = getFocusedWindow() else {
            print("[WindowMover] ERROR: No focused window found")
            return
        }

        guard let currentRect = getWindowRect(window) else {
            print("[WindowMover] ERROR: Could not get window rect")
            return
        }

        guard let windowID = getWindowIdentifier(window) else {
            print("[WindowMover] ERROR: Could not get window identifier")
            return
        }

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

        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)

        if posResult != .success {
            print("[WindowMover] Failed to set position: \(posResult.rawValue)")
        }
        if sizeResult != .success {
            print("[WindowMover] Failed to set size: \(sizeResult.rawValue)")
        }

        return posResult == .success && sizeResult == .success
    }
}

enum Direction {
    case left, right, up, down, maximize
}

// MARK: - Accessibility Helpers

func getFocusedWindow() -> AXUIElement? {
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
    if windowResult == .success {
        return window as! AXUIElement
    }

    print("[AX] App '\(appName)' (\(bundleID)) - kAXFocusedWindowAttribute failed: \(windowResult.rawValue)")

    // Fallback: try getting all windows
    var windows: AnyObject?
    let windowsResult = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windows)
    if windowsResult == .success, let windowList = windows as? [AXUIElement], !windowList.isEmpty {
        print("[AX] Found \(windowList.count) windows via kAXWindowsAttribute, using first")
        return windowList.first
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
        if let window = getFocusedWindow(), let rect = getWindowRect(window) {
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

            if let window = getFocusedWindow(), let rect = getWindowRect(window) {
                let matchIndex = positions.firstIndex(where: { $0.matchesRect(rect) })
                let matchStr = matchIndex.map { "position[\($0)]" } ?? "no match"
                print("  Press \(i): x=\(Int(rect.origin.x)) -> \(matchStr)")
            }
        }
    }
}

// MARK: - App

@main
struct MyMenuBarApp: App {
    @State private var windowMover = WindowMover.shared

    init() {
        setupShortcuts()
    }

    func setupShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .leftHalf) {
            WindowMover.shared.moveWindow(.left)
        }
        KeyboardShortcuts.onKeyUp(for: .rightHalf) {
            WindowMover.shared.moveWindow(.right)
        }
        KeyboardShortcuts.onKeyUp(for: .topHalf) {
            WindowMover.shared.moveWindow(.up)
        }
        KeyboardShortcuts.onKeyUp(for: .bottomHalf) {
            WindowMover.shared.moveWindow(.down)
        }
        KeyboardShortcuts.onKeyUp(for: .maximize) {
            WindowMover.shared.moveWindow(.maximize)
        }
    }

    var body: some Scene {
        MenuBarExtra("Tile", systemImage: "rectangle.split.2x2") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Window Tiling")
                    .font(.headline)

                Divider()

                Group {
                    Button("← Left Half (⌃⌥←)") {
                        WindowMover.shared.moveWindow(.left)
                    }
                    Button("→ Right Half (⌃⌥→)") {
                        WindowMover.shared.moveWindow(.right)
                    }
                    Button("↑ Top Half (⌃⌥↑)") {
                        WindowMover.shared.moveWindow(.up)
                    }
                    Button("↓ Bottom Half (⌃⌥↓)") {
                        WindowMover.shared.moveWindow(.down)
                    }
                    Button("⬜ Maximize (⌃⌥↩)") {
                        WindowMover.shared.moveWindow(.maximize)
                    }
                }

                Divider()

                Group {
                    Button("Run Diagnostics") {
                        TilingTest.runDiagnostics()
                    }
                    Button("Test LEFT Cycle (6x)") {
                        TilingTest.runCycleTest(direction: .left, presses: 6)
                    }
                }

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
        .menuBarExtraStyle(.menu)
    }
}
