import XCTest
@testable import DNSChangerCore

final class AutomationTests: XCTestCase {
    private func parse(_ s: String) -> DNSCommand? { DNSCommand.parse(URL(string: s)!) }

    func testParse() {
        XCTAssertEqual(parse("privatedns://on"), .turnOn(host: nil))
        XCTAssertEqual(parse("privatedns://on?host=DNS.Google"), .turnOn(host: "dns.google"))
        XCTAssertNil(parse("privatedns://on?host=not%20valid"))
        XCTAssertEqual(parse("privatedns://off?token=x"), .turnOff)
        XCTAssertEqual(parse("privatedns://TOGGLE"), .toggle)
        XCTAssertEqual(parse("privatedns://pause"), .pause(minutes: Pause.defaultMinutes))
        XCTAssertEqual(parse("privatedns://pause?minutes=30"), .pause(minutes: 30))
        XCTAssertEqual(parse("privatedns://pause?minutes=99999"), .pause(minutes: Pause.maxMinutes))
        XCTAssertEqual(parse("privatedns://pause?minutes=-3"), .pause(minutes: 1))
        XCTAssertEqual(parse("privatedns:resume"), .resume)
        XCTAssertNil(parse("privatedns://explode"))
        XCTAssertNil(parse("https://on"))
    }

    func testAuthorization() {
        var s = AppSettings()
        s.automationToken = "secret"
        let url = URL(string: "privatedns://off?token=secret")!
        XCTAssertFalse(DNSCommand.isAuthorized(url, settings: s), "automation is off")
        s.automationEnabled = true
        XCTAssertTrue(DNSCommand.isAuthorized(url, settings: s))
        XCTAssertFalse(DNSCommand.isAuthorized(URL(string: "privatedns://off?token=wrong!")!, settings: s))
        XCTAssertFalse(DNSCommand.isAuthorized(URL(string: "privatedns://off")!, settings: s))
    }
}
