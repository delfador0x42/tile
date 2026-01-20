#if DEBUG
import AppKit

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
#endif
