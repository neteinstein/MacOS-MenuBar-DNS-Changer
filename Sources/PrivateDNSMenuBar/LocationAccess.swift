import AppKit
import CoreLocation

/// Location Services access, which macOS 14 and later require before an app may read the Wi-Fi
/// network's name. Only needed for networks that use a provider of their own: "off" settings are
/// applied by macOS, which always knows the name.
@MainActor
final class LocationAccess: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccess()

    @Published private(set) var status: CLAuthorizationStatus
    /// Called when access changes, so the app can read the network's name again.
    var onChange: (() -> Void)?

    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    // By raw value: 3 is "always" and 4 "when in use", whichever this macOS reports.
    var isGranted: Bool { status.rawValue == 3 || status.rawValue == 4 }
    var isDenied: Bool { status == .denied || status == .restricted }

    /// Asks once; after a refusal only System Settings can change it.
    func request() {
        if isDenied {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(url)
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.status = status
            self.onChange?()
        }
    }
}
