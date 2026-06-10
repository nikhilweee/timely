# Timely

A minimal menu bar timer for macOS.

- Click the timer icon and pick an interval (15 sec to 1 hour) to start.
- While running, the menu bar shows a live countdown. Left-click restarts the
  current interval (or pauses it, via the "Click to" setting in the menu);
  right-click shows a menu with Cancel and the intervals.
- When the timer finishes, the menu bar flashes. Click to restart the same
  interval.

## Install

```sh
brew install --cask --no-quarantine nikhilweee/tap/timely
```

The app is ad-hoc signed (no Apple Developer account), so `--no-quarantine` is
needed to avoid the Gatekeeper warning on first launch. Then launch Timely
from /Applications.

## Build from source

```sh
./build.sh
open Timely.app
```

Produces a universal `Timely.app` and a `Timely.zip` for distribution.

## Releasing

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist` and `version`
   in `Casks/timely.rb`.
2. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`. The GitHub
   Actions workflow builds the app and creates a release with `Timely.zip`.
3. Update the `sha256` in `Casks/timely.rb` from the workflow output (or run
   `shasum -a 256 Timely.zip` on the release asset), then copy the cask to the
   [`homebrew-tap`](https://github.com/nikhilweee/homebrew-tap) repo as
   `Casks/timely.rb` and push.

One-time setup: create the `nikhilweee/timely` and `nikhilweee/homebrew-tap`
repos on GitHub, then push this project to the former.
