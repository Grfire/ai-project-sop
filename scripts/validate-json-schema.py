#!/usr/bin/env python3
"""Validate a JSON instance against a JSON Schema. Evidence only; never a gate."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("schema", type=Path)
    parser.add_argument("instance", type=Path)
    args = parser.parse_args()

    schema = json.loads(args.schema.read_text(encoding="utf-8-sig"))
    instance = json.loads(args.instance.read_text(encoding="utf-8-sig"))
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(validator.iter_errors(instance), key=lambda item: list(item.absolute_path))
    if errors:
        for error in errors:
            path = "".join(f"[{part!r}]" for part in error.absolute_path)
            print(f"ERROR {path}: {error.message}", file=sys.stderr)
        return 1
    print(f"OK {args.instance}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
