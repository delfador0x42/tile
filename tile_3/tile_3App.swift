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

    func matchesRect(_ rect: CGRect, tolerance: CGFloat = 10) -> Bool {
        abs(origin.x - rect.origin.x) < tolerance &&
        abs(origin.y - rect.origin.y) < tolerance &&
        abs(size.width - rect.size.width) < tolerance &&
        abs(size.height - rect.size.height) < tolerance
    }
}

// MARK: - Screen Grid

struct ScreenGrid {
    let screen: NSScreen
    let screenIndex: Int
    let frame: CGRect

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

    init(screen: NSScreen, index: Int) {
        self.screen = screen
        self.screenIndex = index
        self.frame = screen.visibleFrame

        let f = frame
        let w = f.width
        let h = f.height
        let x = f.origin.x
        let y = f.origin.y

        // Halves
        leftHalf = WindowPosition(origin: CGPoint(x: x, y: y), size: CGSize(width: w/2, height: h), screenIndex: index)
        rightHalf = WindowPosition(origin: CGPoint(x: x + w/2, y: y), size: CGSize(width: w/2, height: h), screenIndex: index)
        topHalf = WindowPosition(origin: CGPoint(x: x, y: y + h/2), size: CGSize(width: w, height: h/2), screenIndex: index)
        bottomHalf = WindowPosition(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h/2), screenIndex: index)

        // Thirds
        leftThird = WindowPosition(origin: CGPoint(x: x, y: y), size: CGSize(width: w/3, height: h), screenIndex: index)
        centerThird = WindowPosition(origin: CGPoint(x: x + w/3, y: y), size: CGSize(width: w/3, height: h), screenIndex: index)
        rightThird = WindowPosition(origin: CGPoint(x: x + 2*w/3, y: y), size: CGSize(width: w/3, height: h), screenIndex: index)
        leftTwoThirds = WindowPosition(origin: CGPoint(x: x, y: y), size: CGSize(width: 2*w/3, height: h), screenIndex: index)
        rightTwoThirds = WindowPosition(origin: CGPoint(x: x + w/3, y: y), size: CGSize(width: 2*w/3, height: h), screenIndex: index)

        // Quarters
        topLeft = WindowPosition(origin: CGPoint(x: x, y: y + h/2), size: CGSize(width: w/2, height: h/2), screenIndex: index)
        topRight = WindowPosition(origin: CGPoint(x: x + w/2, y: y + h/2), size: CGSize(width: w/2, height: h/2), screenIndex: index)
        bottomLeft = WindowPosition(origin: CGPoint(x: x, y: y), size: CGSize(width: w/2, height: h/2), screenIndex: index)
        bottomRight = WindowPosition(origin: CGPoint(x: x + w/2, y: y), size: CGSize(width: w/2, height: h/2), screenIndex: index)

        // Full
        full = WindowPosition(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h), screenIndex: index)
    }
}

// MARK: - Window Mover Factory

class WindowMover {
    static let shared = WindowMover()

    private var grids: [ScreenGrid] = []

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
            // All halves sorted by Y descending (topmost first in Cocoa coords)
            let positions = grids.flatMap { [$0.topHalf, $0.bottomHalf] }
            return positions.sorted { $0.origin.y > $1.origin.y }
        case .down:
            // All halves sorted by Y ascending (bottommost first)
            let positions = grids.flatMap { [$0.topHalf, $0.bottomHalf] }
            return positions.sorted { $0.origin.y < $1.origin.y }
        case .maximize:
            return grids.sorted { $0.frame.origin.x < $1.frame.origin.x }.map { $0.full }
        }
    }

    func moveWindow(_ direction: Direction) {
        guard let window = getFocusedWindow() else { return }
        guard let currentRect = getWindowRect(window) else { return }

        let positions = positionsForDirection(direction)
        guard !positions.isEmpty else { return }

        // Find if current position matches any in the sequence
        if let matchIndex = positions.firstIndex(where: { $0.matchesRect(currentRect) }) {
            // Already at a position in sequence - move to next (with wrap)
            let nextIndex = (matchIndex + 1) % positions.count
            applyPosition(positions[nextIndex], to: window)
        } else {
            // Not at any position - find the best starting position
            let targetPosition = findBestStartingPosition(for: currentRect, in: positions, direction: direction)
            applyPosition(targetPosition, to: window)
        }
    }

    private func findBestStartingPosition(for rect: CGRect, in positions: [WindowPosition], direction: Direction) -> WindowPosition {
        // Find which screen the window is currently on
        let windowCenter = CGPoint(x: rect.midX, y: rect.midY)

        // Find the grid that contains this window
        if let currentGrid = grids.first(where: { $0.frame.contains(windowCenter) }) {
            // Return the primary position for this direction on the current screen
            switch direction {
            case .left:
                return currentGrid.leftHalf
            case .right:
                return currentGrid.rightHalf
            case .up:
                return currentGrid.topHalf
            case .down:
                return currentGrid.bottomHalf
            case .maximize:
                return currentGrid.full
            }
        }

        // Fallback to first position
        return positions[0]
    }

    private func applyPosition(_ position: WindowPosition, to window: AXUIElement) {
        var pos = position.origin
        var size = position.size
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
    }
}

enum Direction {
    case left, right, up, down, maximize
}

// MARK: - Accessibility Helpers

func getFocusedWindow() -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    var app: AnyObject?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &app) == .success else { return nil }
    var window: AnyObject?
    guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &window) == .success else { return nil }
    return window as! AXUIElement
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

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
        .menuBarExtraStyle(.menu)
    }
}
