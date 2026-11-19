# Development

## Build and test

```bash
swift test                 # unit tests for presets, rules, pause, automation and profiles
swift run PrivateDNSMenuBar  # quick run from the terminal (profile mode; no notifications)
scripts/build-app.sh       # "build/Private DNS.app" for this Mac, ad-hoc signed
UNIVERSAL=1 scripts/build-app.sh && scripts/make-dmg.sh   # Apple silicon + Intel, build/Private-DNS.dmg
```

Requires Xcode 15 or later (Swift 5.9) or its command line tools (`UNIVERSAL=1` needs full Xcode). The ad-hoc signed app uses configuration profiles. CI ([`ci.yml`](../.github/workflows/ci.yml)) runs the tests and both builds on every push.

## Signing with the Network Extension entitlement

1. In your Apple Developer account, create an App ID (e.g. `org.example.privatedns`) with the **Network Extensions** capability.
2. Create a **Developer ID** (or Mac Development) provisioning profile for it and download it.
3. Build and sign:

   ```bash
   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" TEAM_ID=TEAMID BUNDLE_ID=org.example.privatedns PROVISIONING_PROFILE=~/Downloads/PrivateDNS.provisionprofile scripts/build-app.sh
   ```

4. Optionally pack it with `scripts/make-dmg.sh`, notarize `build/Private-DNS.dmg` with `xcrun notarytool submit --wait` and staple it.

## Project layout

| Path | What |
| --- | --- |
| `Sources/DNSChangerCore` | Platform-independent logic: presets and provider info, hostname and NextDNS validation, settings, toggle cycling, per-network settings → on-demand rules and provider switches, pause, the update check and update scripts, the switch-back verdict, `privatedns://` parsing, `.mobileconfig` generation |
| `Sources/PrivateDNSMenuBar` | The app: menu, Settings window, the two DNS backends, resolver probes, network monitor |
| `Tests/DNSChangerCoreTests` | XCTest unit tests for the core |
| `Resources` | `Info.plist` (the version lives here) and the entitlements template used by `scripts/build-app.sh` |
| `scripts` | `build-app.sh` builds the app, `make-dmg.sh` packs the disk image |
| `packaging/homebrew` | The source copy of the tap's `macos-dns-changer` formula |
| `.github/workflows` | `ci.yml` (tests and builds on every push), `release.yml` (publishes the disk image for each new version on `main`) |
| `docs/demo/source` | The demo video's scene, soundtrack and render scripts |

## Releases

The disk image on GitHub Releases and the Homebrew formula in `neteinstein/homebrew-tap`: see [Releasing](releasing.md).

## The demo video

`docs/private-dns.mp4` (and its previews `docs/demo.webp`, `docs/poster.jpg` and the pictures in `docs/look/`) was made with [/brag](https://github.com/latent-spaces/brag). The scene is plain HTML whose every frame is a function of time; the menu in it uses the app's own items and strings from `MenuContent.swift`, drawn in the macOS menu style. To change and re-render it (needs Node with Playwright, Python with NumPy, and ffmpeg):

```bash
cd docs/demo/source
NODE_PATH="$(npm root -g)" node render.mjs /tmp/frames 30 22
python3 music.py /tmp/music.wav
cp /tmp/frames/f0195.png /tmp/frames/f0000.png   # the poster frame doubles as frame 0 (the thumbnail)
ffmpeg -framerate 30 -i /tmp/frames/f%04d.png -i /tmp/music.wav -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart ../../private-dns.mp4
ffmpeg -i ../../private-dns.mp4 -vf "fps=15,scale=860:-1:flags=lanczos" -c:v libwebp_anim -q:v 60 -loop 0 -an ../../demo.webp
```

`brag-plan.md` is the storyboard and `share-copy.txt` a caption for posting it.
