"""Canonical project state, identity guard, and lifecycle rules."""

from __future__ import annotations

import re
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker

from .config import Config, validate_slug
from .io import atomic_write_json, atomic_write_text, read_json, replace_text_atomic

STAGES = ("INTAKE", "REQ", "PPT", "UI", "ARCH", "TEST", "CODE", "DOCS")
TIMESTAMPS = (
    "updated_at",
    "last_code_change_at",
    "last_regression_at",
    "intake_completed_at",
    "test_pack_at",
    "docs_completed_at",
    "lifecycle_changed_at",
)
AUTHORITY_NOTE = (
    "Machine state only. Human gates require conversational confirmation "
    "recorded in APPROVALS.md."
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def active_slug(config: Config) -> str | None:
    current = config.projects_root / "CURRENT.md"
    if not current.is_file():
        return None
    match = re.search(r"(?im)^\s*slug\s*:\s*([a-z0-9][a-z0-9-]*)\s*$", current.read_text(encoding="utf-8-sig"))
    if not match or match.group(1) in {"unset", "none"}:
        return None
    return match.group(1)


def activate(config: Config, slug: str) -> dict[str, Any]:
    validate_slug(slug)
    project = config.project_root(slug)
    if not project.is_dir():
        raise FileNotFoundError(f"project does not exist: {project}")
    state = load_state(config, slug)
    stamp = utc_now()
    atomic_write_text(
        config.projects_root / "CURRENT.md",
        f"# CURRENT\n\nslug: {slug}\nupdated_at: {stamp}\n",
    )
    return {"slug": slug, "lifecycle": state["lifecycle"], "updated_at": stamp}


def guard_project(config: Config, slug: str, intent: str = "delivery") -> dict[str, Any]:
    validate_slug(slug)
    project = config.project_root(slug)
    if project.name != slug:
        raise RuntimeError("project directory slug mismatch")
    state = load_state(config, slug)
    if state.get("slug") != slug:
        raise RuntimeError(f"project identity mismatch: directory '{slug}' != state.slug '{state.get('slug')}'")
    current = active_slug(config)
    if current and current != slug:
        raise RuntimeError(f"project identity mismatch: requested '{slug}' != CURRENT '{current}'")
    lifecycle = state["lifecycle"]
    allowed = {
        "active": {"delivery", "lifecycle", "cancellation"},
        "paused": {"lifecycle", "cancellation"},
        "cancelled": {"cancellation"},
        "archived": {"lifecycle"},
    }
    if intent not in allowed[lifecycle]:
        raise RuntimeError(f"project lifecycle '{lifecycle}' blocks {intent} writes")
    return state


def canonical_state(config: Config, slug: str, value: dict[str, Any]) -> dict[str, Any]:
    paths = config.configured_project_paths(slug) | dict(value.get("paths") or {})
    statuses = value.get("stage_status") or {}
    timestamps = value.get("timestamps") or {}
    governance = value.get("governance") or {}
    refs = value.get("approval_refs") or {}
    result: dict[str, Any] = {
        "schema_version": 1,
        "slug": slug,
        "lifecycle": value.get("lifecycle") or "active",
        "origin": value.get("origin") or "new",
        "current_stage": value.get("current_stage") or "REQ",
        "mode": value.get("mode") or None,
        "stage_status": {
            stage: statuses.get(stage, "na" if stage in {"INTAKE", "PPT"} else "not_started")
            for stage in STAGES
        },
        "ui_input_mode": value.get("ui_input_mode") or None,
        "blocked": value.get("blocked") or None,
        "paths": {key: paths.get(key) for key in ("intake", "req", "ppt_path", "ui", "arch", "code", "test", "docs")},
        "timestamps": {key: timestamps.get(key) or None for key in TIMESTAMPS},
        "approval_refs": {key: val for key, val in refs.items() if val},
        "governance": {
            "data_classification": governance.get("data_classification") or None,
            "regulated_data": list(governance.get("regulated_data") or []),
            "residency": governance.get("residency") or None,
            "retention": governance.get("retention") or None,
            "access_audit": governance.get("access_audit") or None,
            "third_party_transfer": governance.get("third_party_transfer") or None,
            "compliance_owner": governance.get("compliance_owner") or None,
            "active_waiver_ids": list(governance.get("active_waiver_ids") or []),
        },
        "_authority_note": value.get("_authority_note") or AUTHORITY_NOTE,
    }
    regression = value.get("regression")
    if regression:
        result["regression"] = regression
    return result


def validate_state(config: Config, value: dict[str, Any]) -> None:
    schema = read_json(config.root / "schemas" / "state.schema.json")
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(validator.iter_errors(value), key=lambda error: list(error.path))
    if errors:
        raise ValueError("invalid canonical state: " + "; ".join(error.message for error in errors))
    slug = value["slug"]
    for key, uri in value["paths"].items():
        if uri is not None:
            config.resolve(uri, slug=slug)


def write_state(config: Config, slug: str, value: dict[str, Any]) -> dict[str, Any]:
    result = canonical_state(config, slug, value)
    validate_state(config, result)
    atomic_write_json(config.project_root(slug) / "state.json", result)
    return result


def load_state(config: Config, slug: str) -> dict[str, Any]:
    path = config.project_root(slug) / "state.json"
    if not path.is_file():
        raise FileNotFoundError(f"state.json missing: {path}")
    value = read_json(path)
    validate_state(config, value)
    return value


def new_project(config: Config, slug: str, origin: str = "new", set_active: bool = True) -> dict[str, Any]:
    validate_slug(slug)
    if origin not in {"new", "historical"}:
        raise ValueError("origin must be new or historical")
    template = config.projects_root / "_template"
    target = config.project_root(slug)
    if target.exists():
        raise FileExistsError(f"project already exists: {target}")
    config.projects_root.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".new-{slug}-", dir=config.projects_root))
    try:
        shutil.rmtree(temporary)
        shutil.copytree(template, temporary, ignore=shutil.ignore_patterns("node_modules", "__pycache__"))
        for path in temporary.rglob("*"):
            if path.is_file() and path.suffix.lower() in {".md", ".json", ".yaml", ".yml", ".csv", ".ps1"}:
                replace_text_atomic(path, {"{{project-slug}}": slug, "{{slug}}": slug})
        if origin == "new":
            shutil.rmtree(temporary / "intake", ignore_errors=True)
        else:
            for name in ("actual-state.md", "evidence-map.md", "stage-gap-matrix.md", "supplement-plan.md"):
                (temporary / "intake" / name).unlink(missing_ok=True)
        value = read_json(temporary / "state.json")
        value.update(origin=origin, current_stage="INTAKE" if origin == "historical" else "REQ")
        value["stage_status"]["INTAKE"] = "in_progress" if origin == "historical" else "na"
        value["stage_status"]["REQ"] = "not_started" if origin == "historical" else "in_progress"
        value["paths"] = config.configured_project_paths(slug)
        value["timestamps"]["updated_at"] = utc_now()
        result = canonical_state(config, slug, value)
        validate_state(config, result)
        atomic_write_json(temporary / "state.json", result)
        replace_text_atomic(
            temporary / "SOP.md",
            {
                "| Project origin | new / historical |": f"| Project origin | {origin} |",
                "| Current stage | REQ |": f"| Current stage | {'INTAKE' if origin == 'historical' else 'REQ'} |",
                "| INTAKE | na | |": f"| INTAKE | {'in_progress' if origin == 'historical' else 'na'} | |",
                "| REQ | in_progress | |": f"| REQ | {'not_started' if origin == 'historical' else 'in_progress'} | |",
            },
        )
        temporary.replace(target)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary, ignore_errors=True)
    if set_active:
        activate(config, slug)
    return {"slug": slug, "origin": origin, "project_root": str(target), "active": set_active}


def list_projects(config: Config) -> list[dict[str, Any]]:
    current = active_slug(config)
    results = []
    for path in sorted(config.projects_root.iterdir()):
        if not path.is_dir() or path.name == "_template":
            continue
        try:
            state = load_state(config, path.name)
            warning = None
        except Exception as exc:  # list must report malformed portfolio entries
            state, warning = {}, str(exc)
        results.append({
            "slug": path.name,
            "active": path.name == current,
            "lifecycle": state.get("lifecycle", "unknown"),
            "stage": state.get("current_stage", "unknown"),
            "mode": state.get("mode"),
            "blocked": state.get("blocked"),
            "warning": warning,
        })
    return results
