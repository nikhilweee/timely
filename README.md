# Timely

A minimal menu bar timer for macOS.

- Click the timer icon and pick an interval, or choose Custom… and type any
  duration (`25`, `90s`, `1:30`, `1h 10m`).
- While running, the menu bar shows a live countdown. Left-click restarts the
  current interval or pauses it; right-click shows a menu with Cancel and the
  intervals.
- When the timer finishes, the menu bar flashes. Click to restart the same
  interval, or to open the menu.
- Settings… configures the click behaviors and the interval list.

## Install

```sh
brew install --cask nikhilweee/tap/timely
```

Then launch Timely from /Applications. The app is ad-hoc signed (no Apple
Developer account); the cask clears the quarantine flag after install so
Gatekeeper doesn't block the first launch.

## Build from source

```sh
./build.sh
open Timely.app
```

Produces a universal `Timely.app` and a `Timely.zip` for distribution.
