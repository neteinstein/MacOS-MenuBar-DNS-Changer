import XCTest
@testable import DNSChangerCore

final class PresetsTests: XCTestCase {
    func testBuiltInHostsAreUniqueAndValid() {
        let hosts = BuiltInPresets.all.map(\.host)
        XCTAssertEqual(Set(hosts).count, hosts.count)
        for host in hosts { XCTAssertTrue(Hostname.isValid(host), host) }
        XCTAssertEqual(BuiltInPresets.defaultHost, "one.one.one.one")
    }

    func testEveryBuiltInHasProviderInfo() {
        for preset in BuiltInPresets.all {
            XCTAssertNotNil(ProviderInfo.forHost(preset.host), preset.host)
        }
        XCTAssertNil(ProviderInfo.forHost("my.custom.dns"))
    }

    func testHostnameValidation() {
        XCTAssertTrue(Hostname.isValid("dns.google"))
        XCTAssertTrue(Hostname.isValid("abc123.dns.nextdns.io"))
        XCTAssertTrue(Hostname.isValid("dns.google."))
        XCTAssertFalse(Hostname.isValid(""))
        XCTAssertFalse(Hostname.isValid("localhost"))
        XCTAssertFalse(Hostname.isValid("-bad.example.com"))
        XCTAssertFalse(Hostname.isValid("bad-.example.com"))
        XCTAssertFalse(Hostname.isValid("a..b"))
        XCTAssertFalse(Hostname.isValid("has space.com"))
        XCTAssertFalse(Hostname.isValid("https://dns.google"))
        XCTAssertFalse(Hostname.isValid("ação.pt"))
        XCTAssertFalse(Hostname.isValid(String(repeating: "a", count: 64) + ".com"))
    }

    func testNormalize() {
        XCTAssertEqual(Hostname.normalize("  DNS.Google. \n"), "dns.google")
    }

    func testNextDNS() {
        XCTAssertTrue(NextDNS.isValidID("abc123"))
        XCTAssertFalse(NextDNS.isValidID("ab"))
        XCTAssertFalse(NextDNS.isValidID("abc-123"))
        XCTAssertEqual(NextDNS.host(forID: " ABC123 "), "abc123.dns.nextdns.io")
    }
}
