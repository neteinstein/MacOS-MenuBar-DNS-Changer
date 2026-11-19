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

/// What Private DNS does on one Wi-Fi network.
public enum NetworkAction: Hashable, Codable, Sendable {
    /// Use the network's own DNS servers (a hotel sign-in page, an office's internal names).
    case off
    /// Use this provider instead of the usual one.
    case provider(String)

    public var host: String? {
        if case let .provider(host) = self { return host }
        return nil
    }
}

/// A Wi-Fi network with its own setting, by name (SSID). SSIDs are case-sensitive.
public struct WiFiNetwork: Hashable, Codable, Identifiable, Sendable {
    public var ssid: String
    public var action: NetworkAction

    public var id: String { ssid }

    public init(ssid: String, action: NetworkAction = .off) {
        self.ssid = ssid
        self.action = action
    }
}

/// Per-network settings.
///
/// "Off" settings become on-demand rules of the DNS configuration, which macOS evaluates itself:
/// they keep working while the app is closed and match Wi-Fi networks by name without location
/// access. A different provider on a network is a switch the app makes when the Mac joins it, so
/// that needs the app running and, to read the network's name, Location Services access.
public struct NetworkRules: Hashable, Codable, Sendable {
    public var enabled: Bool = false
    /// Off on any Wi-Fi network that has no setting of its own.
    public var offOnWiFi: Bool = false
    public var offOnEthernet: Bool = false
    public var networks: [WiFiNetwork] = []

    public init(enabled: Bool = false, offOnWiFi: Bool = false, offOnEthernet: Bool = false, networks: [WiFiNetwork] = []) {
        self.enabled = enabled
        self.offOnWiFi = offOnWiFi
        self.offOnEthernet = offOnEthernet
        self.networks = networks
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, offOnWiFi, offOnEthernet, networks
        /// Up to 0.1.0: a list of networks where it was off.
        case offOnSSIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        offOnWiFi = try c.decodeIfPresent(Bool.self, forKey: .offOnWiFi) ?? false
        offOnEthernet = try c.decodeIfPresent(Bool.self, forKey: .offOnEthernet) ?? false
        if let networks = try c.decodeIfPresent([WiFiNetwork].self, forKey: .networks) {
            self.networks = networks
        } else {
            networks = (try c.decodeIfPresent([String].self, forKey: .offOnSSIDs) ?? []).map { WiFiNetwork(ssid: $0) }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(offOnWiFi, forKey: .offOnWiFi)
        try c.encode(offOnEthernet, forKey: .offOnEthernet)
        try c.encode(networks, forKey: .networks)
    }

    /// Adds [ssid] if it is not blank and not already listed. Returns whether it was added.
    @discardableResult
    public mutating func addNetwork(_ ssid: String, action: NetworkAction = .off) -> Bool {
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !networks.contains(where: { $0.ssid == trimmed }) else { return false }
        networks.append(WiFiNetwork(ssid: trimmed, action: action))
        return true
    }

    public mutating func setAction(_ action: NetworkAction, for ssid: String) {
        guard let index = networks.firstIndex(where: { $0.ssid == ssid }) else { return }
        networks[index].action = action
    }

    public mutating func removeNetwork(_ ssid: String) {
        networks.removeAll { $0.ssid == ssid }
    }

    /// The SSIDs where it's off.
    public var offSSIDs: [String] { networks.filter { $0.action == .off }.map(\.ssid) }

    /// Whether any network uses a provider of its own (which needs the app and Location access).
    public var hasProviderNetworks: Bool { networks.contains { $0.action.host != nil } }

    public var isEffective: Bool { enabled && (offOnWiFi || offOnEthernet || !networks.isEmpty) }

    /// The provider [network] should use instead of the usual one, if it has one.
    public func provider(for network: NetworkSnapshot) -> String? {
        guard enabled, network.kind == .wifi, let ssid = network.ssid else { return nil }
        return networks.first { $0.ssid == ssid }?.action.host
    }
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
/// Networks with their own provider get a "use it" rule ahead of the general Wi-Fi one, so that
/// "off on any Wi-Fi" doesn't catch them.
public func onDemandRules(for state: DNSState, rules: NetworkRules) -> [OnDemandRule] {
    guard state.isOn else { return [OnDemandRule(action: .disconnect)] }
    var result: [OnDemandRule] = []
    if rules.enabled {
        let off = rules.offSSIDs
        if !off.isEmpty {
            result.append(OnDemandRule(action: .disconnect, interface: .wifi, ssids: off))
        }
        let own = rules.networks.filter { $0.action.host != nil }.map(\.ssid)
        if !own.isEmpty, rules.offOnWiFi {
            result.append(OnDemandRule(action: .connect, interface: .wifi, ssids: own))
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

/// What the app does when the network changes, for networks with a provider of their own.
public struct RuleSwitch: Hashable, Sendable {
    /// Switch to this, or nil to leave DNS alone.
    public var target: DNSState?
    /// The provider to go back to after leaving a network with its own, remembered in settings.
    public var returnHost: String?

    public init(target: DNSState?, returnHost: String?) {
        self.target = target
        self.returnHost = returnHost
    }
}

/// On a network with its own provider, switches to it and remembers the one in use to come back
/// to. On leaving it, goes back, unless the provider was changed by hand in the meantime. Leaves
/// DNS alone while it's off or paused, and while the Mac is between networks.
public func ruleSwitch(network: NetworkSnapshot, state: DNSState, rules: NetworkRules, returnHost: String?) -> RuleSwitch {
    guard network.kind != nil, let current = state.host else { return RuleSwitch(target: nil, returnHost: returnHost) }
    if let own = rules.provider(for: network) {
        if own == current { return RuleSwitch(target: nil, returnHost: returnHost) }
        return RuleSwitch(target: .on(host: own), returnHost: returnHost ?? current)
    }
    guard let back = returnHost else { return RuleSwitch(target: nil, returnHost: nil) }
    let setByRule = rules.networks.contains { $0.action.host == current }
    if setByRule, back != current { return RuleSwitch(target: .on(host: back), returnHost: nil) }
    return RuleSwitch(target: nil, returnHost: nil)
}
