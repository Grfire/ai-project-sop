#!/usr/bin/env python3
"""Validate intake machine artifacts. Evidence only; never a human gate."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator, FormatChecker
except ImportError as exc:
    print(
        f"ERROR jsonschema is unavailable; intake schema validation is mandatory: {exc}",
        file=sys.stderr,
    )
    raise SystemExit(3) from exc

REPO_ROOT = Path(__file__).resolve().parents[1]
PLACEHOLDER = re.compile(r"\{\{(?:slug|source_path|project-slug)\}\}")
SOURCE_SLUG = re.compile(r"(?im)^\|\s*Slug\s*\|\s*([^|]+?)\s*\|")
SOURCE_PATH = re.compile(r"(?im)^\|\s*Source path\s*\|\s*`?([^`|]+?)`?\s*\|")


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def schema_errors(instance: object, schema_path: Path, label: str) -> list[str]:
    schema = load_json(schema_path)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return [
        f"{label}{''.join(f'[{part!r}]' for part in error.absolute_path)}: {error.message}"
        for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.absolute_path))
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("intake", type=Path)
    args = parser.parse_args()
    intake = args.intake.resolve()
    errors: list[str] = []

    manifest_path = intake / "manifest.json"
    ledger_path = intake / "reading-ledger.csv"
    source_path = intake / "SOURCE.md"
    if not manifest_path.is_file():
        errors.append("Missing manifest.json")
        manifest = None
    else:
        try:
            manifest = load_json(manifest_path)
        except json.JSONDecodeError as exc:
            errors.append(f"manifest.json is not valid JSON: {exc}")
            manifest = None
        else:
            errors.extend(
                schema_errors(manifest, REPO_ROOT / "schemas" / "intake-manifest.schema.json", "manifest")
            )

    if not ledger_path.is_file():
        errors.append("Missing reading-ledger.csv")
    else:
        with ledger_path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            for index, row in enumerate(reader, 1):
                errors.extend(
                    schema_errors(
                        row,
                        REPO_ROOT / "schemas" / "intake-ledger-row.schema.json",
                        f"ledger[{index}]",
                    )
                )

    if not source_path.is_file():
        errors.append("Missing SOURCE.md")
    elif manifest is not None:
        text = source_path.read_text(encoding="utf-8")
        slug_match = SOURCE_SLUG.search(text)
        path_match = SOURCE_PATH.search(text)
        if not slug_match:
            errors.append("SOURCE.md missing Slug row")
        elif slug_match.group(1).strip() != str(manifest.get("slug", "")):
            errors.append("SOURCE.md slug does not match manifest.slug")
        if not path_match:
            errors.append("SOURCE.md missing Source path row")
        else:
            documented = str(Path(path_match.group(1).strip()))
            actual = str(Path(str(manifest.get("source_path", ""))))
            if documented.rstrip("\\/") != actual.rstrip("\\/"):
                errors.append("SOURCE.md source path does not match manifest.source_path")

    for path in intake.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".md", ".json", ".csv", ".yaml", ".yml"}:
            continue
        if path.name.lower() == "readme.md":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if PLACEHOLDER.search(text):
            errors.append(f"leftover placeholder in {path.relative_to(intake).as_posix()}")

    if errors:
        for error in errors:
            print(f"ERROR {error}", file=sys.stderr)
        return 1
    print(f"OK intake={intake}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
