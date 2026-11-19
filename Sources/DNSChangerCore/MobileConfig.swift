import Foundation

/// Builds a configuration profile (`.mobileconfig`) with a DNS-over-TLS `DNSSettings` payload.
///
/// This is how builds without the Network Extension entitlement switch DNS: macOS asks the user to
/// install the profile in System Settings. Every profile uses the same identifier, so installing
/// one for another provider replaces the previous one.
public enum MobileConfig {
    public static let profileIdentifier = "org.neteinstein.privatedns.profile"
    public static let payloadIdentifier = "org.neteinstein.privatedns.profile.dns"

    public static func dictionary(
        host: String,
        displayName: String,
        addresses: [String] = [],
        rules: [OnDemandRule] = [OnDemandRule(action: .connect)],
        uuid: UUID = UUID(),
        payloadUUID: UUID = UUID()
    ) -> [String: Any] {
        var dnsSettings: [String: Any] = [
            "DNSProtocol": "TLS",
            "ServerName": host,
        ]
        if !addresses.isEmpty { dnsSettings["ServerAddresses"] = addresses }

        let payload: [String: Any] = [
            "PayloadType": "com.apple.dnsSettings.managed",
            "PayloadIdentifier": payloadIdentifier,
            "PayloadUUID": payloadUUID.uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": "\(displayName) (DNS over TLS)",
            "DNSSettings": dnsSettings,
            "OnDemandRules": rules.map(ruleDictionary),
            "ProhibitDisablement": false,
        ]

        return [
            "PayloadType": "Configuration",
            "PayloadIdentifier": profileIdentifier,
            "PayloadUUID": uuid.uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": "Private DNS: \(displayName)",
            "PayloadDescription": "Encrypts DNS lookups with \(displayName) (\(host)) using DNS over TLS. Made by Private DNS Menu Bar.",
            "PayloadOrganization": "Private DNS Menu Bar",
            "PayloadRemovalDisallowed": false,
            "PayloadScope": "System",
            "PayloadContent": [payload],
        ]
    }

    public static func ruleDictionary(_ rule: OnDemandRule) -> [String: Any] {
        var dict: [String: Any] = ["Action": rule.action.rawValue]
        switch rule.interface {
        case .wifi: dict["InterfaceTypeMatch"] = "WiFi"
        case .ethernet: dict["InterfaceTypeMatch"] = "Ethernet"
        case nil: break
        }
        if !rule.ssids.isEmpty { dict["SSIDMatch"] = rule.ssids }
        return dict
    }

    /// The profile as XML property list data, ready to write to a `.mobileconfig` file.
    public static func data(
        host: String,
        displayName: String,
        addresses: [String] = [],
        rules: [OnDemandRule] = [OnDemandRule(action: .connect)]
    ) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: dictionary(host: host, displayName: displayName, addresses: addresses, rules: rules),
            format: .xml,
            options: 0
        )
    }

    /// A safe file name for the profile of [host].
    public static func fileName(for host: String) -> String {
        "PrivateDNS-\(host.replacingOccurrences(of: ".", with: "-")).mobileconfig"
    }
}
