import AppKit
import DNSChangerCore
import SwiftUI

/// Settings › About: the version, the update check and a donation, like Calendar Hub's.
struct AboutTab: View {
    @EnvironmentObject private var updates: UpdateChecker

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                VStack(spacing: 2) {
                    Text("Private DNS").font(.title2.bold())
                    Text("Version \(updates.currentVersion)").foregroundStyle(.secondary)
                }

                UpdateStatus()

                VStack(spacing: 4) {
                    Text("Made by Pedro Vicente").font(.headline)
                    Link("pedrovicente.pt", destination: URL(string: "https://pedrovicente.pt")!)
                }

                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.open(UpdateChecker.issuesPage)
                    } label: {
                        Label("Send feedback or report a bug", systemImage: "ladybug")
                    }
                    Button {
                        NSWorkspace.shared.open(UpdateChecker.repoPage)
                    } label: {
                        Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Divider().frame(width: 280)

                Text("If Private DNS keeps your browsing a little more private, a donation helps me keep developing open source and free software.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 400)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Support.donate()
                } label: {
                    Label("Support Private DNS", systemImage: "heart.fill")
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Donations.
@MainActor
enum Support {
    static func donate() {
        NSWorkspace.shared.open(UpdateChecker.donatePage)
    }
}

/// The update line in About: the warning when a newer version is out, otherwise a manual check.
struct UpdateStatus: View {
    @EnvironmentObject private var updates: UpdateChecker
    @State private var showingInstructions = false

    var body: some View {
        HStack(spacing: 10) {
            if let latest = updates.available {
                Label("Version \(latest.version) is available", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Update…") { showingInstructions = true }
                    .sheet(isPresented: $showingInstructions) { UpdateInstructionsSheet(latest: latest) }
            } else {
                Button("Check for updates") { Task { await updates.check() } }
                    .disabled(updates.isChecking)
                if updates.isChecking {
                    ProgressView().controlSize(.small)
                } else if updates.lastCheckFailed {
                    Text("Couldn't reach GitHub.").foregroundStyle(.secondary)
                } else if updates.lastChecked != nil {
                    Text("Up to date.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// How to update, for each way the app can be installed: the commands to run by hand, or
/// Terminal runs them; or the new disk image to download.
struct UpdateInstructionsSheet: View {
    let latest: UpdateCheck.Latest
    @Environment(\.dismiss) private var dismiss
    @State private var updateError: String?

    private var homebrew: UpdateCheck.Homebrew? { UpdateChecker.installation.homebrew }
    private var formula: String { UpdateCheck.formula }
    private var upgradeCommands: String { "brew update\nbrew upgrade \(formula)" }
    private var restartCommand: String { "brew services restart \(formula)" }
    private let sourceCommands = """
        cd MacOS-MenuBar-DNS-Changer
        git pull
        scripts/build-app.sh
        open "build/Private DNS.app"
        """

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update to version \(latest.version)").font(.headline)
            if UpdateChecker.isDownloadInstall {
                instruction(UpdateChecker.downloadSummary)
                note("Installed with Homebrew instead? Run “brew update && brew upgrade \(formula)”.")
            } else if let homebrew {
                if let owner = homebrew.owner {
                    instruction("Private DNS was installed with Homebrew from the “\(owner)” account, so the upgrade runs there. Quit the app, then in Terminal, logged in as \(owner), run:")
                    CommandBox(commands: upgradeCommands)
                    if homebrew.serviceLabel != nil {
                        instruction("Then, back in this account (\(NSUserName())), restart it:")
                        CommandBox(commands: restartCommand)
                    } else {
                        instruction("Then open Private DNS again from this account (\(NSUserName())).")
                    }
                } else {
                    instruction("Private DNS was installed with Homebrew. Quit the app, then run this in Terminal:")
                    CommandBox(commands: upgradeCommands + (homebrew.serviceLabel != nil ? "\n" + restartCommand : ""))
                }
                note("Homebrew builds the new version on your Mac. Your settings are kept.")
            } else {
                instruction("Private DNS is built from source. Quit the app, then run this in Terminal, from the folder you cloned it into:")
                CommandBox(commands: sourceCommands)
                note("That pulls the new version, rebuilds the app and opens it. Your settings are kept.")
            }
            if let updateError {
                Label(updateError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            HStack {
                if let url = latest.url {
                    Button("What's new on GitHub") { NSWorkspace.shared.open(url) }
                }
                Spacer()
                if UpdateChecker.isDownloadInstall {
                    Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Download") { NSWorkspace.shared.open(UpdateChecker.downloadDMG); dismiss() }.keyboardShortcut(.defaultAction)
                } else if UpdateChecker.canUpdateInTerminal {
                    Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Update in Terminal", action: updateInTerminal).keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func updateInTerminal() {
        Task {
            do {
                try await UpdateChecker.updateInTerminal()
                dismiss()
            } catch {
                updateError = "Couldn't open Terminal: \(error.localizedDescription)"
            }
        }
    }

    private func instruction(_ text: String) -> some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Commands to run in Terminal, selectable and with their own copy button.
struct CommandBox: View {
    let commands: String

    var body: some View {
        GroupBox {
            HStack(alignment: .top) {
                Text(commands)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(commands, forType: .string)
                }
            }
            .padding(4)
        }
    }
}

/// A switch that stays in the accent color when it's on. The system switch turns gray whenever
/// the Settings window isn't the key window, which happens often for a menu bar app.
struct AccentSwitchStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.secondary.opacity(0.25))
                .overlay(Capsule().strokeBorder(.black.opacity(0.1), lineWidth: 0.5))
                .frame(width: 26, height: 15)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
                        .frame(width: 13, height: 13)
                        .padding(1)
                }
                .animation(.easeOut(duration: 0.15), value: configuration.isOn)
                .opacity(isEnabled ? 1 : 0.5)
                .contentShape(Capsule())
                .onTapGesture { configuration.isOn.toggle() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton) // .isToggle needs macOS 14
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

extension AppModel {
    /// Asks first, then runs the update in Terminal, or downloads the new disk image.
    func confirmUpdate(to latest: UpdateCheck.Latest) {
        let current = UpdateChecker.shared.currentVersion
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            if UpdateChecker.isDownloadInstall {
                alert.messageText = "Download Private DNS \(latest.version)?"
                alert.informativeText = "You have version \(current). " + UpdateChecker.downloadSummary
                alert.addButton(withTitle: "Download")
            } else if UpdateChecker.canUpdateInTerminal {
                alert.messageText = "Update Private DNS to version \(latest.version)?"
                alert.informativeText = "You have version \(current). " + UpdateChecker.updateSummary
                alert.addButton(withTitle: "Update")
            } else {
                alert.messageText = "Version \(latest.version) is available"
                alert.informativeText = "You have version \(current). Settings › About shows how to update this copy."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            if UpdateChecker.isDownloadInstall {
                NSWorkspace.shared.open(UpdateChecker.downloadDMG)
                return
            }
            Task { @MainActor in
                do {
                    try await UpdateChecker.updateInTerminal()
                } catch {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }
}
