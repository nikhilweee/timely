#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Build a universal binary with full Xcode; Command Line Tools can only build native
if [[ "$(xcode-select -p)" != *CommandLineTools* ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN=.build/apple/Products/Release/Timely
else
    swift build -c release
    BIN=$(swift build -c release --show-bin-path)/Timely
fi

# Assemble the app bundle
rm -rf Timely.app Timely.zip
mkdir -p Timely.app/Contents/MacOS
cp "$BIN" Timely.app/Contents/MacOS/Timely
cp Resources/Info.plist Timely.app/Contents/Info.plist

# Ad-hoc sign and zip for distribution
codesign --force --sign - Timely.app
ditto -c -k --keepParent Timely.app Timely.zip

echo "Built Timely.app"
echo "sha256: $(shasum -a 256 Timely.zip | cut -d' ' -f1)"
