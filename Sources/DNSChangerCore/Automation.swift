import Foundation

/// Something a Shortcut, script or automation app asks for, through a `privatedns://` URL:
///
///     privatedns://on?token=…[&host=dns.example.com]
///     privatedns://off?token=…
///     privatedns://toggle?token=…
///     privatedns://pause?token=…[&minutes=30]
///     privatedns://resume?token=…
public enum DNSCommand: Hashable, Sendable {
    /// Your provider, or [host] when given.
    case turnOn(host: String?)
    case turnOff
    case toggle
    case pause(minutes: Int)
    case resume

    public static let scheme = "privatedns"

    /// Nil for an unknown command or an invalid hostname.
    public static func parse(_ url: URL) -> DNSCommand? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        // Accept both privatedns://pause and privatedns:pause / privatedns:///pause.
        let name = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let query = components?.queryItems ?? []
        func value(_ key: String) -> String? { query.first { $0.name == key }?.value }

        switch name {
        case "on":
            guard let raw = value("host"), !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
                return .turnOn(host: nil)
            }
            let host = Hostname.normalize(raw)
            return Hostname.isValid(host) ? .turnOn(host: host) : nil
        case "off": return .turnOff
        case "toggle": return .toggle
        case "pause":
            let minutes = value("minutes").flatMap(Int.init) ?? Pause.defaultMinutes
            return .pause(minutes: min(max(minutes, 1), Pause.maxMinutes))
        case "resume": return .resume
        default: return nil
        }
    }

    /// The token in [url], if any.
    public static func token(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "token" }?.value
    }

    /// Commands are ignored while automation is off or without the right token, so that a web page
    /// cannot change your DNS by opening a link.
    public static func isAuthorized(_ url: URL, settings: AppSettings) -> Bool {
        guard settings.automationEnabled, let token = token(in: url), !settings.automationToken.isEmpty else { return false }
        return constantTimeEquals(token, settings.automationToken)
    }

    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<x.count { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    /// An example URL for the settings window.
    public static func exampleURL(_ name: String, token: String, extra: String = "") -> String {
        "\(scheme)://\(name)?token=\(token)\(extra)"
    }
}
