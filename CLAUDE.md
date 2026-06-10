# Timely

Minimal macOS menu bar timer. Swift + AppKit, built with SPM (no Xcode
project); the entire app is `Sources/Timely/main.swift`. `build.sh` wraps the
binary into `Timely.app` (ad-hoc signed) and zips it.

## Releasing

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist` and `version`
   in `Casks/timely.rb`.
2. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`. The GitHub
   Actions workflow (`.github/workflows/release.yml`) builds a universal
   `Timely.app` and creates a GitHub Release with `Timely.zip`.
3. Update the `sha256` in `Casks/timely.rb` (run `shasum -a 256 Timely.zip`
   on the release asset), then copy the cask to
   https://github.com/nikhilweee/homebrew-tap as `Casks/timely.rb` and push.

The cask exists in two places: `Casks/timely.rb` here (canonical copy) and
the `homebrew-tap` repo (the copy `brew` installs from). Step 3 keeps them in
sync.
