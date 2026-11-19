import DNSChangerCore
import Foundation

/// Lookups through the system resolver (whatever DNS the Mac is using right now).
enum Resolver {
    enum Lookup {
        case addresses([String])
        case noSuchName
        case failed
    }

    /// The IPv4 and IPv6 addresses of [host], or an empty list if it can't be resolved in time.
    static func addresses(of host: String, timeout: TimeInterval = 5) async -> [String] {
        if case let .addresses(list) = await lookup(host, timeout: timeout) { return list }
        return []
    }

    /// Well-known names that always exist. A provider that can't resolve them isn't working.
    private static let probeNames = ["www.apple.com", "www.wikipedia.org", "www.icloud.com", "www.google.com"]
    private static var probeIndex = 0

    /// One health probe. Only real answers count: a blocking provider still resolves these names.
    static func probe(online: Bool, timeout: TimeInterval = 5) async -> ProbeResult {
        guard online else { return .offline }
        probeIndex = (probeIndex + 1) % probeNames.count
        switch await lookup(probeNames[probeIndex], timeout: timeout) {
        case .addresses: return .answered
        case .noSuchName, .failed: return .failed
        }
    }

    /// getaddrinfo on a background thread, given up on after [timeout] (it can't be cancelled, so
    /// a late answer is simply dropped).
    static func lookup(_ host: String, timeout: TimeInterval) async -> Lookup {
        await withCheckedContinuation { continuation in
            let once = Once(continuation)
            DispatchQueue.global(qos: .userInitiated).async { once.finish(blockingLookup(host)) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { once.finish(.failed) }
        }
    }

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Lookup, Never>?

        init(_ continuation: CheckedContinuation<Lookup, Never>) { self.continuation = continuation }

        func finish(_ value: Lookup) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(returning: value)
        }
    }

    private static func blockingLookup(_ host: String) -> Lookup {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        defer { if let result { freeaddrinfo(result) } }
        guard status == 0, let first = result else {
            return status == EAI_NONAME ? .noSuchName : .failed
        }

        var addresses: [String] = []
        for info in sequence(first: first, next: { $0.pointee.ai_next }) {
            guard let addr = info.pointee.ai_addr else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let ok = getnameinfo(addr, info.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST)
            guard ok == 0 else { continue }
            let address = String(cString: buffer)
            // Link-local scope ids ("fe80::1%en0") are not valid DNS server addresses.
            if address.contains("%") { continue }
            if !addresses.contains(address) { addresses.append(address) }
        }
        return addresses.isEmpty ? .failed : .addresses(addresses)
    }
}
