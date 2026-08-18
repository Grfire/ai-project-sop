"""Small fail-closed filesystem primitives used by every mutating command."""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
    )


def atomic_write_text(path: Path, text: str) -> None:
    path = path.resolve()
    if not path.parent.is_dir():
        raise FileNotFoundError(f"parent directory is missing: {path.parent}")
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def atomic_write_json(path: Path, value: Any) -> None:
    atomic_write_text(path, canonical_json(value))


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def append_markdown_atomic(path: Path, record: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"Markdown record file missing: {path}")
    existing = path.read_text(encoding="utf-8-sig").rstrip()
    atomic_write_text(path, f"{existing}\n\n{record.strip()}\n")


def replace_text_atomic(path: Path, replacements: dict[str, str]) -> None:
    text = path.read_text(encoding="utf-8-sig")
    for old, new in replacements.items():
        text = text.replace(old, new)
    atomic_write_text(path, text)
