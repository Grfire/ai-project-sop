#!/usr/bin/env python3
"""Validate machine-readable TEST artifacts without evaluating human gates."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker


REPO_ROOT = Path(__file__).resolve().parents[4]
PLACEHOLDER = re.compile(r"\{\{[^}]+\}\}")
UNCONFIGURED = {"unconfigured"}
PATH_SUFFIXES = {".py", ".ts", ".js", ".mjs", ".cjs", ".ps1", ".spec.ts"}


def load_json(path: Path) -> object:
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def validate(instance: object, schema_path: Path, label: str) -> list[str]:
    schema = load_json(schema_path)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return [
        f"{label}{''.join(f'[{part!r}]' for part in error.absolute_path)}: {error.message}"
        for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.absolute_path))
    ]


def is_unconfigured(value: object) -> bool:
    if not isinstance(value, str):
        return False
    text = value.strip()
    if not text:
        return True
    if PLACEHOLDER.search(text):
        return True
    return text.lower() in UNCONFIGURED


def looks_like_path(value: str) -> bool:
    file_part = value.split("::", 1)[0]
    return ("/" in file_part) or ("\\" in file_part) or Path(file_part).suffix.lower() in PATH_SUFFIXES


def resolve_mapped_file(value: str, roots: list[Path]) -> Path | None:
    relative = value.split("::", 1)[0].replace("\\", "/")
    for root in roots:
        candidate = (root / relative).resolve()
        if candidate.exists():
            return candidate
    return None


def collect_unconfigured(catalog: object, prefix: str = "catalog") -> list[str]:
    errors: list[str] = []
    if not isinstance(catalog, dict):
        return [f"{prefix}: catalog is not an object"]
    for key in ("slug",):
        if is_unconfigured(catalog.get(key, "")):
            errors.append(f"{prefix}: {key} is unconfigured/placeholder")
    source = catalog.get("source", {})
    if isinstance(source, dict):
        for key, value in source.items():
            if is_unconfigured(value):
                errors.append(f"{prefix}: source.{key} is unconfigured/placeholder")
    cases = catalog.get("cases", [])
    if not isinstance(cases, list) or len(cases) == 0:
        errors.append(f"{prefix}: cases must contain at least one configured case")
        return errors
    for index, case in enumerate(cases):
        if not isinstance(case, dict):
            continue
        for key in ("id", "title", "code", "product", "script"):
            if key in case and is_unconfigured(case.get(key)):
                errors.append(f"{prefix}: cases[{index}].{key} is unconfigured/placeholder")
    return errors


def collect_file_mapping(catalog: dict, test_root: Path, code_root: Path | None) -> list[str]:
    errors: list[str] = []
    roots = [test_root]
    if code_root:
        roots.append(code_root)
    cases = catalog.get("cases", [])
    if not isinstance(cases, list):
        return errors
    for index, case in enumerate(cases):
        if not isinstance(case, dict) or case.get("deferred") is True:
            continue
        for field in ("script", "code", "product"):
            value = case.get(field)
            if not isinstance(value, str) or not value.strip() or is_unconfigured(value):
                continue
            if not looks_like_path(value):
                continue
            if resolve_mapped_file(value, roots) is None:
                errors.append(
                    f"catalog: cases[{index}].{field} path does not exist for non-deferred case: {value}"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("catalog", type=Path, help="catalog.yaml to validate")
    parser.add_argument("--last-run", type=Path, help="optional last-run.json to validate")
    parser.add_argument("--slug", help="require catalog.slug to match this project slug")
    parser.add_argument("--test-root", type=Path, help="test pack root for non-deferred file mapping")
    parser.add_argument("--code-root", type=Path, help="optional CODE root for mapped code files")
    parser.add_argument(
        "--allow-unconfigured",
        action="store_true",
        help="skip unconfigured/placeholder and empty-case checks (template inspection only)",
    )
    parser.add_argument(
        "--require-trace",
        action="append",
        default=[],
        metavar="TRACE_ID",
        help="require a trace ID to appear in at least one catalog case; repeatable",
    )
    args = parser.parse_args()

    with args.catalog.open("r", encoding="utf-8-sig") as handle:
        catalog = yaml.safe_load(handle)

    errors = validate(catalog, REPO_ROOT / "schemas" / "test-catalog.schema.json", "catalog")
    if not args.allow_unconfigured:
        errors.extend(collect_unconfigured(catalog))
    if args.slug and isinstance(catalog, dict) and catalog.get("slug") != args.slug:
        errors.append(f"catalog: slug '{catalog.get('slug')}' does not match project '{args.slug}'")

    cases = catalog.get("cases", []) if isinstance(catalog, dict) else []
    ids = [case.get("id") for case in cases if isinstance(case, dict)]
    duplicates = sorted({case_id for case_id in ids if ids.count(case_id) > 1})
    if duplicates:
        errors.append(f"catalog: duplicate stable IDs: {', '.join(duplicates)}")

    covered = {
        trace
        for case in cases
        if isinstance(case, dict)
        for trace in case.get("trace", [])
        if isinstance(trace, str)
    }
    missing = sorted(set(args.require_trace) - covered)
    if missing:
        errors.append(f"catalog: missing required trace coverage: {', '.join(missing)}")
    if isinstance(catalog, dict) and args.test_root:
        errors.extend(collect_file_mapping(catalog, args.test_root, args.code_root))

    if args.last_run:
        last_run = load_json(args.last_run)
        errors.extend(
            validate(last_run, REPO_ROOT / "schemas" / "last-run.schema.json", "last-run")
        )
        if isinstance(last_run, dict) and is_unconfigured(str(last_run.get("slug", ""))):
            errors.append("last-run: slug is unconfigured/placeholder")

    if errors:
        for error in errors:
            print(f"ERROR {error}", file=sys.stderr)
        return 1

    print(f"OK catalog={args.catalog}")
    if args.last_run:
        print(f"OK last-run={args.last_run}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
