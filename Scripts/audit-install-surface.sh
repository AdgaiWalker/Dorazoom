#!/usr/bin/env zsh
set -euo pipefail

# Read-only manual Phase 7 install-surface auditor.
#
# The default run inspects explicit candidate app paths that can confuse TCC
# and manual authorization. It never deletes, overwrites, launches, installs,
# quits apps, resets TCC, registers login items, touches pasteboard, captures
# screen/audio/camera, or writes user output files.

EXPECTED_DAILY_BUNDLE_ID="com.duola.dorazoom"
EXPECTED_DEV_BUNDLE_ID="com.duola.dorazoom.dev"
EXPECTED_EXECUTABLE="DoraZoom"

DEFAULT_CANDIDATES=(
    "/Applications/DoraZoom.app"
    "/Applications/DoraZoom Dev.app"
    "/Applications/DoraZoom (Dev).app"
    "/Applications/ZoomIt.app"
    "/Applications/ZoomIt Dev.app"
)

function usage() {
    print "usage: Scripts/audit-install-surface.sh [--root DIR] [APP ...]"
    print "       Scripts/audit-install-surface.sh --self-test"
    print ""
    print "Default APP candidates are read-only checks under /Applications."
}

function plist_value() {
    local plist_path="$1"
    local key="$2"
    /usr/bin/plutil -extract "$key" raw "$plist_path" 2>/dev/null || true
}

function app_status() {
    local app_path="$1"
    local app_name="${app_path:t}"
    local plist_path="$app_path/Contents/Info.plist"

    if [[ ! -d "$app_path" ]]; then
        print "missing|$app_path|not installed"
        return 0
    fi

    if [[ ! -f "$plist_path" ]]; then
        print "conflict|$app_path|missing Info.plist"
        return 0
    fi

    local bundle_id
    local executable
    local display_name
    bundle_id="$(plist_value "$plist_path" CFBundleIdentifier)"
    executable="$(plist_value "$plist_path" CFBundleExecutable)"
    display_name="$(plist_value "$plist_path" CFBundleDisplayName)"
    if [[ -z "$display_name" ]]; then
        display_name="$(plist_value "$plist_path" CFBundleName)"
    fi

    if [[ "$app_name" == "DoraZoom.app" && "$bundle_id" == "$EXPECTED_DAILY_BUNDLE_ID" && "$executable" == "$EXPECTED_EXECUTABLE" ]]; then
        print "ok|$app_path|daily DoraZoom install surface: bundle=$bundle_id executable=$executable display=${display_name:-unknown}"
        return 0
    fi

    if [[ "$app_name" == "DoraZoom Dev.app" && "$bundle_id" == "$EXPECTED_DEV_BUNDLE_ID" && "$executable" == "$EXPECTED_EXECUTABLE" ]]; then
        print "ok|$app_path|dev DoraZoom install surface: bundle=$bundle_id executable=$executable display=${display_name:-unknown}"
        return 0
    fi

    if [[ "$app_name" == ZoomIt*.app ]]; then
        print "conflict|$app_path|old ZoomIt-named app may own stale permissions: bundle=${bundle_id:-unknown} executable=${executable:-unknown} display=${display_name:-unknown}"
        return 0
    fi

    if [[ "$app_name" == "DoraZoom (Dev).app" ]]; then
        print "conflict|$app_path|stale DoraZoom dev name; expected 'DoraZoom Dev.app': bundle=${bundle_id:-unknown} executable=${executable:-unknown} display=${display_name:-unknown}"
        return 0
    fi

    print "conflict|$app_path|unexpected DoraZoom install surface: bundle=${bundle_id:-unknown} executable=${executable:-unknown} display=${display_name:-unknown}"
}

function audit_paths() {
    local found_conflict=0
    local checked=0
    local app_path
    local status_line
    local status_kind
    local status_path
    local status_detail

    for app_path in "$@"; do
        checked=$((checked + 1))
        status_line="$(app_status "$app_path")"
        status_kind="${status_line%%|*}"
        status_path="${status_line#*|}"
        status_path="${status_path%%|*}"
        status_detail="${status_line#*|*|}"

        case "$status_kind" in
            ok)
                print "OK: $status_path — $status_detail"
                ;;
            missing)
                print "MISSING: $status_path — $status_detail"
                ;;
            conflict)
                found_conflict=1
                print "CONFLICT: $status_path — $status_detail" >&2
                ;;
            *)
                found_conflict=1
                print "CONFLICT: $app_path — unrecognized audit result: $status_line" >&2
                ;;
        esac
    done

    if [[ "$checked" == "0" ]]; then
        print "error: no install surface candidates supplied" >&2
        return 2
    fi

    if [[ "$found_conflict" == "1" ]]; then
        print "Install surface audit found conflicts. Stop before Phase 7 authorization and decide manually; this script did not modify anything." >&2
        return 2
    fi

    print "PASS: install surface audit found no conflicting explicit candidates"
}

function write_fixture_app() {
    local app_path="$1"
    local bundle_id="$2"
    local executable="$3"
    local display_name="$4"
    mkdir -p "$app_path/Contents/MacOS"
    {
        print '<?xml version="1.0" encoding="UTF-8"?>'
        print '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        print '<plist version="1.0">'
        print '<dict>'
        print '  <key>CFBundleIdentifier</key>'
        print "  <string>$bundle_id</string>"
        print '  <key>CFBundleExecutable</key>'
        print "  <string>$executable</string>"
        print '  <key>CFBundleDisplayName</key>'
        print "  <string>$display_name</string>"
        print '</dict>'
        print '</plist>'
    } > "$app_path/Contents/Info.plist"
}

function run_self_test() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    INSTALL_SURFACE_SELF_TEST_TEMP_DIR="$temp_dir"
    trap 'rm -rf "${INSTALL_SURFACE_SELF_TEST_TEMP_DIR:-}"' EXIT

    local apps_dir="$temp_dir/Applications"
    mkdir -p "$apps_dir"

    write_fixture_app "$apps_dir/DoraZoom.app" "$EXPECTED_DAILY_BUNDLE_ID" "$EXPECTED_EXECUTABLE" "DoraZoom"
    write_fixture_app "$apps_dir/ZoomIt.app" "com.sysinternals.ZoomIt" "ZoomIt" "ZoomIt"
    write_fixture_app "$apps_dir/DoraZoom (Dev).app" "$EXPECTED_DEV_BUNDLE_ID" "$EXPECTED_EXECUTABLE" "DoraZoom (Dev)"

    audit_paths "$apps_dir/DoraZoom.app" "$apps_dir/Missing.app" >/dev/null

    local conflict_output
    local conflict_status=0
    conflict_output="$(audit_paths "$apps_dir/DoraZoom.app" "$apps_dir/ZoomIt.app" "$apps_dir/DoraZoom (Dev).app" 2>&1)" || conflict_status=$?

    if [[ "$conflict_status" != "2" ]]; then
        print "error: self-test expected stale install surfaces to fail with status 2, got $conflict_status" >&2
        print "$conflict_output" >&2
        return 2
    fi

    if ! print -r -- "$conflict_output" | rg 'old ZoomIt-named app|stale DoraZoom dev name' >/dev/null; then
        print "error: self-test conflict output did not identify stale install surfaces" >&2
        print "$conflict_output" >&2
        return 2
    fi

    print "PASS: install surface auditor self-test"
}

function candidates_with_root() {
    local root_dir="$1"
    local candidate
    for candidate in "${DEFAULT_CANDIDATES[@]}"; do
        print -r -- "$root_dir/${candidate#/Applications/}"
    done
}

case "${1:-}" in
    --help|-h)
        usage
        ;;
    --self-test)
        run_self_test
        ;;
    --root)
        if [[ -z "${2:-}" ]]; then
            print "error: --root requires a directory" >&2
            exit 2
        fi
        shift
        root_dir="$1"
        shift
        if [[ "$#" == "0" ]]; then
            mapfile -t rooted_candidates < <(candidates_with_root "$root_dir")
            audit_paths "${rooted_candidates[@]}"
        else
            audit_paths "$@"
        fi
        ;;
    "")
        audit_paths "${DEFAULT_CANDIDATES[@]}"
        ;;
    *)
        audit_paths "$@"
        ;;
esac
