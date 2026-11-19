import XCTest
@testable import DNSChangerCore

final class RulesTests: XCTestCase {
    private let on = DNSState.on(host: "dns.google")

    func testOffIsASingleDisconnectRule() {
        let rules = NetworkRules(enabled: true, offOnWiFi: true)
        XCTAssertEqual(onDemandRules(for: .off, rules: rules), [OnDemandRule(action: .disconnect)])
    }

    func testOnWithoutRulesAlwaysConnects() {
        XCTAssertEqual(onDemandRules(for: on, rules: NetworkRules()), [OnDemandRule(action: .connect)])
        // Disabled rules are ignored.
        let disabled = NetworkRules(enabled: false, offOnWiFi: true, networks: [WiFiNetwork(ssid: "X")])
        XCTAssertEqual(onDemandRules(for: on, rules: disabled), [OnDemandRule(action: .connect)])
    }

    func testRuleOrderOffNetworksThenOwnProvidersThenInterfacesThenConnect() {
        let rules = NetworkRules(enabled: true, offOnWiFi: true, offOnEthernet: true, networks: [
            WiFiNetwork(ssid: "Hotel"),
            WiFiNetwork(ssid: "Home", action: .provider("dns.quad9.net")),
            WiFiNetwork(ssid: "Office"),
        ])
        XCTAssertEqual(onDemandRules(for: on, rules: rules), [
            OnDemandRule(action: .disconnect, interface: .wifi, ssids: ["Hotel", "Office"]),
            OnDemandRule(action: .connect, interface: .wifi, ssids: ["Home"]),
            OnDemandRule(action: .disconnect, interface: .wifi),
            OnDemandRule(action: .disconnect, interface: .ethernet),
            OnDemandRule(action: .connect),
        ])
    }

    func testOwnProviderNetworksNeedNoRuleWithoutOffOnWiFi() {
        let rules = NetworkRules(enabled: true, networks: [WiFiNetwork(ssid: "Home", action: .provider("dns.quad9.net"))])
        XCTAssertEqual(onDemandRules(for: on, rules: rules), [OnDemandRule(action: .connect)])
    }

    func testSuspendedByRule() {
        let rules = NetworkRules(enabled: true, offOnWiFi: true, offOnEthernet: true, networks: [
            WiFiNetwork(ssid: "Hotel"), WiFiNetwork(ssid: "Home", action: .provider("dns.quad9.net")),
        ])
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: "Hotel"), state: on, rules: rules))
        XCTAssertFalse(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: "Home"), state: on, rules: rules))
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: "Café"), state: on, rules: rules))
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .ethernet), state: on, rules: rules))
        XCTAssertTrue(isSuspendedByRule(NetworkSnapshot(kind: .wifi), state: .off, rules: rules))

        let onlyHotel = NetworkRules(enabled: true, networks: [WiFiNetwork(ssid: "Hotel")])
        XCTAssertFalse(isSuspendedByRule(NetworkSnapshot(kind: .wifi, ssid: nil), state: on, rules: onlyHotel))
    }

    func testAddSetAndRemoveNetworks() {
        var rules = NetworkRules()
        XCTAssertTrue(rules.addNetwork("  Hotel "))
        XCTAssertFalse(rules.addNetwork("Hotel"))
        XCTAssertFalse(rules.addNetwork("   "))
        XCTAssertEqual(rules.networks, [WiFiNetwork(ssid: "Hotel")])
        XCTAssertFalse(rules.isEffective)
        rules.enabled = true
        XCTAssertTrue(rules.isEffective)
        rules.setAction(.provider("dot.sb"), for: "Hotel")
        XCTAssertEqual(rules.networks[0].action, .provider("dot.sb"))
        XCTAssertTrue(rules.hasProviderNetworks)
        XCTAssertEqual(rules.offSSIDs, [])
        rules.removeNetwork("Hotel")
        XCTAssertTrue(rules.networks.isEmpty)
    }

    func testDecodesTheOldListOfOffNetworks() throws {
        let json = #"{"enabled":true,"offOnWiFi":false,"offOnEthernet":true,"offOnSSIDs":["Hotel","Office"]}"#
        let rules = try JSONDecoder().decode(NetworkRules.self, from: Data(json.utf8))
        XCTAssertEqual(rules, NetworkRules(enabled: true, offOnEthernet: true, networks: [WiFiNetwork(ssid: "Hotel"), WiFiNetwork(ssid: "Office")]))
        let again = try JSONDecoder().decode(NetworkRules.self, from: JSONEncoder().encode(rules))
        XCTAssertEqual(again, rules)
    }

    // MARK: - Switching provider per network

    private let rules = NetworkRules(enabled: true, networks: [
        WiFiNetwork(ssid: "Home", action: .provider("dns.quad9.net")),
        WiFiNetwork(ssid: "Hotel"),
    ])
    private let home = NetworkSnapshot(kind: .wifi, ssid: "Home")
    private let cafe = NetworkSnapshot(kind: .wifi, ssid: "Café")

    func testJoiningANetworkWithItsOwnProviderSwitchesAndRemembers() {
        XCTAssertEqual(ruleSwitch(network: home, state: .on(host: "dot.sb"), rules: rules, returnHost: nil),
                       RuleSwitch(target: .on(host: "dns.quad9.net"), returnHost: "dot.sb"))
        // Already on it: nothing to do.
        XCTAssertEqual(ruleSwitch(network: home, state: .on(host: "dns.quad9.net"), rules: rules, returnHost: "dot.sb"),
                       RuleSwitch(target: nil, returnHost: "dot.sb"))
    }

    func testLeavingGoesBackUnlessChangedByHand() {
        XCTAssertEqual(ruleSwitch(network: cafe, state: .on(host: "dns.quad9.net"), rules: rules, returnHost: "dot.sb"),
                       RuleSwitch(target: .on(host: "dot.sb"), returnHost: nil))
        // Picked another provider by hand while at home: keep it.
        XCTAssertEqual(ruleSwitch(network: cafe, state: .on(host: "dns.google"), rules: rules, returnHost: "dot.sb"),
                       RuleSwitch(target: nil, returnHost: nil))
    }

    func testLeavesDNSAloneWhenOffPausedOrBetweenNetworks() {
        XCTAssertEqual(ruleSwitch(network: home, state: .off, rules: rules, returnHost: nil),
                       RuleSwitch(target: nil, returnHost: nil))
        XCTAssertEqual(ruleSwitch(network: NetworkSnapshot(kind: nil), state: .on(host: "dns.quad9.net"), rules: rules, returnHost: "dot.sb"),
                       RuleSwitch(target: nil, returnHost: "dot.sb"))
        var disabled = rules
        disabled.enabled = false
        XCTAssertEqual(ruleSwitch(network: home, state: .on(host: "dot.sb"), rules: disabled, returnHost: nil),
                       RuleSwitch(target: nil, returnHost: nil))
        // Wi-Fi name unknown (no Location access): no provider of its own.
        XCTAssertEqual(ruleSwitch(network: NetworkSnapshot(kind: .wifi), state: .on(host: "dot.sb"), rules: rules, returnHost: nil),
                       RuleSwitch(target: nil, returnHost: nil))
    }
}
