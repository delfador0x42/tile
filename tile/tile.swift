import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let tileWindow = Self("tileWindow")
}

@main
struct TileApp: App {
    init() {
        // Set the default shortcut to Control+Shift+U
        KeyboardShortcuts.setShortcut(.init(.u, modifiers: [.control, .shift]), for: .tileWindow)

        // Set the handler for when the shortcut is pressed
        KeyboardShortcuts.onKeyUp(for: .tileWindow) {
            print("Hello Shortcut")
        }
    }

    var body: some Scene {
        WindowGroup {
            Text("Hello World")
        }
    }
}

