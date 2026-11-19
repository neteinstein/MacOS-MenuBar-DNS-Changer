import AppKit
import DNSChangerCore
import SwiftUI

/// Settings › Wi-Fi networks: a section per network, each with its own setting, like Calendar
/// Hub's section per secondary calendar.
struct NetworksTab: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var location = LocationAccess.shared
    @State private var newSSID = ""

    private var rules: NetworkRules { model.settings.rules }

    private func binding(_ keyPath: WritableKeyPath<NetworkRules, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings.rules[keyPath: keyPath] },
            set: { value in model.updateRules { $0[keyPath: keyPath] = value } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Toggle("Use network settings", isOn: binding(\.enabled))
                } footer: {
                    Text("While Private DNS is on, a Wi-Fi network can use its own DNS servers (a hotel sign-in page, an office's internal names) or a different provider. Your usual provider comes back when you leave it.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                CurrentNetworkSection(newSSID: $newSSID)

                ForEach(rules.networks) { network in
                    NetworkSection(network: network)
                }
                .disabled(!rules.enabled)

                Section("Everywhere else") {
                    Toggle("Turn off on any other Wi-Fi network", isOn: binding(\.offOnWiFi))
                    Toggle("Turn off on Ethernet", isOn: binding(\.offOnEthernet))
                }
                .disabled(!rules.enabled)
            }
            .formStyle(.grouped)

            HStack {
                TextField("Wi-Fi network name", text: $newSSID)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .onSubmit(add)
                Button("Add network", action: add)
                    .disabled(newSSID.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding()
        }
    }

    private func add() {
        let ssid = newSSID
        model.updateRules { rules in
            rules.enabled = true
            rules.addNetwork(ssid)
        }
        newSSID = ""
    }
}

/// The network the Mac is on, with a button to give it its own setting.
private struct CurrentNetworkSection: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var location = LocationAccess.shared
    @Binding var newSSID: String

    var body: some View {
        Section("Connected now") {
            switch model.network.kind {
            case .wifi:
                if let ssid = model.network.ssid {
                    HStack {
                        Label(ssid, systemImage: "wifi")
                        Spacer()
                        if model.settings.rules.networks.contains(where: { $0.ssid == ssid }) {
                            Text(status(for: ssid)).foregroundStyle(.secondary)
                        } else {
                            Button("Add this network") {
                                model.updateRules { rules in
                                    rules.enabled = true
                                    rules.addNetwork(ssid)
                                }
                            }
                        }
                    }
                } else {
                    HStack {
                        Label("Wi-Fi", systemImage: "wifi")
                        Spacer()
                        Button(location.isDenied ? "Open Location Services…" : "Show network name") { location.request() }
                    }
                    Text("macOS shows the Wi-Fi network's name only to apps with Location Services access. It's only used to show it here and to switch provider on networks that use their own. Or type the name below.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .ethernet:
                Label("Ethernet", systemImage: "cable.connector")
            case nil:
                Label("Not connected", systemImage: "wifi.slash").foregroundStyle(.secondary)
            }
        }
    }

    private func status(for ssid: String) -> String {
        if isSuspendedByRule(model.network, state: model.state, rules: model.settings.rules) { return "Private DNS off here" }
        if let host = model.networkProvider { return "Using \(model.settings.name(of: host))" }
        return "Using your provider"
    }
}

/// One Wi-Fi network's setting.
private struct NetworkSection: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var location = LocationAccess.shared
    let network: WiFiNetwork
    @State private var confirmingRemoval = false

    /// "off", or a provider's hostname.
    private var choice: Binding<String> {
        Binding(
            get: { network.action.host ?? "off" },
            set: { value in
                model.updateRules { $0.setAction(value == "off" ? .off : .provider(value), for: network.ssid) }
            }
        )
    }

    private var canUseOwnProvider: Bool { model.backend.kind == .networkExtension }

    var body: some View {
        Section {
            Picker("On this network", selection: choice) {
                Text("Turn Private DNS off").tag("off")
                if canUseOwnProvider || network.action.host != nil {
                    Divider()
                    ForEach(PresetCategory.allCases, id: \.self) { category in
                        let presets = model.settings.presets.filter { $0.category == category }
                        if !presets.isEmpty {
                            Section(category.title) {
                                ForEach(presets) { preset in Text("Use \(preset.name)").tag(preset.host) }
                            }
                        }
                    }
                }
            }
            note
            HStack {
                Spacer()
                Button("Remove", role: .destructive) { confirmingRemoval = true }
                    .confirmationDialog("Remove “\(network.ssid)”?", isPresented: $confirmingRemoval) {
                        Button("Remove Network", role: .destructive) {
                            let ssid = network.ssid
                            // On the next run loop, so SwiftUI isn't still reading this section.
                            DispatchQueue.main.async { model.updateRules { $0.removeNetwork(ssid) } }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Private DNS will treat it like any other network.")
                    }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "wifi")
                Text(network.ssid)
                if model.network.kind == .wifi, model.network.ssid == network.ssid {
                    Text("Connected").font(.caption).foregroundStyle(.green)
                }
            }
        }
    }

    @ViewBuilder private var note: some View {
        if network.action == .off {
            Text("macOS uses the network's own DNS servers here, even while the app is closed.")
                .font(.caption).foregroundStyle(.secondary)
        } else if !canUseOwnProvider {
            Text("A provider of its own needs the Network Extension build: with configuration profiles, each switch would be a profile to install. Choose “Turn Private DNS off” or remove the network.")
                .font(.caption).foregroundStyle(.orange)
        } else if !location.isGranted {
            HStack {
                Text("Switching provider on this network needs Location Services access, to read the network's name.")
                    .font(.caption).foregroundStyle(.orange)
                Spacer()
                Button(location.isDenied ? "Open Location Services…" : "Allow") { location.request() }
            }
        } else {
            Text("The app switches to this provider when you join the network, and back when you leave. It needs to be running.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
