"""Non-destructive migration from the legacy sibling-workspace layout."""

from __future__ import annotations

import os
import re
import shutil
import tempfile
import uuid
from pathlib import Path
from typing import Any

import yaml

from .config import Config, validate_slug
from .io import atomic_write_json, atomic_write_text, read_json
from .state import canonical_state, validate_state

EXCLUDED_DIRS = {
    ".git",
    ".gnupg",
    ".aws",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".ssh",
    ".tox",
    ".venv",
    "__pycache__",
    "cache",
    "coverage",
    "dist",
    "build",
    "node_modules",
    "secrets",
    "venv",
}
SENSITIVE = re.compile(
    r"(?i)(^|/)(?:\.env(?:\..+)?|\.netrc|\.npmrc|\.pypirc|"
    r"credentials[^/]*|secrets?[^/]*|"
    r"id_(?:rsa|ed25519)|[^/]*\.(?:key|pem|p12|pfx))$"
)
STAGE_KEYS = ("governance", "req", "ui", "arch", "code")


def _under_legacy_root(rendered: str, root: Path) -> Path:
    relative_text = re.sub(
        r"(?i)^[A-Za-z]:[/\\]workspace[/\\]?", "", rendered
    )
    return (root / Path(relative_text.replace("\\", "/"))).resolve()


def _legacy_sources(
    config: Config, slug: str, legacy_root: Path | None = None
) -> dict[str, Path]:
    templates = config.data["migration"]["legacy_sources"]
    root = legacy_root.expanduser().resolve() if legacy_root else None
    result: dict[str, Path] = {}
    for key in STAGE_KEYS:
        rendered = templates[key].format(slug=slug)
        if root:
            # Config records the old E:/workspace layout. A supplied root
            # replaces that prefix while retaining each sibling directory.
            result[key] = _under_legacy_root(rendered, root)
        else:
            result[key] = Path(rendered).expanduser().resolve()
    state_path = result["governance"] / "state.json"
    if state_path.is_file():
        try:
            ppt_path = (read_json(state_path).get("paths") or {}).get("ppt_path")
            if isinstance(ppt_path, str) and ppt_path and "://" not in ppt_path:
                result["ppt"] = (
                    _under_legacy_root(ppt_path, root)
                    if root
                    else Path(ppt_path).expanduser().resolve()
                )
        except Exception:
            # The governance row reports the unreadable state with a useful
            # error; source discovery itself remains side-effect free.
            pass
    return result


def _targets(
    config: Config, slug: str, sources: dict[str, Path] | None = None
) -> dict[str, Path]:
    paths = config.configured_project_paths(slug)
    result = {
        "governance": config.project_root(slug),
        **{
            key: config.resolve(paths[key], slug=slug)
            for key in ("req", "ui", "arch", "code")
        },
    }
    if sources and "ppt" in sources:
        ppt_root = config.resolve(config.data["workspaces"]["ppt"], slug=slug)
        result["ppt"] = (ppt_root / sources["ppt"].name).resolve()
    return result


def _iter_files(source: Path) -> tuple[list[Path], list[dict[str, str]]]:
    files: list[Path] = []
    excluded: list[dict[str, str]] = []
    for directory, dirs, names in os.walk(source, followlinks=False):
        base = Path(directory)
        relative_dir = base.relative_to(source)
        kept: list[str] = []
        for name in dirs:
            candidate = base / name
            relative = (relative_dir / name).as_posix()
            if (
                name.lower() in EXCLUDED_DIRS
                or candidate.is_symlink()
            ):
                excluded.append({"path": relative, "reason": "dependency/cache/VCS/symlink"})
            else:
                kept.append(name)
        dirs[:] = kept
        for name in names:
            candidate = base / name
            relative = candidate.relative_to(source).as_posix()
            if candidate.is_symlink():
                excluded.append({"path": relative, "reason": "symlink"})
            elif SENSITIVE.search(relative):
                excluded.append({"path": relative, "reason": "potential secret"})
            else:
                files.append(candidate)
    return files, excluded


def migration_plan(
    config: Config, slug: str, legacy_root: Path | None = None
) -> dict[str, Any]:
    validate_slug(slug)
    sources = _legacy_sources(config, slug, legacy_root)
    targets = _targets(config, slug, sources)
    keys = STAGE_KEYS + (("ppt",) if "ppt" in sources else ())
    rows: list[dict[str, Any]] = []
    all_ready = True
    for key in keys:
        source, target = sources[key], targets[key]
        files, excluded = _iter_files(source) if source.is_dir() else ([], [])
        errors: list[str] = []
        same_path = source == target
        if key == "governance" and not source.is_dir():
            errors.append("required governance source missing")
        if source.is_dir() and target.exists() and not (
            key == "governance" and same_path
        ):
            errors.append("target already exists; migration never overwrites")
        if key == "governance":
            state_path = source / "state.json"
            if source.is_dir() and not state_path.is_file():
                errors.append("state.json missing")
            elif state_path.is_file():
                try:
                    if read_json(state_path).get("slug") != slug:
                        errors.append("state.json slug mismatch")
                except Exception as exc:
                    errors.append(f"state.json unreadable: {exc}")
        all_ready = all_ready and not errors
        rows.append(
            {
                "stage": key,
                "source": str(source),
                "target": str(target),
                "files": len(files),
                "bytes": sum(path.stat().st_size for path in files),
                "excluded": excluded,
                "action": (
                    "update-in-place"
                    if key == "governance" and source.is_dir() and same_path
                    else ("copy" if source.is_dir() else "skip-missing")
                ),
                "ready": not errors,
                "errors": errors,
            }
        )
    return {
        "slug": slug,
        "mode": "dry-run",
        "ready": all_ready,
        "sources": rows,
        "preserves": ["APPROVALS.md", "DECISIONS.md", "SOP.md", "state.json slug and approval_refs"],
        "human_gate_approved": False,
    }


def _copy_filtered(source: Path, staging: Path) -> None:
    files, _ = _iter_files(source)
    staging.mkdir(parents=True)
    for path in files:
        relative = path.relative_to(source)
        target = staging / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)


def _portable_replacements(
    config: Config,
    slug: str,
    sources: dict[str, Path],
    targets: dict[str, Path],
) -> dict[str, str]:
    uris = {
        "governance": f"bundle://projects/{slug}",
        "req": config.configured_project_paths(slug)["req"],
        "ui": config.configured_project_paths(slug)["ui"],
        "arch": config.configured_project_paths(slug)["arch"],
        "code": config.configured_project_paths(slug)["code"],
    }
    if "ppt" in targets:
        uris["ppt"] = config.uri_for(targets["ppt"], slug=slug)
    replacements: dict[str, str] = {}
    for key, source in sources.items():
        for rendered in {str(source), source.as_posix()}:
            replacements[rendered.rstrip("/\\")] = str(uris[key])
    return dict(sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True))


def _replace_legacy_text(path: Path, replacements: dict[str, str]) -> None:
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8-sig")
    for old, new in replacements.items():
        text = text.replace(old, new)
    atomic_write_text(path, text)


def _update_staged_metadata(
    config: Config,
    slug: str,
    staged: dict[str, Path],
    sources: dict[str, Path],
    targets: dict[str, Path],
) -> None:
    governance = staged["governance"]
    state_path = governance / "state.json"
    state = read_json(state_path)
    if state.get("slug") != slug:
        raise ValueError("state.json slug changed during migration")
    state["paths"] = config.configured_project_paths(slug)
    if "ppt" in staged:
        state["paths"]["ppt_path"] = config.uri_for(targets["ppt"], slug=slug)
    canonical = canonical_state(config, slug, state)
    validate_state(config, canonical)
    atomic_write_json(state_path, canonical)

    replacements = _portable_replacements(config, slug, sources, targets)
    _replace_legacy_text(governance / "SOP.md", replacements)
    _replace_legacy_text(governance / "test" / "catalog.yaml", replacements)
    _replace_legacy_text(governance / "test" / "runtime.yaml", replacements)

    runtime = governance / "test" / "runtime.yaml"
    if runtime.is_file():
        value = yaml.safe_load(runtime.read_text(encoding="utf-8-sig")) or {}
        value["code_root"] = canonical["paths"]["code"]
        value["product_root"] = "project://test/product"
        atomic_write_text(runtime, yaml.safe_dump(value, sort_keys=False, allow_unicode=True))

    catalog = governance / "test" / "catalog.yaml"
    if catalog.is_file():
        value = yaml.safe_load(catalog.read_text(encoding="utf-8-sig")) or {}
        source = value.setdefault("source", {})
        source["prd"] = canonical["paths"]["req"] + "/PRD.md"
        source["arch"] = canonical["paths"]["arch"] + "/design/CODING_HANDOFF.md"
        source["ui"] = canonical["paths"]["ui"] + "/design/design-spec.md"
        atomic_write_text(catalog, yaml.safe_dump(value, sort_keys=False, allow_unicode=True))


METADATA_PATHS = (
    Path("state.json"),
    Path("SOP.md"),
    Path("test/catalog.yaml"),
    Path("test/runtime.yaml"),
)


def _atomic_replace_metadata(source: Path, destination: Path) -> None:
    """Copy a staged file beside its destination, then atomically replace it."""
    temporary = destination.with_name(
        f".{destination.name}.migrate-{uuid.uuid4().hex}.tmp"
    )
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def _restore_metadata(
    governance: Path,
    backups: dict[Path, Path | None],
) -> None:
    for relative, backup in backups.items():
        destination = governance / relative
        if backup is None:
            destination.unlink(missing_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            _atomic_replace_metadata(backup, destination)


def migration_apply(
    config: Config,
    slug: str,
    legacy_root: Path | None = None,
    *,
    execute: bool = False,
) -> dict[str, Any]:
    plan = migration_plan(config, slug, legacy_root)
    if not execute:
        return plan | {"action": "not-applied; pass --execute after reviewing the plan"}
    if not plan["ready"]:
        raise RuntimeError("migration plan is not ready; no files were written")

    sources = _legacy_sources(config, slug, legacy_root)
    targets = _targets(config, slug, sources)
    copy_keys = [
        row["stage"] for row in plan["sources"] if row["action"] == "copy"
    ]
    governance_in_place = any(
        row["stage"] == "governance" and row["action"] == "update-in-place"
        for row in plan["sources"]
    )
    stage_keys = copy_keys + (["governance"] if governance_in_place else [])
    staged: dict[str, Path] = {}
    committed: list[Path] = []
    backups: dict[Path, Path | None] = {}
    backup_root: Path | None = None
    try:
        for key in stage_keys:
            target = targets[key]
            target.parent.mkdir(parents=True, exist_ok=True)
            staging = Path(
                tempfile.mkdtemp(prefix=f".sop-migrate-{slug}-{key}-", dir=target.parent)
            )
            shutil.rmtree(staging)
            _copy_filtered(sources[key], staging)
            staged[key] = staging
        _update_staged_metadata(config, slug, staged, sources, targets)
        for key in copy_keys:
            target = targets[key]
            if target.exists():
                raise FileExistsError(f"target appeared during migration: {target}")
            staged[key].replace(target)
            committed.append(target)

        if governance_in_place:
            governance = targets["governance"]
            backup_root = Path(
                tempfile.mkdtemp(
                    prefix=f".sop-migrate-{slug}-metadata-backup-",
                    dir=governance.parent,
                )
            )
            for relative in METADATA_PATHS:
                destination = governance / relative
                staged_file = staged["governance"] / relative
                if not staged_file.is_file():
                    continue
                if destination.is_file():
                    backup = backup_root / relative
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(destination, backup)
                    backups[relative] = backup
                else:
                    backups[relative] = None
                _atomic_replace_metadata(staged_file, destination)

        return {
            "slug": slug,
            "mode": "apply",
            "applied": True,
            "targets": {
                key: str(targets[key])
                for key in copy_keys + (["governance"] if governance_in_place else [])
            },
            "governance_action": (
                "update-in-place" if governance_in_place else "copy"
            ),
            "excluded_count": sum(len(row["excluded"]) for row in plan["sources"]),
            "human_gate_approved": False,
        }
    except Exception as original:
        restore_error: Exception | None = None
        try:
            if governance_in_place and backups:
                _restore_metadata(targets["governance"], backups)
        except Exception as exc:  # cleanup must continue even if restore reports damage
            restore_error = exc
        finally:
            for target in reversed(committed):
                shutil.rmtree(target, ignore_errors=True)
        if restore_error:
            raise RuntimeError(
                f"migration failed and metadata restore also failed: {restore_error}"
            ) from original
        raise
    finally:
        if backup_root is not None:
            shutil.rmtree(backup_root, ignore_errors=True)
        for staging in staged.values():
            shutil.rmtree(staging, ignore_errors=True)
