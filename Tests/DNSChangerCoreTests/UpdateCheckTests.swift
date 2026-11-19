import XCTest
@testable import DNSChangerCore

final class UpdateCheckTests: XCTestCase {
    func testNumericDottedComparison() {
        XCTAssertTrue(UpdateCheck.isNewer("0.2.0", than: "0.1.0"))
        XCTAssertFalse(UpdateCheck.isNewer("0.1.0", than: "0.2.0"))
        XCTAssertFalse(UpdateCheck.isNewer("0.1.0", than: "0.1.0"))
        XCTAssertTrue(UpdateCheck.isNewer("0.10.0", than: "0.9.9"), "components compare as numbers, not text")
        XCTAssertTrue(UpdateCheck.isNewer("1.0", than: "0.99.99"))
    }

    func testTagPrefixSuffixAndMissingComponents() {
        XCTAssertTrue(UpdateCheck.isNewer("v0.2.0", than: "0.1.0"), "release tags start with v")
        XCTAssertFalse(UpdateCheck.isNewer("1.2", than: "1.2.0"))
        XCTAssertFalse(UpdateCheck.isNewer("1.2.0", than: "1.2"))
        XCTAssertFalse(UpdateCheck.isNewer("0.2.0-beta", than: "0.2.0"), "pre-release suffixes are ignored")
        XCTAssertTrue(UpdateCheck.isNewer("0.2.1-beta", than: "0.2.0"))
        XCTAssertFalse(UpdateCheck.isNewer("", than: "0.1.0"), "an empty version is never an update")
        XCTAssertFalse(UpdateCheck.isNewer("not a version", than: "0.1.0"))
    }

    func testParsesTheLatestReleaseResponse() throws {
        let json = #"{"tag_name":"v0.3.0","html_url":"https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/releases/tag/v0.3.0","name":"Per-network providers"}"#
        let latest = try XCTUnwrap(UpdateCheck.latest(fromReleaseJSON: Data(json.utf8)))
        XCTAssertEqual(latest.version, "v0.3.0")
        XCTAssertEqual(latest.url?.absoluteString, "https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/releases/tag/v0.3.0")
        XCTAssertTrue(UpdateCheck.isNewer(latest.version, than: "0.1.0"))

        XCTAssertNil(UpdateCheck.latest(fromReleaseJSON: Data(#"{"message":"Not Found"}"#.utf8)),
                     "a repo without releases answers 404 with no tag_name")
        XCTAssertNil(UpdateCheck.latest(fromReleaseJSON: Data("not json".utf8)))
    }

    func testReadsTheVersionFromAnInfoPlist() throws {
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleName</key><string>Private DNS</string>
                <key>CFBundleShortVersionString</key><string>0.4.2</string>
            </dict>
            </plist>
            """
        XCTAssertEqual(UpdateCheck.version(fromInfoPlist: Data(plist.utf8)), "0.4.2")
        XCTAssertNil(UpdateCheck.version(fromInfoPlist: Data("junk".utf8)))
    }
}

final class UpdateCheckFormulaAndScheduleTests: XCTestCase {
    func testReadsTheVersionFromAFormula() {
        let formula = """
            class MacosDnsChanger < Formula
              desc "Menu bar app that turns on encrypted DNS"
              url "https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/archive/bfb7da4.tar.gz"
              version "2.0.1"
              sha256 "ca3a079c"

              def caveats
                <<~EOS
                  brew upgrade doesn't restart a running Private DNS: it keeps
                  running the old version until it quits.
                EOS
              end
            end
            """
        XCTAssertEqual(UpdateCheck.version(fromFormula: formula), "2.0.1")
        XCTAssertNil(UpdateCheck.version(fromFormula: "class MacosDnsChanger < Formula\nend\n"))
        XCTAssertNil(UpdateCheck.version(fromFormula: #"  version """#), "an empty version is no version")
        XCTAssertNil(UpdateCheck.version(fromFormula: "404: Not Found"))
    }

    func testDueOnceADay() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        XCTAssertTrue(UpdateCheck.isDue(lastChecked: nil, now: now), "never checked")
        XCTAssertFalse(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(-3600), now: now))
        XCTAssertFalse(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(-23.9 * 3600), now: now))
        XCTAssertTrue(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(-24 * 3600), now: now))
        XCTAssertTrue(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(-5 * 24 * 3600), now: now),
                      "a Mac that slept for days checks as soon as it wakes")
        XCTAssertTrue(UpdateCheck.isDue(lastChecked: now.addingTimeInterval(3600), now: now),
                      "a check dated in the future means the clock was set back")
    }
}

final class UpdateScriptTests: XCTestCase {
    private let prefix = URL(fileURLWithPath: "/opt/homebrew")

    func testFindsTheHomebrewPrefixAndTheClone() {
        XCTAssertEqual(UpdateCheck.homebrewPrefix(forResolvedBundle: URL(fileURLWithPath:
            "/opt/homebrew/Cellar/macos-dns-changer/2.0.1/Private DNS.app"))?.path, "/opt/homebrew")
        XCTAssertEqual(UpdateCheck.homebrewPrefix(forResolvedBundle: URL(fileURLWithPath:
            "/usr/local/Cellar/macos-dns-changer/2.0.1/Private DNS.app"))?.path, "/usr/local")
        XCTAssertNil(UpdateCheck.homebrewPrefix(forResolvedBundle: URL(fileURLWithPath:
            "/Users/me/MacOS-MenuBar-DNS-Changer/build/Private DNS.app")))

        XCTAssertEqual(UpdateCheck.sourceClone(forResolvedBundle: URL(fileURLWithPath:
            "/Users/me/MacOS-MenuBar-DNS-Changer/build/Private DNS.app"))?.path, "/Users/me/MacOS-MenuBar-DNS-Changer")
        XCTAssertNil(UpdateCheck.sourceClone(forResolvedBundle: URL(fileURLWithPath:
            "/Applications/Private DNS.app")), "a build copied out of its clone")
    }

    func testHomebrewUpgradeThenReopen() throws {
        let script = try XCTUnwrap(UpdateCheck.updateScript(for: .homebrew(.init(prefix: prefix))))
        XCTAssertTrue(script.hasPrefix("#!/bin/bash\n"))
        XCTAssertTrue(script.contains("set -euo pipefail\n"), "stops at the first failure")
        assertInOrder(script, [
            "'/opt/homebrew/bin/brew' update\n",
            "'/opt/homebrew/bin/brew' upgrade macos-dns-changer\n",
            "pkill -x PrivateDNSMenuBar || true\n",
            "sleep 1\n",
            "open '/opt/homebrew/opt/macos-dns-changer/Private DNS.app'\n",
        ])
        XCTAssertFalse(script.contains("su "))
        XCTAssertFalse(script.contains("launchctl"))
    }

    func testHomebrewServiceIsRestartedByLaunchd() throws {
        let script = try XCTUnwrap(UpdateCheck.updateScript(for: .homebrew(.init(
            prefix: prefix, serviceLabel: "sh.brew.macos-dns-changer"))))
        assertInOrder(script, [
            "'/opt/homebrew/bin/brew' upgrade macos-dns-changer\n",
            #"launchctl kickstart -k "gui/$(id -u)/"'sh.brew.macos-dns-changer'"# + "\n",
        ])
        XCTAssertFalse(script.contains("pkill"), "launchd restarts the job itself")
    }

    func testHomebrewFromAnAdminAccountUpgradesAsThatAccount() throws {
        let script = try XCTUnwrap(UpdateCheck.updateScript(for: .homebrew(.init(
            prefix: prefix, owner: "admin.me", serviceLabel: "sh.brew.macos-dns-changer"))))
        assertInOrder(script, [
            "su - 'admin.me' -c ''\\''/opt/homebrew/bin/brew'\\'' update && '\\''/opt/homebrew/bin/brew'\\'' upgrade macos-dns-changer'\n",
            // The restart runs as the account logged in to the desktop, not the admin one.
            #"launchctl kickstart -k "gui/$(id -u)/"'sh.brew.macos-dns-changer'"#,
        ])
        XCTAssertFalse(script.contains("\n'/opt/homebrew/bin/brew' upgrade"), "never upgrades as this account")
    }

    func testSourceBuildPullsRebuildsAndReopens() throws {
        let script = try XCTUnwrap(UpdateCheck.updateScript(for: .source(clone: URL(fileURLWithPath: "/Users/me/Pedro's Code/MacOS-MenuBar-DNS-Changer"))))
        assertInOrder(script, [
            "cd '/Users/me/Pedro'\\''s Code/MacOS-MenuBar-DNS-Changer'\n",
            "git pull --ff-only\n",
            "scripts/build-app.sh\n",
            "pkill -x PrivateDNSMenuBar || true\n",
            "open 'build/Private DNS.app'\n",
        ])
        XCTAssertNil(UpdateCheck.updateScript(for: .source(clone: nil)), "nowhere to pull into")
    }

    func testQuotesForTheShell() {
        XCTAssertEqual(UpdateCheck.quoted("plain"), "'plain'")
        XCTAssertEqual(UpdateCheck.quoted("it's $HOME"), #"'it'\''s $HOME'"#)
    }

    private func assertInOrder(_ text: String, _ parts: [String], file: StaticString = #filePath, line: UInt = #line) {
        var rest = text[...]
        for part in parts {
            guard let range = rest.range(of: part) else {
                return XCTFail("missing or out of order: \(part)\nin:\n\(text)", file: file, line: line)
            }
            rest = rest[range.upperBound...]
        }
    }
}
