#!/bin/zsh
set -euo pipefail

# Fail the release if the App Store binary still contains the code paths the
# store flavor is supposed to compile out. Control+V compatibility is an
# intentional store capability and is checked as present below.
#
# This gate exists because the compile-time switch behind those exclusions is
# easy to lose silently. Xcode does NOT forward the app target's
# `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to SwiftPM package targets, so for a long
# time `DORAZOOM_APP_STORE` was simply never defined while every `#if` block in
# `Sources/ZoomItMacCore` looked correct. `Package.swift` now defines the
# condition from the environment, and this script verifies the resulting binary
# instead of trusting the configuration.
#
# Usage: verify-store-build.sh [path/to/DoraZoom.app]

ROOT_DIR="${0:A:h:h}"
APP_PATH="${1:-$ROOT_DIR/.build/DoraZoom.app}"
BINARY="$APP_PATH/Contents/MacOS/DoraZoom"

if [[ ! -x "$BINARY" ]]; then
    echo "error: no executable at $BINARY" >&2
    exit 2
fi

# Absent in store builds. Each one is referenced from store-excluded code, so if
# the condition had not been applied the linker would have kept the type.
FORBIDDEN_SYMBOLS=(
    "DemoTypeController"
    "AppControllerC13startDemoType"
)

# Present in any real build. Release archives may strip the normal symbol table,
# so use the binary's Swift reflection/source metadata for these identity checks
# instead of requiring nm to expose every type.
REQUIRED_SYMBOLS=(
    "AppDelegate"
    "ModeCoordinator"
    "SystemPasteCompatibilityEventTap"
    "ControlVPasteHotkeyService"
)

binary_strings="$(strings "$BINARY" 2>/dev/null || true)"
if [[ -z "$binary_strings" ]]; then
    echo "error: could not inspect $BINARY" >&2
    exit 2
fi

failed=0

for symbol in "${FORBIDDEN_SYMBOLS[@]}"; do
    count="$(printf '%s\n' "$binary_strings" | grep -Fxc "$symbol" || true)"
    if (( count > 0 )); then
        echo "FAIL: store binary still contains $symbol ($count symbols)" >&2
        failed=1
    else
        echo "ok:   $symbol absent"
    fi
done

for symbol in "${REQUIRED_SYMBOLS[@]}"; do
    count="$(printf '%s\n' "$binary_strings" | grep -Fxc "$symbol" || true)"
    if (( count == 0 )); then
        echo "FAIL: expected $symbol in the store binary; is this a real app build?" >&2
        failed=1
    else
        echo "ok:   $symbol present"
    fi
done

if (( failed != 0 )); then
    echo "" >&2
    echo "The App Store binary does not match the store capability set." >&2
    echo "Most likely cause: the archive was built without DORAZOOM_APP_STORE in the" >&2
    echo "environment, or Xcode reused a package build from the full flavor. Rebuild" >&2
    echo "with a clean store derived-data path via Scripts/build-app-store.sh." >&2
    exit 1
fi

echo "Store capability check passed: $BINARY"
