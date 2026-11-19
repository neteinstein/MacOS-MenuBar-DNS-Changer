# MacOS-MenuBar-DNS-Changer

**Private DNS for the Mac menu bar.** Turn on encrypted DNS (DNS over TLS) with a provider you choose in advance, in one click, for every app on the Mac. This is the macOS version of [Private DNS Changer](https://github.com/neteinstein/Private-DNS-Changer) for Android.

- **Menu bar toggle:** turn encrypted DNS on with your chosen provider, or off (⌘T while the menu is open).
- **Providers:** Cloudflare, Google, Quad9, Mullvad, Control D, AdGuard, DNS4EU, DNS.SB, CleanBrowsing, ad-blocking and family filters, a NextDNS configuration ID, or your own DNS-over-TLS hostname. Each built-in one has an *About* panel: who runs it, where it's based, what it blocks, and its privacy policy.
- **Favourites:** star providers to list them at the top of the menu. With *Toggle cycles through favourites* on, Toggle steps through them and then Off.
- **Pause:** off for 5 min, 15 min or 1 h, then back on by itself.
- **Network rules:** keep encrypted DNS off on any Wi-Fi, on Ethernet, or on named Wi-Fi networks (a hotel network with a sign-in page, an office network with internal names). macOS applies them itself, even while the app is closed.
- **Safe switching:** after a switch the app checks that the new provider answers, and puts the previous setting back if it doesn't. The menu shows whether the provider in use is answering.
- **Automation:** `privatedns://` links for Shortcuts, scripts and automation apps, protected by a token.
- **Open at login.**

Requires macOS 13 Ventura or later. Built with Swift, SwiftUI (`MenuBarExtra`) and Swift Package Manager; no Xcode project needed.

## How to install

**No Terminal:** download [Private-DNS.dmg](https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/releases/latest/download/Private-DNS.dmg) and follow [Install Private DNS](docs/download.md), a step-by-step guide.

With [Homebrew](https://brew.sh/):

```bash
brew install neteinstein/tap/macos-dns-changer
```

```bash
brew trust --formula neteinstein/tap/macos-dns-changer
```

```bash
brew services start neteinstein/tap/macos-dns-changer
```

The first command builds the app on your Mac (it needs the Xcode command line tools) and installs it. The second marks the formula as trusted, since recent Homebrew versions won't run formula code from a third-party tap until you say you trust it. The third starts it now and at every login; to start it once instead, run `open "$(brew --prefix)/opt/macos-dns-changer/Private DNS.app"`.

Update with `brew update && brew upgrade macos-dns-changer`, then `brew services restart macos-dns-changer`.

Both the disk image and Homebrew give you an app that isn't signed by Apple, so it uses [configuration profiles](#configuration-profiles-any-build) to switch DNS.

## Setup

macOS only lets an app change the system DNS with Apple's permission, in one of two ways. The app picks the right one by itself.

### Network Extension (instant switching)

A build signed with the `dns-settings` Network Extension entitlement uses [`NEDNSSettingsManager`](https://developer.apple.com/documentation/networkextension/nednssettingsmanager). Like the one-time `adb shell pm grant` on Android, macOS asks once:

1. Open the app and pick a provider.
2. In **System Settings → Network → Filters** (*VPN & Filters* on macOS 13–14), turn on **Private DNS Menu Bar**. The menu shows *Allow in System Settings…* until you do.

After that, every switch is instant and needs no password. Turning it off keeps the configuration but tells macOS not to use it, so you don't have to allow it again.

### Configuration profiles (any build)

A build without the entitlement (for example one you build yourself without a paid Apple developer account) writes a `.mobileconfig` with a `DNSSettings` payload for each switch and hands it to macOS. Install it in **System Settings → Privacy & Security → Profiles** (double-click it, then *Install…*). All profiles share one identifier, so each new one replaces the previous one; *Off* installs a profile that tells macOS not to use encrypted DNS. You can also remove the profile there.

## How it works

Both methods give macOS the same thing, the equivalent of Android's *Private DNS provider hostname*:

| Setting | Value |
| --- | --- |
| Protocol | DNS over TLS (port 853) |
| Server name | the provider hostname, e.g. `dns.google`, checked against its TLS certificate |
| Server addresses | the hostname's IPv4 and IPv6 addresses, looked up just before the switch (and remembered, in case the lookup fails later) |
| On-demand rules | your network rules, then "use it everywhere else"; or a single "never" rule for Off |

**Network rules** are on-demand rules, so macOS evaluates them on every network change, can match Wi-Fi networks by name, and doesn't need the app to be running.

**The connection check** looks up a few well-known names through the system resolver after a switch. If none of them resolves within about 20 seconds while the Mac is online, the app restores the previous setting and shows a notification. Being offline never counts against the provider. It only runs with the Network Extension method; with profiles, the switch waits for you in System Settings.

## Automation

Turn on *Allow automation* in Settings → Automation and copy your token. Then open links like these, from Shortcuts (*Open URLs*), a script, Raycast, Alfred, Keyboard Maestro and so on:

| Link | Does |
| --- | --- |
| `privatedns://on?token=…` | On, with your provider |
| `privatedns://on?token=…&host=dns.quad9.net` | On, with this hostname |
| `privatedns://off?token=…` | Off |
| `privatedns://toggle?token=…` | Same as the menu's toggle |
| `privatedns://pause?token=…&minutes=30` | Pause (1 to 1440 minutes, default 15) |
| `privatedns://resume?token=…` | End a pause now |

```bash
open "privatedns://pause?minutes=10&token=YOUR_TOKEN"
```

Links without the right token, or while automation is off, are ignored, so a web page can't change your DNS. *New token* invalidates the old one.

## Build

```bash
swift test                 # unit tests for presets, rules, pause, automation and profiles
swift run PrivateDNSMenuBar  # quick run from the terminal (profile mode; no notifications)
scripts/build-app.sh       # "build/Private DNS.app" for this Mac, ad-hoc signed
UNIVERSAL=1 scripts/build-app.sh && scripts/make-dmg.sh   # Apple silicon + Intel, build/Private-DNS.dmg
```

Requires Xcode 15 or later (Swift 5.9) or its command line tools (`UNIVERSAL=1` needs full Xcode). The ad-hoc signed app uses configuration profiles.

Releases (the disk image on GitHub Releases and the Homebrew formula in `neteinstein/homebrew-tap`) are described in [Releasing](docs/releasing.md).

### Signing with the Network Extension entitlement

1. In your Apple Developer account, create an App ID (e.g. `org.example.privatedns`) with the **Network Extensions** capability.
2. Create a **Developer ID** (or Mac Development) provisioning profile for it and download it.
3. Build and sign:

   ```bash
   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" TEAM_ID=TEAMID BUNDLE_ID=org.example.privatedns PROVISIONING_PROFILE=~/Downloads/PrivateDNS.provisionprofile ./scripts/build-app.sh
   ```

4. Optionally pack it with `scripts/make-dmg.sh`, notarize `build/Private-DNS.dmg` with `xcrun notarytool submit --wait` and staple it.

## Project layout

| Path | What |
| --- | --- |
| `Sources/DNSChangerCore` | Platform-independent logic: presets and provider info, hostname and NextDNS validation, settings, toggle cycling, network rules → on-demand rules, pause, the switch-back verdict, `privatedns://` parsing, `.mobileconfig` generation |
| `Sources/PrivateDNSMenuBar` | The app: menu, Settings window, the two DNS backends, resolver probes, network monitor |
| `Tests/DNSChangerCoreTests` | XCTest unit tests for the core |
| `Resources` | `Info.plist` (the version lives here) and the entitlements template used by `scripts/build-app.sh` |
| `scripts` | `build-app.sh` builds the app, `make-dmg.sh` packs the disk image |
| `packaging/homebrew` | The source copy of the tap's `macos-dns-changer` formula |
| `.github/workflows` | `ci.yml` (tests and builds on every push), `release.yml` (publishes the disk image for each new version on `main`) |

## Differences from the Android app

- **No "Automatic" mode.** Android's opportunistic mode has no macOS equivalent; Off uses your network's DNS servers.
- **No VPN rule.** On-demand rules match Wi-Fi, Ethernet and Wi-Fi network names; in exchange, Wi-Fi networks can be matched by name.
- **No widget or Quick Settings tile:** the menu bar icon is both. It shows a closed lock while encrypted DNS is in use, an open lock when it's off, a pause sign while paused, and a warning when the provider isn't answering or isn't in use yet.
- English only for now.
