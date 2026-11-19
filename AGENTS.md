# Agent instructions

## Keep the Homebrew tap in step with this repository

Homebrew users only get what the formula in
[neteinstein/homebrew-tap](https://github.com/neteinstein/homebrew-tap) pins, so an update here
isn't finished until the tap serves it as a new version.

Whenever you change what the app is or how it's built (`Sources/`, `Resources/`, `Package.swift`,
`scripts/`):

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   [`Resources/Info.plist`](Resources/Info.plist) in the same PR.
2. Update `Formula/macos-dns-changer.rb` in the tap to that version (`url`, `version`, `sha256`)
   in a PR that links this one. Follow [`docs/releasing.md`](docs/releasing.md) step by step: it
   says which commit to pin, how to check the build, and the order to merge in.

Whenever you change
[`packaging/homebrew/macos-dns-changer.rb`](packaging/homebrew/macos-dns-changer.rb), carry the
change over to the tap as well. If no version bump goes with it, add or bump `revision` in the
tap's copy so that `brew upgrade` picks it up.

Changes that only touch documentation, tests or CI ship nothing to users, so they need neither a
version bump nor a tap update.

Don't report the work as done while the tap is behind. If you can't open the tap PR yourself (no
access to that repository, say), tell the user that the tap still needs updating and which commit
to pin. Never skip it silently.
