import AppKit
import CoreLocation
import DNSChangerCore
import SwiftUI

/// Settings, one pane per part of the app, picked from a sidebar (like Calendar Hub's).
struct SettingsView: View {
    /// The pane shown, kept between openings. The menu sets it to open Settings at a given pane.
    @AppStorage(SettingsPane.defaultsKey) private var pane: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: Binding(get: { pane }, set: { if let picked = $0 { pane = picked } })) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    Image(systemName: pane.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(pane.color.gradient, in: RoundedRectangle(cornerRadius: 5))
                }
                .tag(pane)
            }
            .navigationSplitViewColumnWidth(200)
            .frame(minWidth: 200)
        } detail: {
            pane.content
                .navigationTitle(pane.title)
        }
        .frame(width: 780, height: 540)
        .toggleStyle(AccentSwitchStyle())
        .background(SettingsWindowReader())
        .onAppear { SettingsWindow.bringToFront() }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, providers, networks, automation, whyProfiles, about

    /// Where the shown pane is kept.
    static let defaultsKey = "settingsPane"

    var id: Self { self }

    var title: String {
        switch self {
        case .general: return "General"
        case .providers: return "Providers"
        case .networks: return "Wi-Fi networks"
        case .automation: return "Automation"
        case .whyProfiles: return "Why Profiles"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .providers: return "server.rack"
        case .networks: return "wifi"
        case .automation: return "link"
        case .whyProfiles: return "checkmark.seal.fill"
        case .about: return "info"
        }
    }

    var color: Color {
        switch self {
        case .general, .about: return .gray
        case .providers: return .blue
        case .networks: return .teal
        case .automation: return .purple
        case .whyProfiles: return .orange
        }
    }

    @MainActor @ViewBuilder
    var content: some View {
        switch self {
        case .general: GeneralTab()
        case .providers: ProvidersTab()
        case .networks: NetworksTab()
        case .automation: AutomationTab()
        case .whyProfiles: WhyProfilesTab()
        case .about: AboutTab()
        }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Provider for Turn On", selection: $model.settings.toggleHost) {
                    ForEach(model.settings.presets) { preset in
                        Text(preset.name).tag(preset.host)
                    }
                }
                Toggle("Toggle cycles through favourites", isOn: $model.settings.cycleFavorites)
                Text("With two or more favourites, Toggle (⌘T or privatedns://toggle) steps Off → favourite 1 → favourite 2 → … → Off.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Switch back if the provider doesn't answer", isOn: $model.settings.safeSwitching)
                Text("After a switch the app looks up a few well-known names. If none resolve within \(Int(Health.switchTimeout)) seconds while you're online, it restores the previous setting.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
            }

            Section("How DNS is changed") {
                switch model.backend.kind {
                case .networkExtension:
                    LabeledContent("Method", value: "Network Extension (DNS over TLS)")
                    LabeledContent("Allowed in System Settings", value: model.enabledInSystem ? "Yes" : "Not yet")
                    if !model.enabledInSystem {
                        Text("macOS asks once: open System Settings → Network → Filters (VPN & Filters on macOS 13–14) and turn on “Private DNS Menu Bar”.")
                            .font(.caption)
                        Button("Open System Settings") { SystemSettings.open(.network) }
                    }
                case .profile:
                    LabeledContent("Method", value: "Configuration profiles (DNS over TLS)")
                    Text("This build isn't signed with Apple's Network Extension entitlement, so each switch creates a profile that you install in System Settings → Privacy & Security → Profiles. Why Profiles, in the sidebar, explains why.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Profiles") { SystemSettings.open(.profiles) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Providers

private struct ProvidersTab: View {
    @EnvironmentObject private var model: AppModel
    @State private var newHost = ""
    @State private var newName = ""
    @State private var nextDNSID = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    let presets = model.settings.presets.filter { $0.category == category }
                    if !presets.isEmpty {
                        Section(category.title) {
                            ForEach(presets) { preset in ProviderRow(preset: preset) }
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            GroupBox("Add a provider") {
                VStack(alignment: .leading) {
                    HStack {
                        TextField("DNS-over-TLS hostname, e.g. dns.example.com", text: $newHost)
                        TextField("Name (optional)", text: $newName).frame(width: 140)
                        Button("Add") {
                            if model.settings.addCustom(host: newHost, name: newName) {
                                newHost = ""
                                newName = ""
                                message = nil
                            } else {
                                message = "That isn't a valid hostname."
                            }
                        }
                        .disabled(newHost.isEmpty)
                    }
                    HStack {
                        TextField("NextDNS configuration ID", text: $nextDNSID)
                        Button("Add NextDNS") {
                            if model.addNextDNS(id: nextDNSID) {
                                nextDNSID = ""
                                message = nil
                            } else {
                                message = "A NextDNS ID is 4–32 letters and digits, e.g. abc123."
                            }
                        }
                        .disabled(nextDNSID.isEmpty)
                    }
                    if let message { Text(message).font(.caption).foregroundStyle(.red) }
                }
            }
        }
        .padding()
    }
}

private struct ProviderRow: View {
    @EnvironmentObject private var model: AppModel
    let preset: DNSPreset
    @State private var showInfo = false
    @State private var renaming = false
    @State private var name = ""

    var body: some View {
        HStack {
            Button {
                model.settings.setFavorite(preset.host, !model.settings.favorites.contains(preset.host))
            } label: {
                Image(systemName: model.settings.favorites.contains(preset.host) ? "star.fill" : "star")
                    .foregroundStyle(model.settings.favorites.contains(preset.host) ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Favourite: listed at the top of the menu")

            VStack(alignment: .leading) {
                Text(preset.name)
                Text(preset.host).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.state.host == preset.host {
                Text("In use").font(.caption).foregroundStyle(.green)
            }
            if let info = ProviderInfo.forHost(preset.host) {
                Button { showInfo.toggle() } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showInfo) { ProviderInfoView(preset: preset, info: info) }
            }
            if !preset.builtIn {
                Button { name = preset.name == preset.host ? "" : preset.name; renaming = true } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $renaming) {
                        HStack {
                            TextField("Name", text: $name).frame(width: 180)
                            Button("Save") {
                                model.settings.renameCustom(host: preset.host, name: name)
                                renaming = false
                            }
                        }
                        .padding()
                    }
                Button { model.settings.removeCustom(host: preset.host) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            Button("Use") { Task { await model.select(preset.host) } }
                .disabled(model.state.host == preset.host)
        }
    }
}

private struct ProviderInfoView: View {
    let preset: DNSPreset
    let info: PresetInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preset.name).font(.headline)
            LabeledContent("Run by", value: info.provider.operatorName)
            LabeledContent("Based in", value: info.provider.basedIn)
            Text(info.provider.about)
            Text("Blocks: ").bold() + Text(info.blocks)
            Text("Privacy: ").bold() + Text(info.provider.privacy)
            HStack {
                Link("Website", destination: info.provider.website)
                Link("Privacy policy", destination: info.provider.privacyPolicy)
            }
        }
        .frame(width: 340)
        .padding()
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Wi-Fi networks: see NetworksTab.swift

// MARK: - Automation

private struct AutomationTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Allow automation", isOn: $model.settings.automationEnabled)
                Text("Shortcuts (Open URLs), scripts and automation apps can control Private DNS by opening privatedns:// links. Links without your token are ignored, so a web page can't change your DNS.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Token") {
                HStack {
                    Text(model.settings.automationToken).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Button("Copy") { copy(model.settings.automationToken) }
                    Button("New token") { model.settings.automationToken = AppSettings.newToken() }
                        .help("The old token stops working")
                }
            }
            Section("Links") {
                ForEach(examples, id: \.self) { url in
                    HStack {
                        Text(url).font(.system(.caption, design: .monospaced)).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Copy") { copy(url) }
                    }
                }
                Text("From Terminal: open \"privatedns://pause?minutes=10&token=…\"")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!model.settings.automationEnabled)
        }
        .formStyle(.grouped)
    }

    private var examples: [String] {
        let token = model.settings.automationToken
        return [
            DNSCommand.exampleURL("on", token: token),
            DNSCommand.exampleURL("on", token: token, extra: "&host=dns.quad9.net"),
            DNSCommand.exampleURL("off", token: token),
            DNSCommand.exampleURL("toggle", token: token),
            DNSCommand.exampleURL("pause", token: token, extra: "&minutes=30"),
            DNSCommand.exampleURL("resume", token: token),
        ]
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
