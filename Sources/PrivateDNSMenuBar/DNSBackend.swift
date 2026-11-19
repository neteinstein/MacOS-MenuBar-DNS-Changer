import AppKit
import DNSChangerCore
import Foundation
import NetworkExtension
import Security

/// What the backend knows about the system's DNS configuration.
struct BackendStatus {
    var state: DNSState
    /// For the Network Extension backend: whether the user turned the configuration on in System
    /// Settings. Until then macOS ignores it (the macOS version of Android's one-time `pm grant`).
    var enabledInSystem: Bool
}

enum BackendKind {
    case networkExtension
    case profile
}

protocol DNSBackend {
    var kind: BackendKind { get }
    func load() async throws -> BackendStatus
    /// Writes [state] with [rules]. [addresses] are the resolver's IPs (bootstrap addresses).
    func apply(_ state: DNSState, rules: [OnDemandRule], addresses: [String], displayName: String) async throws
}

enum BackendError: LocalizedError {
    case noAddresses(String)

    var errorDescription: String? {
        switch self {
        case let .noAddresses(host):
            return "Couldn't find the address of \(host). Check the hostname and your connection."
        }
    }
}

enum Backends {
    /// The Network Extension backend needs the `dns-settings` entitlement, which only a build
    /// signed with a provisioning profile has. Everything else falls back to profiles.
    static func make() -> DNSBackend {
        hasDNSSettingsEntitlement ? NetworkExtensionBackend() : ProfileBackend()
    }

    static var hasDNSSettingsEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.networking.networkextension" as CFString, nil)
        return (value as? [String])?.contains("dns-settings") ?? false
    }
}

// MARK: - Network Extension

/// System-wide DNS over TLS through `NEDNSSettingsManager` (macOS 11+). Switching providers is
/// instant and needs no password once the configuration is enabled in System Settings.
///
/// "Off" keeps the configuration but sets a single "never" on-demand rule, so the user does not have
/// to enable it in System Settings again the next time it's turned on.
struct NetworkExtensionBackend: DNSBackend {
    let kind = BackendKind.networkExtension
    private var manager: NEDNSSettingsManager { NEDNSSettingsManager.shared() }

    func load() async throws -> BackendStatus {
        try await manager.loadFromPreferences()
        let host = (manager.dnsSettings as? NEDNSOverTLSSettings)?.serverName
        let rules = manager.onDemandRules ?? []
        let neverApplied = rules.count == 1 && rules[0] is NEOnDemandRuleDisconnect && rules[0].interfaceTypeMatch == .any
            && (rules[0].ssidMatch ?? []).isEmpty
        let state: DNSState = (host == nil || neverApplied) ? .off : .on(host: host!)
        return BackendStatus(state: state, enabledInSystem: manager.isEnabled)
    }

    func apply(_ state: DNSState, rules: [OnDemandRule], addresses: [String], displayName: String) async throws {
        try await manager.loadFromPreferences()
        manager.localizedDescription = "Private DNS Menu Bar"
        if let host = state.host {
            guard !addresses.isEmpty else { throw BackendError.noAddresses(host) }
            let settings = NEDNSOverTLSSettings(servers: addresses)
            settings.serverName = host
            manager.dnsSettings = settings
        } else if manager.dnsSettings == nil {
            // First save while off: a placeholder resolver that the "never" rule keeps unused.
            let settings = NEDNSOverTLSSettings(servers: ["1.1.1.1"])
            settings.serverName = BuiltInPresets.defaultHost
            manager.dnsSettings = settings
        }
        manager.onDemandRules = rules.map(Self.neRule)
        try await manager.saveToPreferences()
    }

    static func neRule(_ rule: OnDemandRule) -> NEOnDemandRule {
        let ne: NEOnDemandRule = rule.action == .connect ? NEOnDemandRuleConnect() : NEOnDemandRuleDisconnect()
        switch rule.interface {
        case .wifi: ne.interfaceTypeMatch = .wiFi
        case .ethernet: ne.interfaceTypeMatch = .ethernet
        case nil: ne.interfaceTypeMatch = .any
        }
        if !rule.ssids.isEmpty { ne.ssidMatch = rule.ssids }
        return ne
    }
}

// MARK: - Configuration profiles

/// For builds without the entitlement (e.g. built from source without a paid developer account):
/// each switch writes a `.mobileconfig` and hands it to macOS, which asks the user to install it in
/// System Settings → Privacy & Security → Profiles. All profiles share one identifier, so a new one
/// replaces the old one; "Off" is a profile whose only rule is "never".
///
/// macOS doesn't let apps read installed device profiles without admin rights, so the state shown is
/// the last one requested.
struct ProfileBackend: DNSBackend {
    let kind = BackendKind.profile
    private static let stateKey = "profileBackend.state"

    func load() async throws -> BackendStatus {
        var state = DNSState.off
        if let data = UserDefaults.standard.data(forKey: Self.stateKey),
           let saved = try? JSONDecoder().decode(DNSState.self, from: data) {
            state = saved
        }
        return BackendStatus(state: state, enabledInSystem: true)
    }

    func apply(_ state: DNSState, rules: [OnDemandRule], addresses: [String], displayName: String) async throws {
        let host = state.host ?? BuiltInPresets.defaultHost
        let name = state.isOn ? displayName : "Off"
        let data = try MobileConfig.data(host: host, displayName: name, addresses: addresses, rules: rules)
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PrivateDNSMenuBar", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(state.isOn ? MobileConfig.fileName(for: host) : "PrivateDNS-off.mobileconfig")
        try data.write(to: file, options: .atomic)

        UserDefaults.standard.set(try JSONEncoder().encode(state), forKey: Self.stateKey)
        await MainActor.run {
            // Opening the file registers it as a downloaded profile; then show where to install it.
            NSWorkspace.shared.open(file)
            SystemSettings.open(.profiles)
        }
    }
}

enum SystemSettings {
    enum Pane {
        case profiles
        case network
        case loginItems
    }

    @MainActor
    static func open(_ pane: Pane) {
        let candidates: [String]
        switch pane {
        case .profiles:
            candidates = [
                "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
                "x-apple.systempreferences:com.apple.preferences.configurationprofiles",
            ]
        case .network:
            // DNS configurations live under Network → Filters (macOS 15) / VPN & Filters (13–14).
            candidates = [
                "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension",
                "x-apple.systempreferences:com.apple.Network-Settings.extension",
            ]
        case .loginItems:
            candidates = ["x-apple.systempreferences:com.apple.LoginItems-Settings.extension"]
        }
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }
}
