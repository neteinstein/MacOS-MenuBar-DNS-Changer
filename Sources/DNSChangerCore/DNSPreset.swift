import Foundation

/// How the provider list is grouped in the menu.
public enum PresetCategory: String, Codable, CaseIterable, Sendable {
    case standard
    case blocking
    case family
    case custom

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .blocking: return "Ad & malware blocking"
        case .family: return "Family"
        case .custom: return "Custom"
        }
    }
}

/// A DNS-over-TLS resolver, identified by its hostname (the same thing Android calls the
/// "Private DNS provider hostname").
public struct DNSPreset: Hashable, Codable, Identifiable, Sendable {
    public var name: String
    public var host: String
    public var builtIn: Bool
    public var category: PresetCategory

    public var id: String { host }

    public init(name: String, host: String, builtIn: Bool, category: PresetCategory? = nil) {
        self.name = name
        self.host = host
        self.builtIn = builtIn
        self.category = category ?? (builtIn ? .standard : .custom)
    }
}

public enum BuiltInPresets {
    private static func standard(_ name: String, _ host: String) -> DNSPreset {
        DNSPreset(name: name, host: host, builtIn: true, category: .standard)
    }

    private static func blocking(_ name: String, _ host: String) -> DNSPreset {
        DNSPreset(name: name, host: host, builtIn: true, category: .blocking)
    }

    private static func family(_ name: String, _ host: String) -> DNSPreset {
        DNSPreset(name: name, host: host, builtIn: true, category: .family)
    }

    /// The same list as the Android app. The first entry is the default for a fresh install.
    public static let all: [DNSPreset] = [
        standard("Cloudflare", "one.one.one.one"),
        standard("Google", "dns.google"),
        standard("Quad9", "dns.quad9.net"),
        standard("Mullvad", "dns.mullvad.net"),
        standard("Control D", "p0.freedns.controld.com"),
        standard("AdGuard (unfiltered)", "unfiltered.adguard-dns.com"),
        standard("DNS4EU", "unfiltered.joindns4.eu"),
        standard("DNS.SB", "dot.sb"),
        standard("Quad9 (ECS)", "dns11.quad9.net"),
        blocking("Cloudflare (malware blocking)", "security.cloudflare-dns.com"),
        blocking("AdGuard", "dns.adguard-dns.com"),
        blocking("Mullvad (ad blocking)", "adblock.dns.mullvad.net"),
        blocking("Control D (ads & tracking)", "p2.freedns.controld.com"),
        blocking("DNS4EU (malware blocking)", "protective.joindns4.eu"),
        blocking("DNS4EU (ad blocking)", "noads.joindns4.eu"),
        blocking("CleanBrowsing Security", "security-filter-dns.cleanbrowsing.org"),
        family("Cloudflare Family", "family.cloudflare-dns.com"),
        family("AdGuard Family", "family.adguard-dns.com"),
        family("CleanBrowsing Family", "family-filter-dns.cleanbrowsing.org"),
        family("Mullvad Family", "family.dns.mullvad.net"),
        family("Control D Family", "family.freedns.controld.com"),
        family("DNS4EU Child", "child.joindns4.eu"),
        family("DNS4EU Child (ad blocking)", "child-noads.joindns4.eu"),
        family("CleanBrowsing Adult", "adult-filter-dns.cleanbrowsing.org"),
    ]

    public static var defaultHost: String { all[0].host }

    public static func preset(for host: String) -> DNSPreset? { all.first { $0.host == host } }
}

public enum NextDNS {
    /// NextDNS gives every configuration its own DNS-over-TLS hostname.
    public static func host(forID id: String) -> String {
        "\(id.trimmingCharacters(in: .whitespaces).lowercased()).dns.nextdns.io"
    }

    public static func isValidID(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard (4...32).contains(trimmed.count) else { return false }
        return trimmed.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.alphanumerics.contains($0) }
    }
}

public enum Hostname {
    /// A DNS name with at least two labels, each 1–63 letters, digits or hyphens, not starting or
    /// ending with a hyphen. Same rule as the Android app.
    public static func isValid(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253 else { return false }
        let trimmed = host.hasSuffix(".") ? String(host.dropLast()) : host
        let labels = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        return labels.allSatisfy(isValidLabel)
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        guard (1...63).contains(label.count), label.first != "-", label.last != "-" else { return false }
        return label.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-")
        }
    }

    /// Lowercased and trimmed, without a trailing dot: the form stored and compared everywhere.
    public static func normalize(_ host: String) -> String {
        var value = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasSuffix(".") { value.removeLast() }
        return value
    }
}
