import XCTest
@testable import DNSChangerCore

final class MobileConfigTests: XCTestCase {
    func testProfileContents() throws {
        let rules = onDemandRules(for: .on(host: "dns.google"), rules: NetworkRules(enabled: true, offOnSSIDs: ["Hotel"]))
        let data = try MobileConfig.data(host: "dns.google", displayName: "Google", addresses: ["8.8.8.8"], rules: rules)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["PayloadType"] as? String, "Configuration")
        XCTAssertEqual(plist["PayloadIdentifier"] as? String, MobileConfig.profileIdentifier)

        let payload = try XCTUnwrap((plist["PayloadContent"] as? [[String: Any]])?.first)
        XCTAssertEqual(payload["PayloadType"] as? String, "com.apple.dnsSettings.managed")
        let dns = try XCTUnwrap(payload["DNSSettings"] as? [String: Any])
        XCTAssertEqual(dns["DNSProtocol"] as? String, "TLS")
        XCTAssertEqual(dns["ServerName"] as? String, "dns.google")
        XCTAssertEqual(dns["ServerAddresses"] as? [String], ["8.8.8.8"])

        let onDemand = try XCTUnwrap(payload["OnDemandRules"] as? [[String: Any]])
        XCTAssertEqual(onDemand.count, 2)
        XCTAssertEqual(onDemand[0]["Action"] as? String, "Disconnect")
        XCTAssertEqual(onDemand[0]["InterfaceTypeMatch"] as? String, "WiFi")
        XCTAssertEqual(onDemand[0]["SSIDMatch"] as? [String], ["Hotel"])
        XCTAssertEqual(onDemand[1]["Action"] as? String, "Connect")
        XCTAssertNil(onDemand[1]["InterfaceTypeMatch"])
    }

    func testNoAddressesKeyWhenUnresolved() throws {
        let dict = MobileConfig.dictionary(host: "dot.sb", displayName: "DNS.SB")
        let payload = try XCTUnwrap((dict["PayloadContent"] as? [[String: Any]])?.first)
        let dns = try XCTUnwrap(payload["DNSSettings"] as? [String: Any])
        XCTAssertNil(dns["ServerAddresses"])
    }

    func testFileName() {
        XCTAssertEqual(MobileConfig.fileName(for: "dns.google"), "PrivateDNS-dns-google.mobileconfig")
    }
}
