#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

VERSION="${ZOOMIT_VERSION:-}"
SIGN_IDENTITY="${ZOOMIT_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${ZOOMIT_NOTARY_PROFILE:-}"
ARCHS="${ZOOMIT_ARCHS-}"
OUTPUT_DIR="${ZOOMIT_RELEASE_DIR:-$ROOT_DIR/.build/internal-release}"
APP_PATH="$OUTPUT_DIR/DoraZoom.app"
DMG_PATH="$OUTPUT_DIR/DoraZoom-$VERSION.dmg"
ZIP_PATH="$OUTPUT_DIR/DoraZoom-$VERSION.zip"

function fail() {
    print "error: $1" >&2
    exit 2
}

function first_developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: .*\)"$/\1/p' \
        | head -n 1
}

[[ -n "$VERSION" ]] || fail "ZOOMIT_VERSION is required, for example 0.1.0"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+(\.[0-9]+)?$' ]] || fail "ZOOMIT_VERSION must be dotted numeric, for example 0.1.0"

if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(first_developer_id_identity)"
fi
[[ -n "$SIGN_IDENTITY" ]] || fail "no Developer ID Application identity found; create one in the Apple Developer account and install it in this Mac keychain"
[[ "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]] || fail "ZOOMIT_SIGN_IDENTITY must be a Developer ID Application identity, not '$SIGN_IDENTITY'"

[[ -n "$NOTARY_PROFILE" ]] || fail "ZOOMIT_NOTARY_PROFILE is required; create a notarytool keychain profile first"
command -v xcrun >/dev/null || fail "xcrun is required"
command -v hdiutil >/dev/null || fail "hdiutil is required"
command -v codesign >/dev/null || fail "codesign is required"
command -v spctl >/dev/null || fail "spctl is required"

mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_PATH" "$DMG_PATH" "$ZIP_PATH"

BUILD_ARCH_ENV=()
if [[ -n "$ARCHS" ]]; then
    BUILD_ARCH_ENV=(ZOOMIT_ARCHS="$ARCHS")
fi

print "==> Build Developer ID app"
env \
    ZOOMIT_VERSION="$VERSION" \
    ZOOMIT_REQUIRE_RELEASE_VERSION=true \
    ZOOMIT_SIGN_IDENTITY="$SIGN_IDENTITY" \
    ZOOMIT_BUNDLE_ID='com.duola.dorazoom' \
    ZOOMIT_DISPLAY_NAME='DoraZoom' \
    ZOOMIT_APP_NAME='DoraZoom.app' \
    "${BUILD_ARCH_ENV[@]}" \
    Scripts/build-app.sh release
mv "$ROOT_DIR/.build/DoraZoom.app" "$APP_PATH"

print "==> Verify signature before notarization"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | rg 'Identifier=com\.duola\.dorazoom|Runtime Version=|TeamIdentifier=' >/dev/null \
    || fail "the release app signature metadata is not a valid hardened Developer ID signature"

print "==> Create pre-notarization zip"
ditto --norsrc -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

print "==> Submit app zip for notarization"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

print "==> Staple notarization ticket"
xcrun stapler staple "$APP_PATH"

print "==> Recreate distributable zip with stapled app"
rm -f "$ZIP_PATH"
ditto --norsrc -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

print "==> Create DMG"
hdiutil create -volname "DoraZoom $VERSION" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH" >/dev/null

print "==> Submit DMG for notarization"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

print "==> Staple DMG notarization ticket"
xcrun stapler staple "$DMG_PATH"

print "==> Verify Gatekeeper assessment"
xcrun stapler validate "$APP_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

print ""
print "Internal release ready:"
print "  app: $APP_PATH"
print "  dmg: $DMG_PATH"
print "  zip: $ZIP_PATH"
print "  version: $VERSION"
print "  identity: $SIGN_IDENTITY"
