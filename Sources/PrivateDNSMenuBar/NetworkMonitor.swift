import CoreWLAN
import DNSChangerCore
import Foundation
import Network

/// Follows the Mac's default network: whether it's online, and whether it's Wi-Fi or Ethernet.
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "PrivateDNSMenuBar.NetworkMonitor")

    /// Called on the main queue with the new network and whether it is online.
    var onChange: ((NetworkSnapshot, Bool) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let kind: NetworkKind?
            if path.usesInterfaceType(.wifi) {
                kind = .wifi
            } else if path.usesInterfaceType(.wiredEthernet) {
                kind = .ethernet
            } else {
                kind = nil
            }
            let snapshot = NetworkSnapshot(kind: kind, ssid: kind == .wifi ? Self.currentSSID() : nil)
            let online = path.status == .satisfied
            DispatchQueue.main.async { self?.onChange?(snapshot, online) }
        }
        monitor.start(queue: queue)
    }

    /// The Wi-Fi network's name. macOS 14+ only reveals it to apps with Location Services access, so
    /// this is often nil: it's only used to explain in the menu why a rule is in effect. The rules
    /// themselves are evaluated by macOS, which always knows the name.
    static func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }
}
