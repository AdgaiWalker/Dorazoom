#!/bin/zsh
# Resets DoraZoom to a clean "first run" state for explicit, manual testing of
# the onboarding and permission-prompt experience.
#
# It quits any running bundle, clears the app's privacy permissions (Screen
# Recording, Microphone, Camera) so the system prompts appear as they would for
# a new user, and optionally wipes the saved settings so hotkeys and other
# preferences return to their defaults.
#
# Usage, only after the user explicitly chooses to reset local permissions:
#   ZOOMIT_ALLOW_TCC_RESET=I_UNDERSTAND_THIS_RESETS_LOCAL_DORAZOOM_PERMISSIONS zsh Scripts/reset-first-run.sh
#   ZOOMIT_ALLOW_TCC_RESET=I_UNDERSTAND_THIS_RESETS_LOCAL_DORAZOOM_PERMISSIONS zsh Scripts/reset-first-run.sh --keep-settings
#   ZOOMIT_ALLOW_TCC_RESET=I_UNDERSTAND_THIS_RESETS_LOCAL_DORAZOOM_PERMISSIONS zsh Scripts/reset-first-run.sh --no-launch
#
# Daily app reset requires an additional explicit guard:
#   ZOOMIT_ALLOW_DAILY_RESET=I_UNDERSTAND_THIS_RESETS_DAILY_DORAZOOM_PERMISSIONS
#
# Note: test first run with the .app bundle (build it with Scripts/build-app.sh),
# not `swift run`. The build script ad-hoc signs the bundle with a stable local
# designated requirement so privacy grants attach to the bundle identifier.

set -euo pipefail

# Match the bundle id produced by Scripts/build-app.sh. Development ad-hoc
# builds use the .dev id so their privacy grants stay separate from the daily
# DoraZoom app. Override with
# ZOOMIT_BUNDLE_ID to reset a differently-identified build.
BUNDLE_ID="${ZOOMIT_BUNDLE_ID:-com.duola.dorazoom.dev}"
ROOT_DIR="${0:A:h:h}"
# build-app.sh's default development bundle is "DoraZoom Dev.app". Override
# with ZOOMIT_APP_NAME if you changed it.
APP_NAME="${ZOOMIT_APP_NAME:-DoraZoom Dev.app}"
APP_PATH="$ROOT_DIR/.build/$APP_NAME"
RESET_CONFIRMATION_PHRASE="I_UNDERSTAND_THIS_RESETS_LOCAL_DORAZOOM_PERMISSIONS"
DAILY_RESET_CONFIRMATION_PHRASE="I_UNDERSTAND_THIS_RESETS_DAILY_DORAZOOM_PERMISSIONS"

keep_settings=false
launch=true
for arg in "$@"; do
    case "$arg" in
        --keep-settings) keep_settings=true ;;
        --no-launch) launch=false ;;
        -h|--help)
            sed -n '2,17p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

if [[ "${ZOOMIT_ALLOW_TCC_RESET:-}" != "$RESET_CONFIRMATION_PHRASE" ]]; then
    echo "Refusing to reset DoraZoom permissions without explicit confirmation." >&2
    echo "Set ZOOMIT_ALLOW_TCC_RESET=$RESET_CONFIRMATION_PHRASE only for a visible manual Phase 7 reset." >&2
    exit 2
fi

if [[ "$BUNDLE_ID" == "com.duola.dorazoom" && "${ZOOMIT_ALLOW_DAILY_RESET:-}" != "$DAILY_RESET_CONFIRMATION_PHRASE" ]]; then
    echo "Refusing to reset the daily DoraZoom permission record without daily-app confirmation." >&2
    echo "Set ZOOMIT_ALLOW_DAILY_RESET=$DAILY_RESET_CONFIRMATION_PHRASE only if you intentionally want to clear the daily app's TCC record." >&2
    exit 2
fi

echo "Quitting any running DoraZoom instance…"
pkill -f "/Contents/MacOS/DoraZoom" 2>/dev/null || true
sleep 1

echo "Resetting privacy permissions (Screen Recording, Microphone, Camera) for $BUNDLE_ID…"
# `reset All` clears every TCC service this app may have been granted.
tccutil reset All "$BUNDLE_ID" || true
# Older development bundles were only executable-signed and appeared to TCC as
# "ZoomIt" instead of the bundle identifier. Clear that stale identity too so
# the Screen Recording list doesn't show an enabled row that no longer matches
# the current app's code requirement.
tccutil reset All "ZoomIt" >/dev/null 2>&1 || true

if [[ "$keep_settings" == false ]]; then
    echo "Clearing saved settings (UserDefaults) for $BUNDLE_ID…"
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
else
    echo "Keeping saved settings."
fi

if [[ "$launch" == true ]]; then
    if [[ -d "$APP_PATH" ]]; then
        echo "Relaunching $APP_PATH …"
        open "$APP_PATH"
        echo "Grant Screen Recording when prompted, then quit and reopen DoraZoom once."
    else
        echo "App bundle not found at $APP_PATH."
        echo "Build it first with: zsh Scripts/build-app.sh release"
        exit 1
    fi
else
    echo "Done. Launch the app manually with: open \"$APP_PATH\""
fi
