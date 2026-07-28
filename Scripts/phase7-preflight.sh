#!/usr/bin/env zsh
set -euo pipefail

# One-stop Phase 7 local-simulation acceptance entrypoint.
#
# This script intentionally stays inside local simulation. It does not
# install or launch DoraZoom, request TCC permissions, register login items,
# reset permissions, touch the real pasteboard, capture screen/audio/camera,
# control target apps, or write user output files.

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

function usage() {
    print "usage: Scripts/phase7-preflight.sh [--self-test]"
    print ""
    print "Runs local-simulation acceptance checks for Phase 7."
}

function print_local_simulation_result() {
    print ""
    print "Phase 7 local-simulation acceptance passed."
    print ""
    print "Evidence:"
    print "1. Delivery gate passed."
    print "2. ACCEPTANCE.md local-simulation record is complete."
    print "3. No real install, launch, TCC, pasteboard, capture, device or target-app workflow was executed."
}

function run_preflight() {
    print "==> Delivery gate"
    Scripts/verify-delivery.sh

    print ""
    print "==> Local-simulation acceptance record"
    Scripts/verify-acceptance-record.sh ACCEPTANCE.md

    print_local_simulation_result
}

function run_self_test() {
    local script_path="Scripts/phase7-preflight.sh"

    if ! rg -n 'Scripts/verify-delivery\.sh|Scripts/verify-acceptance-record\.sh ACCEPTANCE\.md|Phase 7 local-simulation acceptance passed' "$script_path" >/dev/null; then
        print "error: preflight script does not compose the required local-simulation checks" >&2
        return 2
    fi

    if ! rg -n 'does not[[:space:]]+install|request TCC|real pasteboard|capture screen/audio/camera|No real install' "$script_path" >/dev/null; then
        print "error: preflight script does not state the local-simulation boundary clearly" >&2
        return 2
    fi

    local old_manual_word="manual"
    local old_acceptance_word="acceptance"
    local old_steps_word="steps"
    local applications_word="Applications"
    local old_pattern="Next[[:space:]]+${old_manual_word}[[:space:]]+${old_steps_word}|${old_manual_word}[[:space:]]+${old_acceptance_word}|/${applications_word}.*manually"
    if rg -n "$old_pattern" "$script_path" >/dev/null; then
        print "error: preflight script still points at the old external acceptance flow" >&2
        return 2
    fi

    zsh -n "$script_path"
    print "PASS: phase 7 preflight self-test"
}

case "${1:-}" in
    --help|-h)
        usage
        ;;
    --self-test)
        run_self_test
        ;;
    "")
        run_preflight
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
