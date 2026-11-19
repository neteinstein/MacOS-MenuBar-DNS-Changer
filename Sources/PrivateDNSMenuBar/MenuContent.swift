import AppKit
import DNSChangerCore
import SwiftUI

/// The menu shown when clicking the menu bar icon.
struct MenuContent: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updates: UpdateChecker

    var body: some View {
        statusSection
        Divider()
        providersSection
        footerSection
    }

    @ViewBuilder private var statusSection: some View {
        Text(statusLine)
        if let detail = detailLine { Text(detail) }

        if !model.enabledInSystem {
            Button("Allow in System Settings…") { SystemSettings.open(.network) }
        }

        primaryAction

        if model.settings.pause == nil {
            Menu("Pause") {
                ForEach(Pause.presetMinutes, id: \.self) { minutes in
                    Button(minutes >= 60 ? "\(minutes / 60) hour" : "\(minutes) minutes") {
                        Task { await model.pause(minutes: minutes) }
                    }
                }
            }
            .disabled(!model.state.isOn)
        }
    }

    @ViewBuilder private var providersSection: some View {
        if !model.settings.favoritePresets.isEmpty {
            Section("Favourites") {
                ForEach(model.settings.favoritePresets) { preset in providerItem(preset) }
            }
            Divider()
        }

        Menu("Providers") {
            ForEach(PresetCategory.allCases, id: \.self) { category in
                categoryMenu(category)
            }
        }

        if let host = model.state.host {
            ProviderInfoMenu(host: host, name: model.settings.name(of: host))
        }
    }

    @ViewBuilder private func categoryMenu(_ category: PresetCategory) -> some View {
        let presets = model.settings.presets.filter { $0.category == category }
        if !presets.isEmpty {
            Menu(category.title) {
                ForEach(presets) { preset in providerItem(preset) }
            }
        }
    }

    @ViewBuilder private var footerSection: some View {
        if let error = model.lastError {
            Divider()
            Text("⚠︎ " + error)
            Button("Dismiss") { model.lastError = nil }
        }

        Divider()

        if let latest = updates.available {
            Button("Update to Version \(latest.version)…") { model.confirmUpdate(to: latest) }
        }
        Button("Donate…") { Support.donate() }
        settingsButton
        Button("Quit Private DNS") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var primaryAction: some View {
        if model.settings.pause != nil {
            Button("Resume now") { Task { await model.resume() } }
        } else {
            switch model.toggleTarget {
            case .off:
                Button("Turn Off") { Task { await model.toggle() } }
                    .keyboardShortcut("t")
            case let .on(host):
                Button(model.state.isOn ? "Switch to \(model.settings.name(of: host))" : "Turn On (\(model.settings.name(of: host)))") {
                    Task { await model.toggle() }
                }
                .keyboardShortcut("t")
            }
        }
    }

    private func providerItem(_ preset: DNSPreset) -> some View {
        Toggle(preset.name, isOn: Binding(
            get: { model.state.host == preset.host },
            set: { on in
                Task {
                    if on { await model.select(preset.host) } else { await model.turnOff() }
                }
            }
        ))
    }

    @ViewBuilder private var settingsButton: some View {
        if #available(macOS 14, *) {
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",")
        } else {
            Button("Settings…") { AppModel.openSettingsWindow() }
                .keyboardShortcut(",")
        }
    }

    private var statusLine: String {
        if model.busy { return "Private DNS: switching…" }
        if let remaining = model.pauseRemaining { return "Private DNS: paused (\(remaining) left)" }
        guard let name = model.currentName else { return "Private DNS: Off" }
        return "Private DNS: \(name)"
    }

    private var detailLine: String? {
        guard model.state.isOn, model.settings.pause == nil else { return nil }
        if !model.enabledInSystem { return "Not in use: allow it in System Settings → Network → Filters" }
        if model.backend.kind == .profile { return "Applied by configuration profile" }
        if model.suspendedByRule { return "Not in use on this network (network rule)" }
        switch model.health {
        case .answering: return "✓ Provider is answering"
        case .notAnswering: return "✗ Provider is not answering"
        case .checking: return "Checking the provider…"
        case .unknown: return model.online ? nil : "Offline"
        }
    }
}

/// Who runs the provider in use and what it blocks.
struct ProviderInfoMenu: View {
    let host: String
    let name: String

    var body: some View {
        Menu("About \(name)") {
            Text(host)
            if let info = ProviderInfo.forHost(host) {
                Text("Run by \(info.provider.operatorName), \(info.provider.basedIn)")
                Divider()
                Text("Blocks: " + info.blocks)
                Text(info.provider.privacy)
                Divider()
                Button("Website") { NSWorkspace.shared.open(info.provider.website) }
                Button("Privacy policy") { NSWorkspace.shared.open(info.provider.privacyPolicy) }
            } else {
                Text("A provider you added.")
            }
        }
    }
}
