import SwiftUI
import KeyboardShortcuts
import ApplicationServices


// MARK: - AX Debug Helpers

func printAXElementInfo(_ element: AXUIElement, label: String = "Element") {
    print("\n========== \(label) ==========")

    // Get role first
    var role: AnyObject?
    if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success {
        print("Role: \(role as? String ?? "unknown")")
    }

    // Get all attribute names
    var attributeNames: CFArray?
    // This is to 
    if AXUIElementCopyAttributeNames(element, &attributeNames) == .success,
       let names = attributeNames as? [String] {
        print("\n--- Attributes (\(names.count)) ---")
        for name in names.sorted() {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
            if result == .success {
                print("  \(name): \(describeAXValue(value))")
            } else {
                print("  \(name): <error: \(result.rawValue)>")
            }
        }
    }

    // Get all action names
    var actionNames: CFArray?
    if AXUIElementCopyActionNames(element, &actionNames) == .success,
       let actions = actionNames as? [String] {
        print("\n--- Actions (\(actions.count)) ---")
        for action in actions.sorted() {
            print("  \(action)")
        }
    }

    print("================================\n")
}

func describeAXValue(_ value: AnyObject?) -> String {
    guard let value = value else { return "nil" }

    // Handle AXValue types (CGPoint, CGSize, CGRect, etc.)
    if CFGetTypeID(value) == AXValueGetTypeID() {
        let axValue = value as! AXValue
        let type = AXValueGetType(axValue)

        switch type {
        case .cgPoint:
            var point = CGPoint.zero
            AXValueGetValue(axValue, .cgPoint, &point)
            return "CGPoint(x: \(point.x), y: \(point.y))"
        case .cgSize:
            var size = CGSize.zero
            AXValueGetValue(axValue, .cgSize, &size)
            return "CGSize(w: \(size.width), h: \(size.height))"
        case .cgRect:
            var rect = CGRect.zero
            AXValueGetValue(axValue, .cgRect, &rect)
            return "CGRect(\(rect))"
        default:
            return "AXValue(type: \(type.rawValue))"
        }
    }

    // Handle AXUIElement (just show type, don't recurse)
    if CFGetTypeID(value) == AXUIElementGetTypeID() {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(value as! AXUIElement, kAXRoleAttribute as CFString, &role)
        return "<AXUIElement: \(role as? String ?? "unknown")>"
    }

    // Handle arrays
    if let array = value as? [AnyObject] {
        return "[\(array.count) items]"
    }

    // Default: just use description
    return "\(value)"
}

func exploreAllAXElements() {
    print("\n🔍 Exploring Accessibility Elements...\n")

    // System-wide element
    let systemWide = AXUIElementCreateSystemWide()
    printAXElementInfo(systemWide, label: "System Wide")

    // Focused application
    var focusedApp: AnyObject?
    if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success {
        printAXElementInfo(focusedApp as! AXUIElement, label: "Focused Application")

        // Focused window
        var focusedWindow: AnyObject?
        if AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
            printAXElementInfo(focusedWindow as! AXUIElement, label: "Focused Window")
        }
    }
}


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
    
    exploreAllAXElements()

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
    static let leftHalf = Self("", default: .init(.u, modifiers: [.control, .shift]))
}

struct ContentView: View {
    @State private var isPressed = false
    
   

    var body: some View {
        VStack(spacing: 20) {
            Text(isPressed ? "Hello Shortcut" : "Nothing to see")
            KeyboardShortcuts.Recorder("", name: .leftHalf)
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

