import Foundation

/// The outcome of one lookup through the system resolver.
public enum ProbeResult: Hashable, Sendable {
    /// The resolver answered with addresses.
    case answered
    /// The resolver answered, but the name does not exist. Still proof that DNS works.
    case noSuchName
    /// No answer: timeout or a server failure.
    case failed
    /// The Mac has no network, so a failure says nothing about the provider.
    case offline
}

public enum HealthStatus: Hashable, Sendable {
    case unknown
    case checking
    case answering
    case notAnswering
}

/// What safe switching does after a few probes.
public enum SwitchVerdict: Hashable, Sendable {
    /// The provider answers. Keep it.
    case keep
    /// Not enough evidence yet: probe again.
    case wait
    /// The provider does not answer while the Mac is online. Go back to the previous setting.
    case revert
}

public enum Health {
    /// Seconds safe switching waits for the provider before reverting (same as the Android app).
    public static let switchTimeout: TimeInterval = 20

    public static func status(of result: ProbeResult) -> HealthStatus {
        switch result {
        case .answered, .noSuchName: return .answering
        case .failed: return .notAnswering
        case .offline: return .unknown
        }
    }

    /// One answer is enough to keep the provider. Revert only when every probe while online failed
    /// and at least [minFailures] did, and the time is up; being offline never counts against it.
    public static func verdict(results: [ProbeResult], elapsed: TimeInterval, minFailures: Int = 2) -> SwitchVerdict {
        if results.contains(where: { status(of: $0) == .answering }) { return .keep }
        let failures = results.filter { $0 == .failed }.count
        guard elapsed >= switchTimeout else { return .wait }
        return failures >= minFailures ? .revert : .keep
    }
}
