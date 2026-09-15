#!/bin/zsh
set -euo pipefail

# Build and package the Mac App Store flavor. This creates the signed .app and
# installer .pkg consumed by App Store Connect; it does not upload or submit
# the app for review.
#
# DORAZOOM_APP_STORE must be exported for the archive. Xcode does not forward
# the app target's SWIFT_ACTIVE_COMPILATION_CONDITIONS to package targets, so
# `Package.swift` reads this variable and defines the condition on
# `ZoomItMacCore`. The archive is then checked by `verify-store-build.sh`.
ROOT_DIR="${0:A:h:h}"
APP_SIGN_IDENTITY="${ZOOMIT_STORE_APP_SIGN_IDENTITY:-3rd Party Mac Developer Application: cong ni (26GG8J688T)}"
INSTALLER_SIGN_IDENTITY="${ZOOMIT_STORE_INSTALLER_SIGN_IDENTITY:-3rd Party Mac Developer Installer: cong ni (26GG8J688T)}"
VERSION="${ZOOMIT_VERSION:-1.0.0}"
BUILD_NUMBER="${ZOOMIT_BUILD_NUMBER:-4.0.1}"
APP_PATH="$ROOT_DIR/.build/DoraZoom.app"
PKG_PATH="${ZOOMIT_STORE_PKG_PATH:-$ROOT_DIR/.build/DoraZoom-${VERSION}-${BUILD_NUMBER}.pkg}"
# A dedicated derived-data path keeps the store flavor away from whatever
# Xcode GUI builds leave in the default location.
DERIVED_DATA="${ZOOMIT_STORE_DERIVED_DATA:-$ROOT_DIR/.build/DoraZoomStoreDerivedData}"

export DORAZOOM_APP_STORE=1

cd "$ROOT_DIR"

if ! security find-identity -v -p codesigning 2>/dev/null | rg -F "$APP_SIGN_IDENTITY" >/dev/null; then
    echo "error: Mac App Store application signing identity not found: $APP_SIGN_IDENTITY" >&2
    exit 2
fi
if ! security find-identity -v 2>/dev/null | rg -F "$INSTALLER_SIGN_IDENTITY" >/dev/null; then
    echo "error: Mac App Store installer signing identity not found: $INSTALLER_SIGN_IDENTITY" >&2
    exit 2
fi

ARCHIVE_PATH="${ZOOMIT_STORE_ARCHIVE_PATH:-$ROOT_DIR/.build/DoraZoom-${VERSION}-${BUILD_NUMBER}.xcarchive}"
EXPORT_DIR="${ZOOMIT_STORE_EXPORT_DIR:-$ROOT_DIR/.build/DoraZoom-${VERSION}-${BUILD_NUMBER}-export}"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
xcodebuild \
    -project "$ROOT_DIR/AppStore/DoraZoomStore.xcodeproj" \
    -scheme DoraZoomStore \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    archive

codesign --verify --deep --strict "$ARCHIVE_PATH/Products/Applications/DoraZoom.app"
codesign -d --entitlements - --xml "$ARCHIVE_PATH/Products/Applications/DoraZoom.app" >/dev/null

# Refuse to export a store package that still carries the full-flavor code.
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/DoraZoom.app"
"$ROOT_DIR/Scripts/verify-store-build.sh" "$ARCHIVED_APP"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$ROOT_DIR/AppStore/export-options.plist"

EXPORTED_PKG="$(find "$EXPORT_DIR" -maxdepth 1 -type f -name '*.pkg' -print -quit)"
if [[ -z "$EXPORTED_PKG" ]]; then
    echo "error: Xcode export did not produce an App Store package." >&2
    exit 2
fi
mkdir -p "${PKG_PATH:h}"
cp "$EXPORTED_PKG" "$PKG_PATH"

echo "Built Mac App Store archive: $ARCHIVE_PATH"
echo "Built Mac App Store package: $PKG_PATH"
