import XCTest
@testable import DNSChangerCore

final class PauseHealthTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testPauseRestoresCurrentProvider() {
        let p = Pause.start(minutes: 15, now: now, current: .on(host: "dot.sb"), existing: nil, toggleHost: "dns.google")
        XCTAssertEqual(p.restoreHost, "dot.sb")
        XCTAssertEqual(p.until, now.addingTimeInterval(15 * 60))
        XCTAssertFalse(p.isExpired(at: now))
        XCTAssertTrue(p.isExpired(at: p.until))
    }

    func testPauseWhileOffRestoresToggleProvider() {
        let p = Pause.start(minutes: 5, now: now, current: .off, existing: nil, toggleHost: "dns.google")
        XCTAssertEqual(p.restoreHost, "dns.google")
    }

    func testPausingAgainKeepsFirstProviderAndClamps() {
        let first = PauseState(until: now, restoreHost: "dot.sb")
        let p = Pause.start(minutes: 100_000, now: now, current: .off, existing: first, toggleHost: "dns.google")
        XCTAssertEqual(p.restoreHost, "dot.sb")
        XCTAssertEqual(p.until, now.addingTimeInterval(TimeInterval(Pause.maxMinutes * 60)))
        let q = Pause.start(minutes: 0, now: now, current: .off, existing: nil, toggleHost: "dns.google")
        XCTAssertEqual(q.until, now.addingTimeInterval(60))
    }

    func testHealthVerdicts() {
        XCTAssertEqual(Health.verdict(results: [.failed, .answered], elapsed: 1), .keep)
        XCTAssertEqual(Health.verdict(results: [.noSuchName], elapsed: 1), .keep)
        XCTAssertEqual(Health.verdict(results: [.failed, .failed], elapsed: 5), .wait)
        XCTAssertEqual(Health.verdict(results: [.failed, .failed, .failed], elapsed: 21), .revert)
        // Offline never counts against the provider.
        XCTAssertEqual(Health.verdict(results: [.offline, .offline, .failed], elapsed: 21), .keep)
        XCTAssertEqual(Health.verdict(results: [], elapsed: 21), .keep)
    }

    func testHealthStatus() {
        XCTAssertEqual(Health.status(of: .answered), .answering)
        XCTAssertEqual(Health.status(of: .failed), .notAnswering)
        XCTAssertEqual(Health.status(of: .offline), .unknown)
    }
}
