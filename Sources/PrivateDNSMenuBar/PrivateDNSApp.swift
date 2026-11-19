import AppKit
import DNSChangerCore
import SwiftUI

@main
struct PrivateDNSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(model)
        } label: {
            Image(systemName: model.menuBarSymbol)
                .accessibilityLabel(model.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // privatedns:// URLs from Shortcuts, scripts and automation apps. Registered here rather than
        // with .onOpenURL because a menu bar extra has no window to receive it.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in AppModel.shared.start() }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        Task { @MainActor in AppModel.shared.handle(url: url) }
    }
}

extension AppModel {
    var menuBarSymbol: String {
        if settings.pause != nil { return "pause.circle" }
        if !state.isOn { return "lock.open" }
        if !enabledInSystem || suspendedByRule { return "lock.trianglebadge.exclamationmark" }
        if health == .notAnswering { return "exclamationmark.lock" }
        return "lock.shield.fill"
    }

    var menuBarAccessibilityLabel: String {
        if settings.pause != nil { return "Private DNS paused" }
        return state.isOn ? "Private DNS on: \(currentName ?? "")" : "Private DNS off"
    }

    /// Opens the Settings window and brings this (Dock-less) app to the front.
    static func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            // Handled by SettingsLink in the menu.
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
