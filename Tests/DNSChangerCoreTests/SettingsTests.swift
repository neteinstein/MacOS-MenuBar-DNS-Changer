import XCTest
@testable import DNSChangerCore

final class SettingsTests: XCTestCase {
    func testAddRenameRemoveCustom() {
        var s = AppSettings()
        XCTAssertFalse(s.addCustom(host: "not a host"))
        XCTAssertTrue(s.addCustom(host: " My.DNS.example. ", name: "  Home  "))
        XCTAssertEqual(s.custom, [CustomProvider(host: "my.dns.example", name: "Home")])
        XCTAssertEqual(s.name(of: "my.dns.example"), "Home")

        // Built-ins are not duplicated.
        XCTAssertTrue(s.addCustom(host: "dns.google"))
        XCTAssertEqual(s.custom.count, 1)

        s.renameCustom(host: "my.dns.example", name: "   ")
        XCTAssertEqual(s.name(of: "my.dns.example"), "my.dns.example")

        s.toggleHost = "my.dns.example"
        s.setFavorite("my.dns.example", true)
        s.removeCustom(host: "my.dns.example")
        XCTAssertTrue(s.custom.isEmpty)
        XCTAssertTrue(s.favorites.isEmpty)
        XCTAssertEqual(s.toggleHost, BuiltInPresets.defaultHost)
    }

    func testCustomPresetsSortAfterBuiltIns() {
        var s = AppSettings()
        s.addCustom(host: "z.example.com", name: "zeta")
        s.addCustom(host: "a.example.com", name: "Alpha")
        XCTAssertEqual(s.presets.suffix(2).map(\.name), ["Alpha", "zeta"])
        XCTAssertEqual(s.presets.last?.category, .custom)
    }

    func testFavoritesFollowPresetOrder() {
        var s = AppSettings()
        s.setFavorite("dot.sb", true)
        s.setFavorite("one.one.one.one", true)
        XCTAssertEqual(s.favoritePresets.map(\.host), ["one.one.one.one", "dot.sb"])
        XCTAssertEqual(s.cycle, [])
        s.cycleFavorites = true
        XCTAssertEqual(s.cycle, ["one.one.one.one", "dot.sb"])
    }

    func testDecodesOlderSettingsWithMissingKeys() throws {
        let json = #"{"toggleHost":"dns.google","favorites":["dot.sb"]}"#
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.toggleHost, "dns.google")
        XCTAssertEqual(s.favorites, ["dot.sb"])
        XCTAssertTrue(s.safeSwitching)
        XCTAssertFalse(s.automationEnabled)
        XCTAssertEqual(s.automationToken.count, 24)
    }

    func testRoundTrip() throws {
        var s = AppSettings()
        s.addCustom(host: "x.example.com")
        s.pause = PauseState(until: Date(timeIntervalSince1970: 1000), restoreHost: "dns.google")
        s.rules = NetworkRules(enabled: true, offOnSSIDs: ["Hotel"])
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
    }

    func testToggleWithoutCycle() {
        XCTAssertEqual(nextToggleTarget(state: .off, toggleHost: "dns.google", cycle: []), .on(host: "dns.google"))
        XCTAssertEqual(nextToggleTarget(state: .on(host: "dot.sb"), toggleHost: "dns.google", cycle: []), .off)
        XCTAssertEqual(nextToggleTarget(state: .off, toggleHost: "dns.google", cycle: ["a.b"]), .on(host: "dns.google"))
    }

    func testToggleCyclesThroughFavourites() {
        let cycle = ["a.com", "b.com", "c.com"]
        XCTAssertEqual(nextToggleTarget(state: .off, toggleHost: "x.com", cycle: cycle), .on(host: "a.com"))
        XCTAssertEqual(nextToggleTarget(state: .on(host: "a.com"), toggleHost: "x.com", cycle: cycle), .on(host: "b.com"))
        XCTAssertEqual(nextToggleTarget(state: .on(host: "c.com"), toggleHost: "x.com", cycle: cycle), .off)
        XCTAssertEqual(nextToggleTarget(state: .on(host: "other.com"), toggleHost: "x.com", cycle: cycle), .off)
    }

    func testTokensAreRandom() {
        XCTAssertNotEqual(AppSettings.newToken(), AppSettings.newToken())
    }
}
