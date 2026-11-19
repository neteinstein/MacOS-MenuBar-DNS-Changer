# Agent instructions

## Bump the version with every change to the app

Every PR that changes what the app is or how it's built (`Sources/`, `Resources/`, `Package.swift`,
`scripts/`) gets a version of its own, in that same PR, in
[`Resources/Info.plist`](Resources/Info.plist):

- `CFBundleShortVersionString`: always bump the minor version, the middle number, and leave the
  other two alone: 0.3.0 → 0.4.0 → 0.5.0. A fix gets a minor bump just like a feature. Don't use
  the patch number, and don't bump the major one unless the user asks for it.
- `CFBundleVersion`: add 1.

Changes that only touch documentation, tests or CI ship nothing to users, so they get no version.

## Keep the Homebrew tap in step with this repository

Homebrew users only get what the formula in
[neteinstein/homebrew-tap](https://github.com/neteinstein/homebrew-tap) pins, so an update here
isn't finished until the tap serves it as a new version.

Whenever a PR bumps the version, update `Formula/macos-dns-changer.rb` in the tap to that version
(`url`, `version`, `sha256`) in a PR that links this one. Follow
[`docs/releasing.md`](docs/releasing.md) step by step: it says which commit to pin, how to check
the build, and the order to merge in.

Whenever you change
[`packaging/homebrew/macos-dns-changer.rb`](packaging/homebrew/macos-dns-changer.rb), carry the
change over to the tap as well. If no version bump goes with it, add or bump `revision` in the
tap's copy so that `brew upgrade` picks it up.

Don't report the work as done while the tap is behind. If you can't open the tap PR yourself (no
access to that repository, say), tell the user that the tap still needs updating and which commit
to pin. Never skip it silently.
