import AppKit
import SwiftUI

/// Settings › Why Profiles: why a copy without Apple's entitlement switches DNS with
/// configuration profiles, what that means day to day, and how to switch without them.
struct WhyProfilesTab: View {
    @EnvironmentObject private var model: AppModel

    private static let howItWorksPage = URL(string: "https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/blob/main/docs/how-it-works.md#two-ways-to-change-the-system-dns")!
    private static let signingPage = URL(string: "https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/blob/main/docs/development.md#signing-with-the-network-extension-entitlement")!

    /// False for a copy signed with the Network Extension entitlement, which the last two
    /// sections don't apply to.
    private var usesProfiles: Bool { model.backend.kind == .profile }

    private var reasonTitle: String {
        usesProfiles ? "Why this copy uses profiles" : "Why other copies use profiles"
    }

    var body: some View {
        Form {
            Section {
                if usesProfiles {
                    Text("macOS doesn't let an app change the system's DNS by itself. Apple allows it in two ways only, and this copy of Private DNS can use just one of them: configuration profiles.")
                } else {
                    Text("This copy is signed with Apple's Network Extension entitlement, so it switches DNS by itself and doesn't use profiles. Copies without the entitlement (the disk image, Homebrew, a build of your own) do, for the reasons below.")
                }
            }

            Section("The two ways macOS allows") {
                way(
                    "Network Extension",
                    symbol: "bolt.fill",
                    text: "The app changes DNS itself, instantly, once you've allowed it in System Settings. Apple only gives this to apps signed with a paid Apple Developer account."
                )
                way(
                    "Configuration profile",
                    symbol: "checkmark.seal.fill",
                    text: "The app writes the DNS setting into a profile, and you install it in System Settings. Any app can do this, because you approve every change yourself."
                )
            }

            Section(reasonTitle) {
                Text("The disk image and the Homebrew build aren't signed by Apple, so they don't have the entitlement. Without it macOS refuses to let the app change DNS, and a profile is the only way left.")
                Text("The DNS servers in Network settings aren't a way round it: they only take plain, unencrypted DNS. Encrypted DNS for the whole Mac has to go through one of the two ways above.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if usesProfiles {
                Section("What it means for you") {
                    Text("Every switch is a profile to install, and so is turning it off: in System Settings › Privacy & Security › Profiles (General › Device Management on newer versions of macOS), double-click “Private DNS: …” and click Install.")
                    Text("Each profile replaces the one before, so there's only ever one to keep or remove.")
                    Text("macOS doesn't let apps read the profiles you've installed, so the menu shows the last setting you asked for.")
                    Button("Open Profiles") { SystemSettings.open(.profiles) }
                }

                Section("Switching without profiles") {
                    Text("A copy signed with the Network Extension entitlement switches instantly, after you allow it once in System Settings › Network › Filters. You can build one from the source code with your own Apple Developer account.")
                    HStack {
                        Button("How to build a signed copy") { NSWorkspace.shared.open(Self.signingPage) }
                        Button("How it works") { NSWorkspace.shared.open(Self.howItWorksPage) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func way(_ title: String, symbol: String, text: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(text)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(.secondary)
        }
    }
}
