import SwiftUI
import KeyboardShortcuts
import ApplicationServices

extension KeyboardShortcuts.Name {
    static let leftHalf = Self("leftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    static let rightHalf = Self("rightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let topHalf = Self("topHalf", default: .init(.upArrow, modifiers: [.control, .option]))
    static let bottomHalf = Self("bottomHalf", default: .init(.downArrow, modifiers: [.control, .option]))
}

func getFocusedWindow() -> AXUIElement? {
    let systemWide = AXUIElementCreateSystemWide()
    var app: AnyObject?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &app) == .success else { return nil }
    var window: AnyObject?
    guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &window) == .success else { return nil }
    return window as! AXUIElement
}

func tileLeftHalf() {
    guard let win = getFocusedWindow(), let screen = NSScreen.main else { return }
    let f = screen.visibleFrame
    var pos = CGPoint(x: f.origin.x, y: f.origin.y)
    var size = CGSize(width: f.width / 2, height: f.height)
    AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}

func tileRightHalf() {
    guard let win = getFocusedWindow(), let screen = NSScreen.main else { return }
    let f = screen.visibleFrame
    var pos = CGPoint(x: f.origin.x + f.width / 2, y: f.origin.y)
    var size = CGSize(width: f.width / 2, height: f.height)
    AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}

func tileTopHalf() {
    guard let win = getFocusedWindow(), let screen = NSScreen.main else { return }
    let f = screen.visibleFrame
    var pos = CGPoint(x: f.origin.x, y: f.origin.y)
    var size = CGSize(width: f.width, height: f.height / 2)
    AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}

func tileBottomHalf() {
    guard let win = getFocusedWindow(), let screen = NSScreen.main else { return }
    let f = screen.visibleFrame
    var pos = CGPoint(x: f.origin.x, y: f.origin.y + f.height / 2)
    var size = CGSize(width: f.width, height: f.height / 2)
    AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &pos)!)
    AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}



struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                LeftHalfIcon()
                KeyboardShortcuts.Recorder(for: .leftHalf)
            }
            HStack {
                RightHalfIcon()
                KeyboardShortcuts.Recorder(for: .rightHalf)
            }
            HStack {
                TopHalfIcon()
                KeyboardShortcuts.Recorder(for: .topHalf)
            }
            HStack {
                BottomHalfIcon()
                KeyboardShortcuts.Recorder(for: .bottomHalf)
            }
        }
        .padding()
    }
}

@main
struct TileApp: App {
    init() {
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary)
        }
        KeyboardShortcuts.onKeyUp(for: .leftHalf) { tileLeftHalf() }
        KeyboardShortcuts.onKeyUp(for: .rightHalf) { tileRightHalf() }
        KeyboardShortcuts.onKeyUp(for: .topHalf) { tileTopHalf() }
        KeyboardShortcuts.onKeyUp(for: .bottomHalf) { tileBottomHalf() }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
