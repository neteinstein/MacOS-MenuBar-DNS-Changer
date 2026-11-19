# /brag plan: Private DNS (MacOS-MenuBar-DNS-Changer)

**What:** a Mac menu bar app that turns on encrypted DNS (DNS over TLS) with a provider you pick, in one click.
**For:** anyone on a Mac who doesn't want their Wi-Fi, ISP or hotel network reading every site they look up.
**Sets it apart:** one click from the menu bar, 24 named providers with who-runs-it info, pause and per-network rules, free via DMG or Homebrew.
**Hook:** the plain-text DNS lookups your Mac broadcasts, streaming past, readable by anyone on the network.
**Visual hook:** the lookups scramble into ciphertext the moment the lock closes.
**Real UI:** the app's own menu (status line, Turn On (Cloudflare), Pause, Favourites, Providers ▸ categories, About provider) with its exact strings, redrawn in the macOS menu style (the app is SwiftUI and can't render off a Mac).
**Tone:** default (punchy, clean). **Share caption:** see share-copy.txt.

Identity: macOS light menu material, system blue #0A84FF accent, Inter (stand-in for SF Pro), dark navy stage #0B1020, green #30D158 for "on".
Music: 120 BPM (beat 0.5 s, bar 2 s), A minor → C major lift at the reveal. Every cut on a beat.

| # | Time | Scene |
|---|---|---|
| 1 Hook | 0–3 s | Plain-text domain names stream up a dark screen. "Your Mac tells the network every site you visit." |
| 2 Reveal | 3–7.5 s | macOS menu bar, open-lock icon. Cursor clicks it, the menu drops, cursor clicks **Turn On (Cloudflare)**. Lock closes, status reads "Private DNS: Cloudflare / ✓ Provider is answering". Caption "One click. Encrypted DNS." |
| 3 Providers | 7.5–11.5 s | Providers ▸ Standard / Ad & malware blocking / Family / Custom cascade; Quad9 picked; About card: Quad9 Foundation, Switzerland, blocks malicious domains. Caption "24 providers. Know who runs each one." |
| 4 Pause & rules | 11.5–15.5 s | Pause ▸ 15 minutes; icon becomes pause, status "paused (15 min left)". Then a rule chip: Off on "Hotel Wi-Fi" — macOS applies it. Caption "Pause for a hotel login. Or let a rule do it." |
| 5 Automation | 15.5–17.5 s | Terminal types `open "privatedns://toggle?token=…"`, menu bar lock flips. Caption "Scriptable." |
| 6 Outro | 17.5–21 s | Icon, "Private DNS", "Encrypted DNS from your menu bar", `brew install neteinstein/tap/macos-dns-changer` · "or download Private-DNS.dmg" · macOS 13+ · free. |

No personal data: domains are generic public sites; the token is shown as "…".
