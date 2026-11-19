# Releasing

Private DNS ships two ways, like [Calendar Hub](https://github.com/neteinstein/Calendar-Hub):

1. **Disk image:** `Private-DNS.dmg` on [GitHub Releases](https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/releases), for people who don't use Homebrew.
2. **Homebrew:** `brew install neteinstein/tap/macos-dns-changer`, which builds the app from source on the user's Mac.

## Bumping the version

The version is `CFBundleShortVersionString` (and the `CFBundleVersion` build number) in
[`Resources/Info.plist`](../Resources/Info.plist). Every PR that changes the app bumps the minor
version (0.3.0 → 0.4.0) and adds 1 to the build number; [`AGENTS.md`](../AGENTS.md) has the rule.

**The disk image is automatic.** Every push to `main` runs [`release.yml`](../.github/workflows/release.yml):
if there's no release tagged `v<version>` yet, it tests, builds a universal (Apple silicon and Intel)
app, packs `Private-DNS.dmg` with [`scripts/make-dmg.sh`](../scripts/make-dmg.sh) and publishes the
release. Pushes that don't change the version do nothing.

**Homebrew users only get a new version when the formula in the tap changes**, so every version
bump must be followed by a PR on [neteinstein/homebrew-tap](https://github.com/neteinstein/homebrew-tap)
that updates `Formula/macos-dns-changer.rb`. A bump isn't done until the tap serves it.

1. Cut the bump's branch from the current `main` and push it before touching the tap. The formula
   pins a commit archive, so the pinned commit has to exist on GitHub. Pin the branch head
   (`git rev-parse HEAD`) and merge the PR with a merge commit (not squash), so that commit ends
   up on `main`. If the branch gets more commits before it merges, re-pin.
2. In the tap's `Formula/macos-dns-changer.rb`, set:
   - `url` to `https://github.com/neteinstein/MacOS-MenuBar-DNS-Changer/archive/<commit>.tar.gz`
   - `version` to the new `CFBundleShortVersionString`
   - `sha256` to the output of `curl -sSL <url> | shasum -a 256`

   Also carry over anything else that changed in
   [`packaging/homebrew/macos-dns-changer.rb`](../packaging/homebrew/macos-dns-changer.rb) since the
   last update: apart from the header comment and the `url`/`version`/`sha256` pin (plus
   `revision`, which lives only in the tap), the two files are identical.
3. Check that the archive builds the way the formula builds it: extract it into an empty directory
   and run `scripts/build-app.sh --disable-sandbox` there. (CI runs the same command on every push.)
4. In the tap, commit as `macos-dns-changer <version>` on a branch `macos-dns-changer-<version>`,
   push it, and open a PR against the tap's `main` that links the app PR. Merge the app PR first,
   then the tap PR.

If the formula has to change without a version bump (a build fix, say), update the tap the same way,
and add or bump `revision` so that `brew upgrade` picks the change up.

## Requirements for both channels

The repository must be **public**: Homebrew downloads the source archive and users download the disk
image without signing in to GitHub.
