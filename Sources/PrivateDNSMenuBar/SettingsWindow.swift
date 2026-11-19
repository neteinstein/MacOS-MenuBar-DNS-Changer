import AppKit
import SwiftUI

/// The Settings window, and bringing it in front of other apps.
///
/// A menu bar app has no Dock icon and isn't the active app when its menu is used, so the window
/// SwiftUI opens can end up behind other apps' windows, and stays there if it was already open:
/// either way, nothing seems to happen. Like Calendar Hub's `showSettings`.
@MainActor
enum SettingsWindow {
    /// The window SwiftUI put the Settings view in, told by `SettingsWindowReader`.
    static weak var window: NSWindow?

    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        // After the click (or the view's appearance) has been handled: by then SwiftUI has shown
        // the window.
        DispatchQueue.main.async {
            // Only a window that's on screen: SwiftUI can keep a closed one around.
            guard let window = SettingsWindow.window, window.isVisible else { return }
            window.makeKeyAndOrderFront(nil)
            // macOS doesn't always let a menu bar app become the active one. This puts the window
            // on top all the same.
            window.orderFrontRegardless()
        }
    }
}

/// Tells `SettingsWindow` which window the Settings view is in. Goes in its background.
struct SettingsWindowReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ReaderView() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ReaderView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { SettingsWindow.window = window }
        }
    }
}

/// For the menu's `SettingsLink` (macOS 14 and later), which has no action of its own to add to:
/// runs the link's action, then brings the window to the front.
struct BringSettingsToFrontButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            configuration.trigger()
            SettingsWindow.bringToFront()
        } label: {
            configuration.label
        }
    }
}
