import AppKit
import DNSChangerCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            ProvidersTab().tabItem { Label("Providers", systemImage: "server.rack") }
            RulesTab().tabItem { Label("Networks", systemImage: "wifi") }
            AutomationTab().tabItem { Label("Automation", systemImage: "gearshape.2") }
        }
        .frame(width: 560, height: 460)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
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
                    Text("This build isn't signed with Apple's Network Extension entitlement, so each switch creates a profile that you install in System Settings → Privacy & Security → Profiles. A build signed with the entitlement switches instantly; see the README.")
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

// MARK: - Network rules

private struct RulesTab: View {
    @EnvironmentObject private var model: AppModel
    @State private var newSSID = ""

    private func binding(_ keyPath: WritableKeyPath<NetworkRules, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings.rules[keyPath: keyPath] },
            set: { value in model.updateRules { $0[keyPath: keyPath] = value } }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Use network rules", isOn: binding(\.enabled))
                Text("While Private DNS is on, these networks use their own DNS servers instead, e.g. a hotel Wi-Fi with a sign-in page or an office network with internal names. macOS applies the rules itself, even while the app is closed. Your provider comes back as soon as you leave.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Turn off on") {
                Toggle("Any Wi-Fi network", isOn: binding(\.offOnWiFi))
                Toggle("Ethernet", isOn: binding(\.offOnEthernet))
            }
            .disabled(!model.settings.rules.enabled)

            Section("These Wi-Fi networks") {
                ForEach(model.settings.rules.offOnSSIDs, id: \.self) { ssid in
                    HStack {
                        Text(ssid)
                        Spacer()
                        Button { model.updateRules { rules in rules.offOnSSIDs.removeAll { $0 == ssid } } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("Network name (SSID)", text: $newSSID)
                    Button("Add") {
                        let ssid = newSSID
                        model.updateRules { $0.addSSID(ssid) }
                        newSSID = ""
                    }
                    .disabled(newSSID.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let current = NetworkMonitor.currentSSID(), !model.settings.rules.offOnSSIDs.contains(current) {
                        Button("Add “\(current)”") { model.updateRules { $0.addSSID(current) } }
                    }
                }
            }
            .disabled(!model.settings.rules.enabled)
        }
        .formStyle(.grouped)
    }
}

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
