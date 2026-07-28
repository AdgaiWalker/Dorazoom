#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

if [[ ! -d Tests ]]; then
    print "error: Tests directory not found" >&2
    exit 2
fi

FORBIDDEN_PATTERNS=(
    'NSPasteboard\.general'
    'CGEvent\.tapCreate'
    'CGEventCreateKeyboardEvent'
    'NSEvent\.addGlobalMonitorForEvents'
    'SCStream\b'
    'SCShareableContent\b'
    'SCScreenshotManager\b'
    'AVCaptureDevice\b'
    'AVAudioEngine\b'
    'AVAudioRecorder\b'
    '\bProcess\s*\('
    '\bNSTask\b'
    '/usr/bin/'
    'osascript\b'
    'pbcopy\b'
    'pbpaste\b'
    'screencapture\b'
    'tccutil\b'
    'SMAppService\b'
    'IOHID'
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if rg -n --pcre2 "$pattern" Tests; then
        print "error: automated tests must use simulation/test doubles, but matched forbidden real-platform API pattern: $pattern" >&2
        exit 2
    fi
done

print "PASS: automated tests stay inside the simulation boundary"
