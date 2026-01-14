import SwiftUI
import KeyboardShortcuts
import ApplicationServices


func getFocusedWindow() -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    var focusedApp: AnyObject?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
        return nil
    }

    print(focusedApp)
    
    
    
    var focusedWindow: AnyObject?
    guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
        return nil
    }

    print(focusedWindow)
    
    
    return (focusedWindow as! AXUIElement)
}

func tileWindowToLeftHalf() {
    guard let windowRef = getFocusedWindow() else {
        print("Could not get focused window")
        return
    }

    // Get the main screen dimensions
    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.visibleFrame

    // Calculate left half position and size
    let leftHalfOrigin = CGPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
    let leftHalfSize = CGSize(width: screenFrame.width / 2, height: screenFrame.height)

    // Set position
    var position = leftHalfOrigin
    guard let axPositionValue = AXValueCreate(.cgPoint, &position) else { return }
    AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute as CFString, axPositionValue)

    // Set size
    var size = leftHalfSize
    guard let axSizeValue = AXValueCreate(.cgSize, &size) else { return }
    let error = AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute as CFString, axSizeValue)

    if error == .success {
        print("Window tiled to left half successfully")
    } else {
        print("Failed to tile window, error code: \(error.rawValue)")
    }
}



extension KeyboardShortcuts.Name {
    static let leftHalf = Self("useless name 1", default: .init(.u, modifiers: [.control, .shift]))
}

struct ContentView: View {
    @State private var isPressed = false
    
    init() {
        // Set the default shortcut to Control+Shift+U
        //KeyboardShortcuts.setShortcut(.init(.u, modifiers: [.control, .shift]), for: .tileWindow)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isPressed ? "Hello Shortcut" : "Nothing to see")
            KeyboardShortcuts.Recorder("useless name 2", name: .leftHalf)
        }

        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .leftHalf) {
                tileWindowToLeftHalf()
                isPressed.toggle()
            }
            
            
        }
    }
}






@main
struct TileApp: App {
    init() {
        
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary)
            return
        }


        
       
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

