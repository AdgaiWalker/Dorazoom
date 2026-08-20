#!/usr/bin/env python3
"""Build DoraZoom's String Catalog from reviewed keysets and locale JSON files."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


PRINTF_TOKEN = re.compile(
    r"%(?:\d+\$)?[-+#0 ']*(?:\d+|\*)?(?:\.(?:\d+|\*))?"
    r"(?:hh|h|ll|l|L|z|j|t|q)?[@diuoxXfFeEgGaAcCsSp]"
)
DEMOTYPE_TOKEN = re.compile(
    r"\[(?:start|end|pause:n|paste|/paste|enter|up|down|left|right)\]"
)
KEYBOARD_MODIFIERS = {"Control", "Command", "Option", "Shift"}
KEYBOARD_CONTEXT = re.compile(
    r"\b(?:shortcut|key|hotkey|keyboard|press|hold|undo|toggled|require|without|with)\b"
    r"|[+-]",
    re.IGNORECASE,
)


def load_object(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in data.items()
    ):
        raise ValueError(f"{path} must contain a JSON object of string keys and values")
    return data


def placeholders(value: str) -> list[str]:
    # Order is part of the formatting contract unless the translator uses
    # explicit positional specifiers such as %2$@. Sorting would let `%@ %d`
    # silently become `%d %@` and crash or corrupt the rendered message.
    return PRINTF_TOKEN.findall(value.replace("%%", ""))


def load_keep_english(path: Path) -> list[str]:
    """Read the simple `terms.keep_english` list without a YAML dependency."""
    tokens: list[str] = []
    in_keep_english = False
    section_indent = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        indent = len(raw_line) - len(raw_line.lstrip())
        if stripped == "keep_english:":
            in_keep_english = True
            section_indent = indent
            continue
        if not in_keep_english:
            continue
        if stripped and indent <= section_indent:
            break
        match = re.match(r"^-\s+(.+?)\s*$", stripped)
        if match:
            tokens.append(match.group(1).strip("'\""))
    if not tokens:
        raise ValueError(f"No terms.keep_english entries found in {path}")
    return tokens


def contains_token(value: str, token: str) -> bool:
    return re.search(
        rf"(?<![A-Za-z0-9]){re.escape(token)}(?![A-Za-z0-9])",
        value,
    ) is not None


def requires_protected_token(value: str, token: str) -> bool:
    if not contains_token(value, token):
        return False
    # Modifier names can also be ordinary English nouns (for example,
    # "Pen Control"). Protect them only in a keyboard/shortcut context.
    if token in KEYBOARD_MODIFIERS:
        return KEYBOARD_CONTEXT.search(value) is not None
    return True


def string_unit(value: str) -> dict[str, dict[str, str]]:
    return {"stringUnit": {"state": "translated", "value": value}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keysets-dir", type=Path, default=Path(".l10n/keysets"))
    parser.add_argument("--translations-dir", type=Path, default=Path(".l10n/translations"))
    parser.add_argument("--glossary", type=Path, default=Path(".l10n/glossary.yaml"))
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("Sources/ZoomItMacCore/Resources/Localizable.xcstrings"),
    )
    parser.add_argument(
        "--locale",
        action="append",
        dest="locales",
        help="Required translated locale. Repeat for each locale.",
    )
    args = parser.parse_args()
    protected_tokens = load_keep_english(args.glossary)

    keyset_paths = sorted(args.keysets_dir.glob("*.json"))
    if not keyset_paths:
        raise FileNotFoundError(f"No keysets found in {args.keysets_dir}")

    english: dict[str, str] = {}
    owners: dict[str, Path] = {}
    for path in keyset_paths:
        for key, value in load_object(path).items():
            if key in english and english[key] != value:
                raise ValueError(
                    f"Conflicting English values for {key!r}: "
                    f"{owners[key]} has {english[key]!r}; {path} has {value!r}"
                )
            english[key] = value
            owners.setdefault(key, path)

    locales = args.locales or []
    translated: dict[str, dict[str, str]] = {}
    expected = set(english)
    for locale in locales:
        path = args.translations_dir / f"{locale}.json"
        if not path.is_file():
            raise FileNotFoundError(f"Missing translations for {locale}: {path}")
        values = load_object(path)
        missing = sorted(expected - set(values))
        extra = sorted(set(values) - expected)
        if missing or extra:
            raise ValueError(
                f"{locale} key mismatch: missing {len(missing)} {missing[:5]}, "
                f"extra {len(extra)} {extra[:5]}"
            )
        for key, source in english.items():
            if not values[key].strip():
                raise ValueError(f"{locale} has an empty translation for {key!r}")
            if placeholders(source) != placeholders(values[key]):
                raise ValueError(
                    f"{locale} placeholder mismatch for {key!r}: "
                    f"{placeholders(source)} != {placeholders(values[key])}"
                )
            if source.count("\n") != values[key].count("\n"):
                raise ValueError(
                    f"{locale} changed line-break structure for {key!r}: "
                    f"{source.count(chr(10))} != {values[key].count(chr(10))}"
                )
            required_tokens = [
                token
                for token in protected_tokens
                if requires_protected_token(source, token)
            ]
            required_tokens.extend(DEMOTYPE_TOKEN.findall(source))
            missing_tokens = [
                token for token in required_tokens
                if not contains_token(values[key], token)
            ]
            if missing_tokens:
                raise ValueError(
                    f"{locale} changed protected tokens for {key!r}: {missing_tokens}"
                )
        translated[locale] = values

    strings: dict[str, object] = {}
    for key in sorted(english):
        localizations = {"en": string_unit(english[key])}
        for locale in locales:
            localizations[locale] = string_unit(translated[locale][key])
        strings[key] = {
            "extractionState": "manual",
            "localizations": localizations,
        }

    catalog = {
        "sourceLanguage": "en",
        "strings": strings,
        "version": "1.0",
    }
    args.catalog.parent.mkdir(parents=True, exist_ok=True)
    args.catalog.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"Built {args.catalog} with {len(strings)} keys and "
        f"{1 + len(locales)} locales (English + {', '.join(locales) or 'none'})."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
