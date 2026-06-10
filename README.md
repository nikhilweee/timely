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
