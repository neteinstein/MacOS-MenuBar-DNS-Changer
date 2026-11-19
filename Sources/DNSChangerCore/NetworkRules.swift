import Foundation

public enum NetworkKind: String, Codable, CaseIterable, Sendable {
    case wifi
    case ethernet

    public var title: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        }
    }
}

/// Where encrypted DNS should stay off. macOS evaluates these itself (as "on-demand rules" of the
/// DNS configuration), so they keep working while the app is closed, and unlike on Android they can
/// match Wi-Fi networks by name without location access.
public struct NetworkRules: Hashable, Codable, Sendable {
    public var enabled: Bool = false
    public var offOnWiFi: Bool = false
    public var offOnEthernet: Bool = false
    /// Wi-Fi networks (SSIDs) where encrypted DNS stays off, e.g. a captive-portal hotel network or
    /// an office network whose internal names only its own DNS server knows.
    public var offOnSSIDs: [String] = []

    public init(enabled: Bool = false, offOnWiFi: Bool = false, offOnEthernet: Bool = false, offOnSSIDs: [String] = []) {
        self.enabled = enabled
        self.offOnWiFi = offOnWiFi
        self.offOnEthernet = offOnEthernet
        self.offOnSSIDs = offOnSSIDs
    }

    /// Adds [ssid] if it is not blank and not already listed. SSIDs are case-sensitive.
    public mutating func addSSID(_ ssid: String) {
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !offOnSSIDs.contains(trimmed) else { return }
        offOnSSIDs.append(trimmed)
    }

    public var isEffective: Bool { enabled && (offOnWiFi || offOnEthernet || !offOnSSIDs.isEmpty) }
}

/// A platform-neutral on-demand rule. The app maps these to `NEOnDemandRule`s and the profile
/// exporter to `OnDemandRules` dictionaries. The system uses the first rule that matches.
public struct OnDemandRule: Hashable, Sendable {
    public enum Action: String, Sendable {
        /// Use the encrypted DNS settings.
        case connect = "Connect"
        /// Don't: the network's own DNS servers are used.
        case disconnect = "Disconnect"
    }

    public var action: Action
    public var interface: NetworkKind?
    public var ssids: [String]

    public init(action: Action, interface: NetworkKind? = nil, ssids: [String] = []) {
        self.action = action
        self.interface = interface
        self.ssids = ssids
    }
}

/// The on-demand rules for [state]. Off is expressed as a single "never" rule instead of removing
/// the configuration, so that the user does not have to enable it in System Settings again.
public func onDemandRules(for state: DNSState, rules: NetworkRules) -> [OnDemandRule] {
    guard state.isOn else { return [OnDemandRule(action: .disconnect)] }
    var result: [OnDemandRule] = []
    if rules.enabled {
        if !rules.offOnSSIDs.isEmpty {
            result.append(OnDemandRule(action: .disconnect, interface: .wifi, ssids: rules.offOnSSIDs))
        }
        if rules.offOnWiFi { result.append(OnDemandRule(action: .disconnect, interface: .wifi)) }
        if rules.offOnEthernet { result.append(OnDemandRule(action: .disconnect, interface: .ethernet)) }
    }
    result.append(OnDemandRule(action: .connect))
    return result
}

/// The network the Mac is on, as far as rules care.
public struct NetworkSnapshot: Hashable, Sendable {
    public var kind: NetworkKind?
    public var ssid: String?

    public init(kind: NetworkKind?, ssid: String? = nil) {
        self.kind = kind
        self.ssid = ssid
    }
}

/// Whether [rules] keep encrypted DNS off on [network]: used to explain in the menu why a provider
/// that is "on" is not being used right now. Evaluates like the system does: first match wins.
public func isSuspendedByRule(_ network: NetworkSnapshot, state: DNSState, rules: NetworkRules) -> Bool {
    for rule in onDemandRules(for: state, rules: rules) {
        if let interface = rule.interface, interface != network.kind { continue }
        if !rule.ssids.isEmpty {
            guard let ssid = network.ssid, rule.ssids.contains(ssid) else { continue }
        }
        return rule.action == .disconnect
    }
    return false
}
