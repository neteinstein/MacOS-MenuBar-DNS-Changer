// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrivateDNSMenuBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PrivateDNSMenuBar", targets: ["PrivateDNSMenuBar"]),
        .library(name: "DNSChangerCore", targets: ["DNSChangerCore"]),
    ],
    targets: [
        // Pure Foundation: presets, rules, pause, automation commands and profile generation.
        // Builds and tests on any platform Swift runs on.
        .target(name: "DNSChangerCore"),
        // The menu bar app: SwiftUI, NetworkExtension, ServiceManagement. macOS only.
        .executableTarget(name: "PrivateDNSMenuBar", dependencies: ["DNSChangerCore"]),
        .testTarget(name: "DNSChangerCoreTests", dependencies: ["DNSChangerCore"]),
    ]
)
