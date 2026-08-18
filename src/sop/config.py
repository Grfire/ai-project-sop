"""Bundle configuration and portable URI resolution."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import unquote

import yaml
from jsonschema import Draft202012Validator

from .io import read_json

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
URI_RE = re.compile(r"^(bundle|project)://(.*)$")


def _inside(candidate: Path, root: Path) -> bool:
    try:
        candidate.relative_to(root)
        return True
    except ValueError:
        return False


@dataclass(frozen=True)
class Config:
    root: Path
    data: dict[str, Any]

    @classmethod
    def load(cls, root: Path | str | None = None) -> "Config":
        bundle = Path(root or Path.cwd()).expanduser().resolve()
        path = bundle / "sop.yaml"
        if not path.is_file():
            raise FileNotFoundError(f"sop.yaml missing at bundle root: {bundle}")
        data = yaml.safe_load(path.read_text(encoding="utf-8-sig"))
        schema = read_json(bundle / "schemas" / "sop-config.schema.json")
        errors = sorted(Draft202012Validator(schema).iter_errors(data), key=lambda e: list(e.path))
        if errors:
            raise ValueError("invalid sop.yaml: " + "; ".join(error.message for error in errors))
        return cls(bundle, data)

    @property
    def projects_root(self) -> Path:
        return self.resolve(self.data["projects_root"])

    def project_root(self, slug: str) -> Path:
        validate_slug(slug)
        return (self.projects_root / slug).resolve()

    def resolve(
        self,
        value: str,
        *,
        slug: str | None = None,
        allow_external: bool = False,
    ) -> Path:
        if not isinstance(value, str) or not value.strip():
            raise ValueError("path must be a non-empty string")
        rendered = value.format(slug=slug) if slug else value
        if "{slug}" in rendered:
            raise ValueError("path requires a slug")
        match = URI_RE.fullmatch(rendered)
        if match:
            scheme, raw = match.groups()
            relative = Path(unquote(raw.lstrip("/").replace("\\", "/")))
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError(f"portable URI escapes its root: {value}")
            base = self.root if scheme == "bundle" else self._require_project_root(slug)
            resolved = (base / relative).resolve()
            if not _inside(resolved, base.resolve()):
                raise ValueError(f"portable URI escapes its root: {value}")
            return resolved
        path = Path(rendered).expanduser()
        if path.is_absolute() and allow_external:
            return path.resolve()
        raise ValueError(
            "internal paths must use bundle:// or project://; "
            "absolute paths are accepted only for explicit external sources"
        )

    def uri_for(self, path: Path | str, *, slug: str | None = None) -> str:
        resolved = Path(path).expanduser().resolve()
        if slug:
            project = self.project_root(slug)
            if _inside(resolved, project):
                suffix = resolved.relative_to(project).as_posix()
                return "project://" + suffix
        if _inside(resolved, self.root):
            suffix = resolved.relative_to(self.root).as_posix()
            return "bundle://" + suffix
        return str(resolved)

    def configured_project_paths(self, slug: str) -> dict[str, str | None]:
        validate_slug(slug)
        result: dict[str, str | None] = {}
        for key, value in self.data["project_paths"].items():
            result[key] = value.format(slug=slug) if isinstance(value, str) else None
        return result

    def _require_project_root(self, slug: str | None) -> Path:
        if not slug:
            raise ValueError("project:// resolution requires --slug or an active project")
        return self.project_root(slug)


def validate_slug(slug: str) -> str:
    if not SLUG_RE.fullmatch(slug or ""):
        raise ValueError("slug must match ^[a-z0-9][a-z0-9-]*$")
    return slug
