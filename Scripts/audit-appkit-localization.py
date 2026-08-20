#!/usr/bin/env python3
"""Reject direct user-facing AppKit string literals missed by the generic audit."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PATTERNS = [
    re.compile(r'NSButton\s*\(\s*title:\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'NSTextField\s*\(\s*labelWithString:\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(
        r'\.(?:messageText|informativeText|placeholderString|toolTip|'
        r'accessibilityLabel|title|stringValue)\s*=\s*"((?:[^"\\]|\\.)*)"'
    ),
]
TEXT = re.compile(r"[A-Za-z\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af]")
ELLIPSIS_ONLY = {"...", "…"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path)
    args = parser.parse_args()

    findings: list[str] = []
    scanned = 0
    for path in sorted(args.source_dir.rglob("*.swift")):
        scanned += 1
        for line_number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            for pattern in PATTERNS:
                for match in pattern.finditer(line):
                    literal = match.group(1)
                    if literal in ELLIPSIS_ONLY or TEXT.search(literal):
                        findings.append(f"{path}:{line_number}: {literal!r}")

    if findings:
        print("ERROR: direct user-facing AppKit literals require AppLocalization:")
        print("\n".join(findings))
        return 1
    print(f"AppKit literal audit: {scanned} Swift files, 0 findings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
