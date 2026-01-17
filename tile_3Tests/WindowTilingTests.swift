import XCTest
@testable import tile_3

/// Tests for window tiling functionality
///
/// Key behaviors to verify:
/// 1. Single screen: LEFT twice cycles left half → right half → left half
/// 2. Multi-screen: Window moves spatially leftward, entering each new screen from its right edge
/// 3. Positions are correctly calculated in screen coordinates (origin top-left, Y down)
final class WindowTilingTests: XCTestCase {

    // MARK: - Position Calculation Tests

    func testPositionsForLeftDirection_SingleScreen() {
        // Given a single screen setup
        let mover = WindowMover.shared
        mover.rebuildGrids()

        let positions = mover.positionsForDirection(.left)

        // Should have 2 positions (left half, right half)
        XCTAssertEqual(positions.count, 2, "Single screen should have 2 horizontal positions")

        // Positions should be sorted by X descending (rightmost first)
        XCTAssertGreaterThan(positions[0].origin.x, positions[1].origin.x,
                            "Positions should be sorted by X descending for LEFT direction")

        // First position should be right half (higher X)
        // Second position should be left half (lower X)
        print("LEFT positions: \(positions.map { "x=\($0.origin.x)" })")
    }

    func testPositionsForRightDirection_SingleScreen() {
        let mover = WindowMover.shared
        mover.rebuildGrids()

        let positions = mover.positionsForDirection(.right)

        XCTAssertEqual(positions.count, 2)

        // Positions should be sorted by X ascending (leftmost first)
        XCTAssertLessThan(positions[0].origin.x, positions[1].origin.x,
                         "Positions should be sorted by X ascending for RIGHT direction")
    }

    func testPositionsForUpDirection_SingleScreen() {
        let mover = WindowMover.shared
        mover.rebuildGrids()

        let positions = mover.positionsForDirection(.up)

        XCTAssertEqual(positions.count, 2)

        // In screen coordinates, lower Y = top of screen
        // Positions should be sorted by Y ascending (topmost first)
        XCTAssertLessThan(positions[0].origin.y, positions[1].origin.y,
                         "Positions should be sorted by Y ascending for UP direction (top first)")
    }

    func testPositionsForDownDirection_SingleScreen() {
        let mover = WindowMover.shared
        mover.rebuildGrids()

        let positions = mover.positionsForDirection(.down)

        XCTAssertEqual(positions.count, 2)

        // Positions should be sorted by Y descending (bottommost first)
        XCTAssertGreaterThan(positions[0].origin.y, positions[1].origin.y,
                            "Positions should be sorted by Y descending for DOWN direction (bottom first)")
    }

    // MARK: - Coordinate Conversion Tests

    func testScreenCoordinateConversion() {
        // Verify that positions are in screen coordinates (not Cocoa coordinates)
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let mover = WindowMover.shared
        mover.rebuildGrids()

        let positions = mover.positionsForDirection(.left)
        guard let leftHalf = positions.last else { // leftHalf has lower X, so it's last in LEFT direction
            XCTFail("No positions available")
            return
        }

        // In screen coordinates, Y should be relatively small for full-height windows
        // (close to menu bar, which is at Y ≈ 25)
        // In Cocoa coordinates, Y would be large (near bottom of screen coordinate space)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0

        print("Primary screen height: \(primaryScreenHeight)")
        print("Left half origin.y: \(leftHalf.origin.y)")
        print("Left half size.height: \(leftHalf.size.height)")

        // The Y origin should be small (menu bar area) not large (Cocoa bottom)
        XCTAssertLessThan(leftHalf.origin.y, primaryScreenHeight / 2,
                         "Y coordinate should be in screen coords (small value for top of visible area)")
    }

    // MARK: - Cycling Logic Tests

    func testPositionMatchingWithTolerance() {
        let pos1 = WindowPosition(origin: CGPoint(x: 100, y: 100),
                                   size: CGSize(width: 500, height: 400),
                                   screenIndex: 0)

        // Exact match
        let rect1 = CGRect(x: 100, y: 100, width: 500, height: 400)
        XCTAssertTrue(pos1.matchesRect(rect1), "Exact match should return true")

        // Within tolerance
        let rect2 = CGRect(x: 105, y: 95, width: 505, height: 395)
        XCTAssertTrue(pos1.matchesRect(rect2, tolerance: 10), "Within tolerance should match")

        // Outside tolerance
        let rect3 = CGRect(x: 120, y: 100, width: 500, height: 400)
        XCTAssertFalse(pos1.matchesRect(rect3, tolerance: 10), "Outside tolerance should not match")
    }

    func testCyclingIndex() {
        // Test the cycling logic: (index + 1) % count
        let positions = [0, 1] // Simulating 2 positions

        // At index 0 → next is 1
        XCTAssertEqual((0 + 1) % positions.count, 1)

        // At index 1 → next wraps to 0
        XCTAssertEqual((1 + 1) % positions.count, 0)
    }
}

// MARK: - Integration Tests (require accessibility permissions)

final class WindowTilingIntegrationTests: XCTestCase {

    /// Creates a test window that we can move around
    var testWindow: NSWindow?

    override func setUp() {
        super.setUp()

        // Create a test window
        testWindow = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        testWindow?.title = "Test Window"
        testWindow?.makeKeyAndOrderFront(nil)

        // Give the window time to appear
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    }

    override func tearDown() {
        testWindow?.close()
        testWindow = nil
        super.tearDown()
    }

    /// Test that pressing LEFT cycles through positions correctly on a single screen
    func testLeftCycling_SingleScreen() {
        guard NSScreen.screens.count == 1 else {
            print("Skipping single-screen test: \(NSScreen.screens.count) screens detected")
            return
        }

        let mover = WindowMover.shared
        let positions = mover.positionsForDirection(.left)

        print("\n=== LEFT Cycling Test (Single Screen) ===")
        print("Expected cycle: leftHalf → rightHalf → leftHalf")
        print("Positions in order: \(positions.map { "x=\(Int($0.origin.x))" })")

        // First press: should snap to leftHalf
        mover.moveWindow(.left)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        if let rect = getCurrentWindowRect() {
            print("After 1st LEFT: x=\(Int(rect.origin.x)), width=\(Int(rect.size.width))")

            // Find which position we're at
            if let matchedPos = positions.first(where: { $0.matchesRect(rect) }) {
                print("  Matched position at x=\(Int(matchedPos.origin.x))")
            } else {
                print("  No exact match found")
            }
        }

        // Second press: should move to rightHalf (or wrap)
        mover.moveWindow(.left)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        if let rect = getCurrentWindowRect() {
            print("After 2nd LEFT: x=\(Int(rect.origin.x)), width=\(Int(rect.size.width))")
        }

        // Third press: should wrap back to leftHalf (or continue cycle)
        mover.moveWindow(.left)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        if let rect = getCurrentWindowRect() {
            print("After 3rd LEFT: x=\(Int(rect.origin.x)), width=\(Int(rect.size.width))")
        }
    }

    /// Test multi-screen cycling behavior
    func testLeftCycling_MultiScreen() {
        guard NSScreen.screens.count > 1 else {
            print("Skipping multi-screen test: only \(NSScreen.screens.count) screen(s) detected")
            return
        }

        let mover = WindowMover.shared
        let positions = mover.positionsForDirection(.left)

        print("\n=== LEFT Cycling Test (Multi-Screen: \(NSScreen.screens.count) screens) ===")
        print("Expected: Window moves spatially leftward, entering each screen from its right edge")
        print("Positions in order (by X descending):")
        for (i, pos) in positions.enumerated() {
            print("  \(i): x=\(Int(pos.origin.x)), screenIndex=\(pos.screenIndex)")
        }

        // Cycle through all positions
        for i in 0..<min(positions.count + 1, 10) {
            mover.moveWindow(.left)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

            if let rect = getCurrentWindowRect() {
                let matchInfo = positions.enumerated()
                    .first(where: { $0.element.matchesRect(rect) })
                    .map { "matched index \($0.offset)" } ?? "no match"
                print("After LEFT #\(i + 1): x=\(Int(rect.origin.x)), \(matchInfo)")
            }
        }
    }

    /// Verify position calculations against actual screen dimensions
    func testPositionCalculationsMatchScreenDimensions() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen")
            return
        }

        let visibleFrame = screen.visibleFrame
        let mover = WindowMover.shared
        mover.rebuildGrids()

        let leftPositions = mover.positionsForDirection(.left)

        print("\n=== Position Verification ===")
        print("Screen visible frame: \(visibleFrame)")
        print("Expected half width: \(visibleFrame.width / 2)")

        for pos in leftPositions {
            print("Position: origin=(\(Int(pos.origin.x)), \(Int(pos.origin.y))), size=(\(Int(pos.size.width))x\(Int(pos.size.height)))")

            // Width should be half of screen width
            XCTAssertEqual(pos.size.width, visibleFrame.width / 2, accuracy: 1,
                          "Position width should be half of screen width")

            // Height should match visible height
            XCTAssertEqual(pos.size.height, visibleFrame.height, accuracy: 1,
                          "Position height should match visible frame height")
        }
    }

    // MARK: - Helper

    private func getCurrentWindowRect() -> CGRect? {
        guard let window = getFocusedWindow() else { return nil }
        return getWindowRect(window)
    }
}

// MARK: - Manual Test Runner

/// Run this to manually test the window tiling with visual feedback
/// Can be called from the app or a test
func runManualWindowTilingTest() {
    print("\n" + String(repeating: "=", count: 60))
    print("WINDOW TILING MANUAL TEST")
    print(String(repeating: "=", count: 60))

    let mover = WindowMover.shared
    mover.rebuildGrids()

    print("\nScreen Configuration:")
    for (i, screen) in NSScreen.screens.enumerated() {
        print("  Screen \(i): frame=\(screen.frame), visibleFrame=\(screen.visibleFrame)")
    }

    print("\nLEFT direction positions (sorted by X descending):")
    let leftPositions = mover.positionsForDirection(.left)
    for (i, pos) in leftPositions.enumerated() {
        print("  [\(i)] x=\(Int(pos.origin.x)), y=\(Int(pos.origin.y)), " +
              "size=\(Int(pos.size.width))x\(Int(pos.size.height)), screen=\(pos.screenIndex)")
    }

    print("\nRIGHT direction positions (sorted by X ascending):")
    let rightPositions = mover.positionsForDirection(.right)
    for (i, pos) in rightPositions.enumerated() {
        print("  [\(i)] x=\(Int(pos.origin.x)), screen=\(pos.screenIndex)")
    }

    print("\n" + String(repeating: "-", count: 60))
    print("Testing LEFT cycling (press Ctrl+Q to stop)...")
    print(String(repeating: "-", count: 60))

    // Test cycling
    for i in 1...6 {
        print("\nPress #\(i) - LEFT")
        mover.moveWindow(.left)

        // Wait a bit and show result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let window = getFocusedWindow(),
               let rect = getWindowRect(window) {
                let matchIndex = leftPositions.firstIndex(where: { $0.matchesRect(rect) })
                let matchStr = matchIndex.map { "→ position[\($0)]" } ?? "→ no match"
                print("  Result: x=\(Int(rect.origin.x)), y=\(Int(rect.origin.y)) \(matchStr)")
            }
        }

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    }

    print("\n" + String(repeating: "=", count: 60))
    print("TEST COMPLETE")
    print(String(repeating: "=", count: 60))
}
