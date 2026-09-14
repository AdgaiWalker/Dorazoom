#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SKILL_DIR="$ROOT_DIR/.agents/skills/app-i18n-l10n"
CATALOG="$ROOT_DIR/Sources/ZoomItMacCore/Resources/Localizable.xcstrings"
RESOURCE_DIR="$ROOT_DIR/Sources/ZoomItMacCore/Resources"

locales=(zh-Hans zh-Hant ja ko de fr es-ES es-419 pt-BR)
metadata_files=(
    de-DE-app-store-metadata.md
    en-US-app-store-metadata.md
    es-ES-app-store-metadata.md
    es-MX-app-store-metadata.md
    fr-FR-app-store-metadata.md
    ja-app-store-metadata.md
    ko-app-store-metadata.md
    pt-BR-app-store-metadata.md
    zh-Hans-app-store-metadata.md
    zh-Hant-app-store-metadata.md
)

cd "$ROOT_DIR"

locale_arguments=()
audit_arguments=(--locale en)
for locale in $locales; do
    locale_arguments+=(--locale "$locale")
    audit_arguments+=(--locale "$locale")
done

python3 Scripts/build-localization-catalog.py $locale_arguments
python3 "$SKILL_DIR/scripts/audit_catalog.py" \
    --catalog "$CATALOG" \
    $audit_arguments
python3 "$SKILL_DIR/scripts/audit_runtime_l10n.py" \
    --source-dir Sources/ZoomItMacCore
python3 Scripts/audit-appkit-localization.py Sources/ZoomItMacCore

for locale in en $locales; do
    plutil -lint "$RESOURCE_DIR/$locale.lproj/InfoPlist.strings"
done
plutil -lint ZoomItInfo.plist

for metadata_file in $metadata_files; do
    python3 "$SKILL_DIR/scripts/validate_metadata.py" \
        --file "docs/app-store/metadata/$metadata_file"
done

swift test
git diff --check

print "PASS: DoraZoom localization catalog, metadata, resources, and tests"
