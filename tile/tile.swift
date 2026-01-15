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

struct ShortcutRow: View {
    let icon: AnyView
    let label: String
    let shortcutName: KeyboardShortcuts.Name

    var body: some View {
        HStack() {
            HStack() {
                icon
                Text(label)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 90, alignment: .leading)

            KeyboardShortcuts.Recorder(for: shortcutName)
        }
       
    }
}

struct ContentView: View {
    var body: some View {
        VStack() {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Tile")
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
//            .padding(.bottom, 20)

            VStack() {
                ShortcutRow(
                    icon: AnyView(LeftHalfIcon()),
                    label: "Left",
                    shortcutName: .leftHalf
                )
                ShortcutRow(
                    icon: AnyView(RightHalfIcon()),
                    label: "Right",
                    shortcutName: .rightHalf
                )
                ShortcutRow(
                    icon: AnyView(TopHalfIcon()),
                    label: "Top",
                    shortcutName: .topHalf
                )
                ShortcutRow(
                    icon: AnyView(BottomHalfIcon()),
                    label: "Bottom",
                    shortcutName: .bottomHalf
                )
            }
        }
        .padding(24)
        .frame(minWidth: 150)
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

        DispatchQueue.main.async {
            NSApp.deactivate()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "square.grid.2x2")
        }
        .menuBarExtraStyle(.window)
    }
}
