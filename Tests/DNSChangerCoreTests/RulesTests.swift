import XCTest
@testable import DNSChangerCore

final class RulesTests: XCTestCase {
    func testOffIsASingleDisconnectRule() {
        let rules = NetworkRules(enabled: true, offOnWiFi: true)
        XCTAssertEqual(onDemandRules(for: .off, rules: rules), [OnDemandRule(action: .disconnect)])
    }

    func testOnWithoutRulesAlwaysConnects() {
        XCTAssertEqual(onDemandRules(for: .on(host: "dns.google"), rules: NetworkRules()), [OnDemandRule(action: .connect)])
        // Disabled rules are ignored.
        let disabled = NetworkRules(enabled: false, offOnWiFi: true, offOnSSIDs: ["X"])
        XCTAssertEqual(onDemandRules(for: .on(host: "dns.google"), rules: disabled), [OnDemandRule(action: .connect)])
    }

    func testRuleOrderSSIDsFirstThenInterfacesThenConnect() {
        let rules = NetworkRules(enabled: true, offOnWiFi: true, offOnEthernet: true, offOnSSIDs: ["Hotel", "Office"])
        XCTAssertEqual(onDemandRules(for: .on(host: "dns.google"), rules: rules), [
            OnDemandRule(action: .disconnect, interface: .wifi, ssids: ["Hotel", "Office"]),
            OnDemandRule(action: .disconnect, interface: .wifi),
            OnDemandRule(action: .disconnect, interface: .ethernet),
            OnDemandRule(action: .connect),
        ])
    }

    func testSuspendedByRule() {
        let on = DNSState.on(host: "dns.google")
        let rules = NetworkRules(enabled: true, offOnEthernet: true, offOnSSIDs: ["Hotel"])
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: "Hotel"), state: on, rules: rules))
        XCTAssertFalse(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: "Home"), state: on, rules: rules))
        XCTAssertFalse(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: nil), state: on, rules: rules))
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .ethernet), state: on, rules: rules))
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .wifi), state: .off, rules: rules))
    }

    func testAddSSID() {
        var rules = NetworkRules()
        rules.addSSID("  Hotel ")
        rules.addSSID("Hotel")
        rules.addSSID("   ")
        XCTAssertEqual(rules.offOnSSIDs, ["Hotel"])
        XCTAssertFalse(rules.isEffective)
        rules.enabled = true
        XCTAssertTrue(rules.isEffective)
    }
}
