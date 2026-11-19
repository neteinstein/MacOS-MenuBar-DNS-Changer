import Foundation

/// Whether encrypted DNS is in use, and with which resolver.
public enum DNSState: Hashable, Codable, Sendable {
    case off
    case on(host: String)

    public var host: String? {
        if case let .on(host) = self { return host }
        return nil
    }

    public var isOn: Bool { host != nil }
}

/// A provider the user added, with an optional display name.
public struct CustomProvider: Hashable, Codable, Sendable {
    public var host: String
    public var name: String?

    public init(host: String, name: String? = nil) {
        self.host = host
        self.name = name
    }
}

/// Everything the app remembers. Stored as one JSON blob in UserDefaults.
public struct AppSettings: Hashable, Codable, Sendable {
    /// The provider the menu's on/off item, the keyboard shortcut and automation switch on.
    public var toggleHost: String = BuiltInPresets.defaultHost
    public var custom: [CustomProvider] = []
    /// Starred hosts, in no particular order: the menu lists them in preset order.
    public var favorites: Set<String> = []
    /// When on, "Toggle" steps Off → favourite 1 → favourite 2 → … → Off.
    public var cycleFavorites: Bool = false
    /// When on, the app checks the provider answers after a switch and goes back if it doesn't.
    public var safeSwitching: Bool = true
    public var rules: NetworkRules = NetworkRules()
    public var automationEnabled: Bool = false
    public var automationToken: String = AppSettings.newToken()
    public var pause: PauseState?
    /// The provider to go back to after leaving a Wi-Fi network that has its own.
    public var ruleReturnHost: String?

    public init() {}

    // Decode field by field so that settings saved by an older version (missing keys) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        toggleHost = try c.decodeIfPresent(String.self, forKey: .toggleHost) ?? defaults.toggleHost
        custom = try c.decodeIfPresent([CustomProvider].self, forKey: .custom) ?? defaults.custom
        favorites = try c.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? defaults.favorites
        cycleFavorites = try c.decodeIfPresent(Bool.self, forKey: .cycleFavorites) ?? defaults.cycleFavorites
        safeSwitching = try c.decodeIfPresent(Bool.self, forKey: .safeSwitching) ?? defaults.safeSwitching
        rules = try c.decodeIfPresent(NetworkRules.self, forKey: .rules) ?? defaults.rules
        automationEnabled = try c.decodeIfPresent(Bool.self, forKey: .automationEnabled) ?? defaults.automationEnabled
        automationToken = try c.decodeIfPresent(String.self, forKey: .automationToken) ?? defaults.automationToken
        pause = try c.decodeIfPresent(PauseState.self, forKey: .pause)
        ruleReturnHost = try c.decodeIfPresent(String.self, forKey: .ruleReturnHost)
    }

    /// Built-in presets followed by custom ones, sorted by name.
    public var presets: [DNSPreset] {
        BuiltInPresets.all + custom
            .map { DNSPreset(name: $0.name ?? $0.host, host: $0.host, builtIn: false) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Starred providers, in the order the menu lists them.
    public var favoritePresets: [DNSPreset] { presets.filter { favorites.contains($0.host) } }

    /// The display name for [host]: the preset's or custom name, or the host itself.
    public func name(of host: String) -> String {
        presets.first { $0.host == host }?.name ?? host
    }

    public mutating func setFavorite(_ host: String, _ favorite: Bool) {
        if favorite { favorites.insert(host) } else { favorites.remove(host) }
    }

    /// Adds a custom provider. Returns false for an invalid hostname. A built-in or existing host is
    /// not added twice, but a name given for an existing custom one renames it.
    @discardableResult
    public mutating func addCustom(host rawHost: String, name: String? = nil) -> Bool {
        let host = Hostname.normalize(rawHost)
        guard Hostname.isValid(host) else { return false }
        if BuiltInPresets.preset(for: host) != nil { return true }
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = (cleanName?.isEmpty ?? true) ? nil : cleanName
        if let index = custom.firstIndex(where: { $0.host == host }) {
            if finalName != nil { custom[index].name = finalName }
        } else {
            custom.append(CustomProvider(host: host, name: finalName))
        }
        return true
    }

    /// Renames a custom provider. A blank name goes back to showing the hostname.
    public mutating func renameCustom(host: String, name: String) {
        guard let index = custom.firstIndex(where: { $0.host == host }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        custom[index].name = trimmed.isEmpty ? nil : trimmed
    }

    /// Removes a custom provider. If it was the toggle provider, that falls back to the default.
    public mutating func removeCustom(host: String) {
        custom.removeAll { $0.host == host }
        favorites.remove(host)
        if toggleHost == host { toggleHost = BuiltInPresets.defaultHost }
    }

    /// The hosts "Toggle" steps through: favourites, when cycling is on.
    public var cycle: [String] { cycleFavorites ? favoritePresets.map(\.host) : [] }

    public static func newToken() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        var generator = SystemRandomNumberGenerator()
        return String((0..<24).map { _ in alphabet.randomElement(using: &generator)! })
    }
}

/// What "Toggle" does. Without a cycle (fewer than two favourites) it switches between Off and
/// [toggleHost]. With one, Off → cycle[0] → cycle[1] → … → Off; a provider that is not in the
/// cycle goes to Off. Same behaviour as the Android widget and tile.
public func nextToggleTarget(state: DNSState, toggleHost: String, cycle: [String]) -> DNSState {
    guard cycle.count >= 2 else { return state.isOn ? .off : .on(host: toggleHost) }
    guard let current = state.host else { return .on(host: cycle[0]) }
    guard let index = cycle.firstIndex(of: current), index < cycle.count - 1 else { return .off }
    return .on(host: cycle[index + 1])
}
