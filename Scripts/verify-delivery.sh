#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

DEV_APP="$ROOT_DIR/.build/DoraZoom Dev.app"
DAILY_APP="$ROOT_DIR/.build/DoraZoom.app"
DAILY_ZIP="$ROOT_DIR/.build/DoraZoom.zip"
STALE_ZOOMIT_ZIP="$ROOT_DIR/.build/ZoomIt.zip"
ALLOWED_ROOT_APP_NAMES=(
    "DoraZoom Dev.app"
    "DoraZoom.app"
)
APP_EXECUTABLE_NAME="DoraZoom"
APP_ICON_FILE_NAME="DoraZoom"
ARCHS="${ZOOMIT_ARCHS-}"
EXPECTED_ARCHS="${ARCHS:-arm64}"
EXPECTED_VERSION="${ZOOMIT_VERSION:-1.0}"
BUILD_ARCH_ENV=()
if [[ -n "$ARCHS" ]]; then
    BUILD_ARCH_ENV=(ZOOMIT_ARCHS="$ARCHS")
fi

function section() {
    print "\n==> $1"
}

function assert_equal() {
    local actual="$1"
    local expected="$2"
    local label="$3"
    if [[ "$actual" != "$expected" ]]; then
        print "error: $label expected '$expected', got '$actual'" >&2
        exit 2
    fi
}

function assert_contains() {
    local actual="$1"
    local expected_fragment="$2"
    local label="$3"
    if [[ "$actual" != *"$expected_fragment"* ]]; then
        print "error: $label expected to contain '$expected_fragment', got '$actual'" >&2
        exit 2
    fi
}

function assert_not_contains() {
    local actual="$1"
    local rejected_fragment="$2"
    local label="$3"
    if [[ "$actual" == *"$rejected_fragment"* ]]; then
        print "error: $label must not contain '$rejected_fragment'" >&2
        exit 2
    fi
}

function assert_matches() {
    local actual="$1"
    local expected_pattern="$2"
    local label="$3"
    if ! print "$actual" | rg "$expected_pattern" >/dev/null; then
        print "error: $label expected to match '$expected_pattern', got '$actual'" >&2
        exit 2
    fi
}

function assert_no_quarantine_xattr() {
    local checked_path="$1"
    local label="$2"
    if xattr -lr "$checked_path" 2>/dev/null | rg 'com\.apple\.quarantine' >/dev/null; then
        print "error: $label must not carry com.apple.quarantine before distribution" >&2
        exit 2
    fi
}

function is_allowed_root_app_name() {
    local candidate="$1"
    local allowed
    for allowed in "${ALLOWED_ROOT_APP_NAMES[@]}"; do
        if [[ "$candidate" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

function assert_root_app_artifacts_are_allowlisted() {
    local app_path
    local app_name
    [[ -d "$ROOT_DIR/.build" ]] || return 0
    while IFS= read -r -d '' app_path; do
        app_name="${app_path:t}"
        if ! is_allowed_root_app_name "$app_name"; then
            print "error: root .build app artifact is not an accepted DoraZoom delivery target: $app_path" >&2
            print "accepted root app artifacts: ${ALLOWED_ROOT_APP_NAMES[*]}" >&2
            exit 2
        fi
    done < <(find "$ROOT_DIR/.build" -maxdepth 1 -type d -name '*.app' -print0)
}

function normalize_archs() {
    print -r -- "$1" | tr ' ' '\n' | sed '/^$/d' | sort | paste -sd ' ' -
}

function first_codesigning_identity() {
    security find-identity -v -p codesigning 2>/dev/null | awk '/[A-F0-9]{40}/ {print $2; exit}'
}

EXPECTED_ARCHS_NORMALIZED="$(normalize_archs "$EXPECTED_ARCHS")"

section "Automated test boundary audit"
Scripts/verify-test-boundary.sh

section "Acceptance record verifier self-test"
Scripts/verify-acceptance-record.sh --self-test

section "Acceptance draft generator self-test"
Scripts/phase7-acceptance-draft.sh --self-test

section "Install surface auditor self-test"
Scripts/audit-install-surface.sh --self-test

section "Phase 7 preflight self-test"
Scripts/phase7-preflight.sh --self-test

section "Root app artifact allowlist audit"
assert_root_app_artifacts_are_allowlisted

section "Manual reset helper safety audit"
set +e
RESET_GUARD_OUTPUT="$(Scripts/reset-first-run.sh --no-launch 2>&1)"
RESET_GUARD_STATUS=$?
DAILY_RESET_GUARD_OUTPUT="$(ZOOMIT_ALLOW_TCC_RESET=I_UNDERSTAND_THIS_RESETS_LOCAL_DORAZOOM_PERMISSIONS ZOOMIT_BUNDLE_ID=com.duola.dorazoom Scripts/reset-first-run.sh --no-launch 2>&1)"
DAILY_RESET_GUARD_STATUS=$?
set -e
assert_equal "$RESET_GUARD_STATUS" "2" "manual reset helper unconfirmed status"
assert_contains "$RESET_GUARD_OUTPUT" "ZOOMIT_ALLOW_TCC_RESET" "manual reset helper unconfirmed guard"
assert_equal "$DAILY_RESET_GUARD_STATUS" "2" "daily reset helper unconfirmed status"
assert_contains "$DAILY_RESET_GUARD_OUTPUT" "ZOOMIT_ALLOW_DAILY_RESET" "daily reset helper guard"

section "Swift build"
swift build

section "Swift tests"
swift test

section "Self-test"
.build/debug/ZoomItMacSelfTest

section "Dependency audit"
DEPS="$(swift package show-dependencies --format text)"
print "$DEPS"
assert_equal "$DEPS" "No external dependencies found" "SwiftPM dependencies"

section "Build dev app"
env \
    ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' \
    ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' \
    "${BUILD_ARCH_ENV[@]}" \
    Scripts/build-app.sh debug

section "Build daily release app"
SIGN_IDENTITY="${ZOOMIT_SIGN_IDENTITY:-$(first_codesigning_identity)}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    print "error: no local codesigning identity found for daily release build." >&2
    exit 2
fi

env \
    ZOOMIT_SIGN_IDENTITY="$SIGN_IDENTITY" \
    ZOOMIT_BUNDLE_ID='com.duola.dorazoom' \
    ZOOMIT_DISPLAY_NAME='DoraZoom' \
    ZOOMIT_APP_NAME='DoraZoom.app' \
    "${BUILD_ARCH_ENV[@]}" \
    ZOOMIT_REQUIRE_RELEASE_VERSION='true' \
    Scripts/build-app.sh release

section "Bundle identity audit"
assert_root_app_artifacts_are_allowlisted
assert_equal "$(plutil -extract CFBundleIdentifier raw "$DEV_APP/Contents/Info.plist")" "com.duola.dorazoom.dev" "dev bundle id"
assert_equal "$(plutil -extract CFBundleName raw "$DEV_APP/Contents/Info.plist")" "DoraZoom (Dev)" "dev bundle name"
assert_equal "$(plutil -extract CFBundleDisplayName raw "$DEV_APP/Contents/Info.plist")" "DoraZoom (Dev)" "dev display name"
assert_equal "$(plutil -extract CFBundleExecutable raw "$DEV_APP/Contents/Info.plist")" "$APP_EXECUTABLE_NAME" "dev executable name"
assert_equal "$(plutil -extract CFBundleIconFile raw "$DEV_APP/Contents/Info.plist")" "$APP_ICON_FILE_NAME" "dev icon file"
assert_equal "$(plutil -extract CFBundleShortVersionString raw "$DEV_APP/Contents/Info.plist")" "$EXPECTED_VERSION" "dev short version"
assert_equal "$(plutil -extract CFBundleVersion raw "$DEV_APP/Contents/Info.plist")" "$EXPECTED_VERSION" "dev build version"
assert_equal "$(plutil -extract LSUIElement raw "$DEV_APP/Contents/Info.plist")" "true" "dev menu-bar accessory mode"
assert_equal "$(plutil -extract LSMinimumSystemVersion raw "$DEV_APP/Contents/Info.plist")" "14.0" "dev minimum macOS version"
assert_contains "$(plutil -extract NSCameraUsageDescription raw "$DEV_APP/Contents/Info.plist")" "DoraZoom" "dev camera usage description"
assert_contains "$(plutil -extract NSMicrophoneUsageDescription raw "$DEV_APP/Contents/Info.plist")" "DoraZoom" "dev microphone usage description"
assert_equal "$(plutil -extract CFBundleIdentifier raw "$DAILY_APP/Contents/Info.plist")" "com.duola.dorazoom" "daily bundle id"
assert_equal "$(plutil -extract CFBundleName raw "$DAILY_APP/Contents/Info.plist")" "DoraZoom" "daily bundle name"
assert_equal "$(plutil -extract CFBundleDisplayName raw "$DAILY_APP/Contents/Info.plist")" "DoraZoom" "daily display name"
assert_equal "$(plutil -extract CFBundleExecutable raw "$DAILY_APP/Contents/Info.plist")" "$APP_EXECUTABLE_NAME" "daily executable name"
assert_equal "$(plutil -extract CFBundleIconFile raw "$DAILY_APP/Contents/Info.plist")" "$APP_ICON_FILE_NAME" "daily icon file"
assert_equal "$(plutil -extract CFBundleShortVersionString raw "$DAILY_APP/Contents/Info.plist")" "$EXPECTED_VERSION" "daily short version"
assert_equal "$(plutil -extract CFBundleVersion raw "$DAILY_APP/Contents/Info.plist")" "$EXPECTED_VERSION" "daily build version"
assert_equal "$(plutil -extract LSUIElement raw "$DAILY_APP/Contents/Info.plist")" "true" "daily menu-bar accessory mode"
assert_equal "$(plutil -extract LSMinimumSystemVersion raw "$DAILY_APP/Contents/Info.plist")" "14.0" "daily minimum macOS version"
assert_contains "$(plutil -extract NSCameraUsageDescription raw "$DAILY_APP/Contents/Info.plist")" "DoraZoom" "daily camera usage description"
assert_contains "$(plutil -extract NSMicrophoneUsageDescription raw "$DAILY_APP/Contents/Info.plist")" "DoraZoom" "daily microphone usage description"
[[ -x "$DEV_APP/Contents/MacOS/$APP_EXECUTABLE_NAME" ]]
[[ -x "$DAILY_APP/Contents/MacOS/$APP_EXECUTABLE_NAME" ]]
[[ ! -e "$DEV_APP/Contents/MacOS/ZoomIt" ]]
[[ ! -e "$DAILY_APP/Contents/MacOS/ZoomIt" ]]
[[ -f "$DEV_APP/Contents/Resources/$APP_ICON_FILE_NAME.icns" ]]
[[ -f "$DAILY_APP/Contents/Resources/$APP_ICON_FILE_NAME.icns" ]]
[[ ! -e "$DEV_APP/Contents/Resources/ZoomIt.icns" ]]
[[ ! -e "$DAILY_APP/Contents/Resources/ZoomIt.icns" ]]
if find "$DEV_APP/Contents/Resources" "$DAILY_APP/Contents/Resources" -maxdepth 1 -type f -name 'ZoomIt*.png' | rg . >/dev/null; then
    print "error: packaged icon resources must use DoraZoom filenames" >&2
    exit 2
fi

section "Codesign audit"
codesign --verify --deep --strict --verbose=2 "$DEV_APP"
codesign --verify --deep --strict --verbose=2 "$DAILY_APP"
DEV_CODESIGN_DETAILS="$(codesign -dv --verbose=4 "$DEV_APP" 2>&1)"
assert_contains "$DEV_CODESIGN_DETAILS" "Identifier=com.duola.dorazoom.dev" "dev codesign identifier"
assert_contains "$DEV_CODESIGN_DETAILS" "Signature=adhoc" "dev codesign ad-hoc signature"
assert_contains "$DEV_CODESIGN_DETAILS" "TeamIdentifier=not set" "dev codesign team identifier"
DAILY_CODESIGN_DETAILS="$(codesign -dv --verbose=4 "$DAILY_APP" 2>&1)"
print "$DAILY_CODESIGN_DETAILS" | rg 'Identifier=|Authority=|TeamIdentifier='
assert_contains "$DAILY_CODESIGN_DETAILS" "Identifier=com.duola.dorazoom" "daily codesign identifier"
assert_matches "$DAILY_CODESIGN_DETAILS" '^Authority=.+$' "daily codesign authority"
assert_matches "$DAILY_CODESIGN_DETAILS" '^TeamIdentifier=[A-Z0-9]+$' "daily codesign team identifier"
assert_contains "$DAILY_CODESIGN_DETAILS" "Runtime Version=" "daily hardened runtime"
DEV_ENTITLEMENTS="$(codesign -d --entitlements - --xml "$DEV_APP" 2>/dev/null)"
DAILY_ENTITLEMENTS="$(codesign -d --entitlements - --xml "$DAILY_APP" 2>/dev/null)"
print "$DEV_ENTITLEMENTS" | rg 'com.apple.security.device.audio-input' >/dev/null
print "$DEV_ENTITLEMENTS" | rg 'com.apple.security.device.camera' >/dev/null
assert_not_contains "$DEV_ENTITLEMENTS" "com.apple.security.app-sandbox" "dev entitlements"
print "$DAILY_ENTITLEMENTS" | rg 'com.apple.security.device.audio-input' >/dev/null
print "$DAILY_ENTITLEMENTS" | rg 'com.apple.security.device.camera' >/dev/null
assert_not_contains "$DAILY_ENTITLEMENTS" "com.apple.security.app-sandbox" "daily entitlements"

section "Package daily zip"
if [[ -e "$STALE_ZOOMIT_ZIP" ]]; then
    print "error: stale ZoomIt.zip artifact must be removed before DoraZoom delivery verification" >&2
    exit 2
fi
assert_no_quarantine_xattr "$DAILY_APP" "daily app bundle"
ditto --norsrc -c -k --keepParent "$DAILY_APP" "$DAILY_ZIP"
if [[ -e "$STALE_ZOOMIT_ZIP" ]]; then
    print "error: stale ZoomIt.zip artifact must not be produced during DoraZoom delivery verification" >&2
    exit 2
fi
assert_no_quarantine_xattr "$DAILY_ZIP" "daily zip"
ZIP_ENTRIES="$(zipinfo -1 "$DAILY_ZIP")"
if print "$ZIP_ENTRIES" | rg '(^|/)\._|^__MACOSX/' >/dev/null; then
    print "error: daily zip contains AppleDouble/resource-fork metadata" >&2
    exit 2
fi
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ditto -x -k "$DAILY_ZIP" "$TMP_DIR"
ZIP_APP_COUNT="$(find "$TMP_DIR" -maxdepth 1 -name '*.app' -type d | wc -l | tr -d ' ')"
assert_equal "$ZIP_APP_COUNT" "1" "zip top-level app count"
[[ -d "$TMP_DIR/DoraZoom.app" ]]
[[ ! -e "$TMP_DIR/ZoomIt.app" ]]
assert_no_quarantine_xattr "$TMP_DIR/DoraZoom.app" "extracted daily app bundle"
if find "$TMP_DIR/DoraZoom.app/Contents/Resources" -maxdepth 1 -type f -name 'ZoomIt*.png' | rg . >/dev/null; then
    print "error: extracted icon resources must use DoraZoom filenames" >&2
    exit 2
fi
assert_equal "$(plutil -extract CFBundleIdentifier raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "com.duola.dorazoom" "extracted daily bundle id"
assert_equal "$(plutil -extract CFBundleName raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "DoraZoom" "extracted daily bundle name"
assert_equal "$(plutil -extract CFBundleDisplayName raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "DoraZoom" "extracted daily display name"
assert_equal "$(plutil -extract CFBundleExecutable raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "$APP_EXECUTABLE_NAME" "extracted daily executable name"
assert_equal "$(plutil -extract CFBundleIconFile raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "$APP_ICON_FILE_NAME" "extracted daily icon file"
assert_equal "$(plutil -extract CFBundleShortVersionString raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "$EXPECTED_VERSION" "extracted daily short version"
assert_equal "$(plutil -extract CFBundleVersion raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "$EXPECTED_VERSION" "extracted daily build version"
assert_equal "$(plutil -extract LSUIElement raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "true" "extracted daily menu-bar accessory mode"
assert_equal "$(plutil -extract LSMinimumSystemVersion raw "$TMP_DIR/DoraZoom.app/Contents/Info.plist")" "14.0" "extracted daily minimum macOS version"
EXTRACTED_DAILY_ARCHS="$(lipo -archs "$TMP_DIR/DoraZoom.app/Contents/MacOS/$APP_EXECUTABLE_NAME" 2>/dev/null || echo unknown)"
assert_equal "$(normalize_archs "$EXTRACTED_DAILY_ARCHS")" "$EXPECTED_ARCHS_NORMALIZED" "normalized extracted daily architectures"
EXTRACTED_DAILY_ENTITLEMENTS="$(codesign -d --entitlements - --xml "$TMP_DIR/DoraZoom.app" 2>/dev/null)"
print "$EXTRACTED_DAILY_ENTITLEMENTS" | rg 'com.apple.security.device.audio-input' >/dev/null
print "$EXTRACTED_DAILY_ENTITLEMENTS" | rg 'com.apple.security.device.camera' >/dev/null
assert_not_contains "$EXTRACTED_DAILY_ENTITLEMENTS" "com.apple.security.app-sandbox" "extracted daily entitlements"
EXTRACTED_DAILY_CODESIGN_DETAILS="$(codesign -dv --verbose=4 "$TMP_DIR/DoraZoom.app" 2>&1)"
assert_contains "$EXTRACTED_DAILY_CODESIGN_DETAILS" "Identifier=com.duola.dorazoom" "extracted daily codesign identifier"
assert_matches "$EXTRACTED_DAILY_CODESIGN_DETAILS" '^Authority=.+$' "extracted daily codesign authority"
assert_matches "$EXTRACTED_DAILY_CODESIGN_DETAILS" '^TeamIdentifier=[A-Z0-9]+$' "extracted daily codesign team identifier"
assert_contains "$EXTRACTED_DAILY_CODESIGN_DETAILS" "Runtime Version=" "extracted daily hardened runtime"
codesign --verify --deep --strict --verbose=2 "$TMP_DIR/DoraZoom.app"

section "Size snapshot"
SOURCE_FILE_COUNT="$(find . -path './.git' -prune -o -path './.build' -prune -o -path './website' -prune -o -type f -print | wc -l | tr -d ' ')"
SOURCE_BYTES="$(find . -path './.git' -prune -o -path './.build' -prune -o -path './website' -prune -o -type f -print0 | xargs -0 stat -f %z | awk '{s+=$1} END {print s}')"
SWIFT_LINES="$(find Sources -name '*.swift' -type f -print0 | xargs -0 wc -l | tail -n 1 | awk '{print $1}')"
DEV_SIZE="$(du -sh "$DEV_APP" | awk '{print $1}')"
DAILY_SIZE="$(du -sh "$DAILY_APP" | awk '{print $1}')"
ZIP_SIZE="$(ls -lh "$DAILY_ZIP" | awk '{print $5}')"
DEV_ARCHS="$(lipo -archs "$DEV_APP/Contents/MacOS/$APP_EXECUTABLE_NAME" 2>/dev/null || echo unknown)"
DAILY_ARCHS="$(lipo -archs "$DAILY_APP/Contents/MacOS/$APP_EXECUTABLE_NAME" 2>/dev/null || echo unknown)"
assert_equal "$(normalize_archs "$DEV_ARCHS")" "$EXPECTED_ARCHS_NORMALIZED" "normalized dev architectures"
assert_equal "$(normalize_archs "$DAILY_ARCHS")" "$EXPECTED_ARCHS_NORMALIZED" "normalized daily architectures"

print "source files: $SOURCE_FILE_COUNT"
print "source bytes: $SOURCE_BYTES"
print "swift lines:  $SWIFT_LINES"
print "dev app:      $DEV_SIZE"
print "daily app:    $DAILY_SIZE"
print "daily zip:    $ZIP_SIZE"
print "dev archs:    $DEV_ARCHS"
print "daily archs:  $DAILY_ARCHS"

section "Whitespace diff audit"
git diff --check

section "Delivery verification complete"
print "PASS"
