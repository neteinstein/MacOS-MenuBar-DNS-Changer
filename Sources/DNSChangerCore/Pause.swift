import Foundation

/// Encrypted DNS turned off for a while (a captive portal, a site that won't load); the provider
/// comes back at [until].
public struct PauseState: Hashable, Codable, Sendable {
    public var until: Date
    public var restoreHost: String

    public init(until: Date, restoreHost: String) {
        self.until = until
        self.restoreHost = restoreHost
    }

    public func isExpired(at now: Date) -> Bool { now >= until }
}

public enum Pause {
    public static let presetMinutes = [5, 15, 60]
    public static let defaultMinutes = 15
    public static let maxMinutes = 24 * 60

    /// Starts or extends a pause. Pausing again keeps the provider of the first pause; otherwise it
    /// brings back what was on, or the toggle provider if encrypted DNS was already off.
    public static func start(
        minutes: Int,
        now: Date,
        current: DNSState,
        existing: PauseState?,
        toggleHost: String
    ) -> PauseState {
        let clamped = min(max(minutes, 1), maxMinutes)
        let restore = existing?.restoreHost ?? current.host ?? toggleHost
        return PauseState(until: now.addingTimeInterval(TimeInterval(clamped * 60)), restoreHost: restore)
    }
}
