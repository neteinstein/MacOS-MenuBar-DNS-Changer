# How it works

## Two ways to change the system DNS

macOS only lets an app change the system DNS with Apple's permission, in one of two ways. The app picks the right one by itself: it checks at launch whether it was signed with the `dns-settings` entitlement.

### Network Extension (instant switching)

A build signed with the `dns-settings` Network Extension entitlement uses [`NEDNSSettingsManager`](https://developer.apple.com/documentation/networkextension/nednssettingsmanager). Like the one-time `adb shell pm grant` on Android, macOS asks once:

1. Open the app and pick a provider.
2. In **System Settings → Network → Filters** (*VPN & Filters* on macOS 13–14), turn on **Private DNS Menu Bar**. The menu shows *Allow in System Settings…* until you do.

After that, every switch is instant and needs no password. Turning it off keeps the configuration but gives it a single "never" rule, so you don't have to allow it again.

### Configuration profiles (any build)

A build without the entitlement (the DMG, Homebrew, or your own build without a paid Apple developer account) writes a `.mobileconfig` with a `DNSSettings` payload for each switch, into `~/Library/Application Support/PrivateDNSMenuBar/`, and hands it to macOS. Install it in **System Settings → Privacy & Security → Profiles** (double-click it, then *Install…*). All profiles share one identifier, so each new one replaces the previous one; *Off* installs a profile with a single "never" rule. You can also remove the profile there.

macOS doesn't let apps read installed device profiles without admin rights, so in this mode the menu shows the last setting you asked for.

Settings › Why Profiles says the same in the app: why this copy needs profiles, what that means day to day, and how to switch without them.

## What macOS is given

Both methods give macOS the same thing, the equivalent of Android's *Private DNS provider hostname*:

| Setting | Value |
| --- | --- |
| Protocol | DNS over TLS (port 853) |
| Server name | the provider hostname, e.g. `dns.google`, checked against its TLS certificate |
| Server addresses | the hostname's IPv4 and IPv6 addresses, looked up just before the switch (and remembered, in case the lookup fails later) |
| On-demand rules | your network rules, then "use it everywhere else"; or a single "never" rule for Off |

## Settings per Wi-Fi network

Settings › Wi-Fi networks has a section per network, like Calendar Hub's section per calendar. Each network either turns Private DNS **off** or uses **a provider of its own**:

- **Off** becomes an on-demand rule of the DNS configuration, so macOS applies it on every network change, matches the network by name itself, and doesn't need the app to be running or any permission.
- **A provider of its own** is a switch the app makes when the Mac joins the network: it remembers the provider in use, switches, and switches back when you leave, unless you picked another provider by hand in the meantime. It needs the app running, the Network Extension build (with profiles, every switch would be a profile to install), and Location Services access, because macOS 14 and later only tell apps the Wi-Fi network's name with it. If one of these is missing, the section says what to do.

*Everywhere else* can also turn it off on any other Wi-Fi network and on Ethernet. The rules macOS sees, first match wins: networks set to off, networks with a provider of their own (kept on), any other Wi-Fi, Ethernet, then "use encrypted DNS".

## Updates

Once a day, and from **Check for updates** in Settings › About, the app asks GitHub for the newest version: for a Homebrew install, the version the tap serves (what `brew upgrade` installs); otherwise the latest release, or the version on `main` before there is one. When there's a newer one, the menu shows **Update to Version …** and About shows **Update…**:

- **Homebrew:** Terminal opens and runs `brew update` and `brew upgrade macos-dns-changer`, then restarts the app (with `launchctl kickstart` under `brew services`). If Homebrew belongs to another account, it runs as that account and asks for its password.
- **DMG:** the browser downloads the new `Private-DNS.dmg`; drag it into Applications.
- **Source build:** Terminal pulls, rebuilds and reopens it, while the app is still in its clone's `build` folder.

## The connection check

After a switch, the app looks up a few well-known names (`www.apple.com`, `www.wikipedia.org`, `www.icloud.com`, `www.google.com`) through the system resolver, every few seconds. One answer is enough. If none resolves within about 20 seconds while the Mac is online, the app restores the previous setting and shows a notification. Being offline never counts against the provider. It also checks every two minutes and after network changes, for the "Provider is answering" line in the menu. It only runs with the Network Extension method; with profiles, the switch waits for you in System Settings.

## Pause

Pause installs Off and remembers the provider and the end time. The app checks every 15 seconds and when the Mac wakes; when the time is up it switches the provider back on. Pausing again keeps the provider of the first pause. Turning DNS on yourself ends the pause.

## Toggle and favourites

Toggle (⌘T in the menu, or `privatedns://toggle`) switches between Off and the provider chosen for *Turn On*. With *Toggle cycles through favourites* on and two or more favourites, it steps Off → favourite 1 → favourite 2 → … → Off, like the Android widget.

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

## Differences from the Android app

- **No "Automatic" mode.** Android's opportunistic mode has no macOS equivalent; Off uses your network's DNS servers.
- **No VPN rule.** Rules match Wi-Fi networks by name, any Wi-Fi and Ethernet; in exchange, each Wi-Fi network can have its own setting.
- **No widget or Quick Settings tile:** the menu bar icon is both. It shows a shield while encrypted DNS is in use, an open lock when it's off, a pause sign while paused, and a warning when the provider isn't answering or isn't in use yet.
- English only for now.
