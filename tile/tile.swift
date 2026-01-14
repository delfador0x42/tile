import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let tileWindow = Self("tileWindow")
}

struct ContentView: View {
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 20) {
            Text(isPressed ? "Hello Shortcut" : "Nothing to see")

            KeyboardShortcuts.Recorder("Hotkey:", name: .tileWindow)
        }
        .padding(40)
        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .tileWindow) {
                isPressed.toggle()
            }
        }
    }
}

@main
struct TileApp: App {
    init() {
        // Set the default shortcut to Control+Shift+U
        KeyboardShortcuts.setShortcut(.init(.u, modifiers: [.control, .shift]), for: .tileWindow)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

