"""Cross-platform stage scaffolding, validation, intake, and regression."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator, FormatChecker

from .config import Config
from .io import atomic_write_json, atomic_write_text, read_json, replace_text_atomic
from .state import active_slug, guard_project, load_state, utc_now, write_state


def scaffold(config: Config, slug: str, stage: str, force: bool = False) -> dict[str, Any]:
    stage = stage.upper()
    specs = {
        "REQ": ("req-project", "req"),
        "UI": ("ui-project", "ui"),
        "ARCH": ("arch-project", "arch"),
        "CODE": ("code-project", "code"),
    }
    if stage not in specs:
        raise ValueError("stage must be REQ, UI, ARCH, or CODE")
    guard_project(config, slug)
    template_name, path_key = specs[stage]
    source = config.resolve(config.data["templates_root"]) / template_name
    target = config.resolve(config.configured_project_paths(slug)[path_key], slug=slug)
    if target.exists() and not force:
        return {"slug": slug, "stage": stage, "target": str(target), "created": False, "skipped": True}
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".scaffold-{slug}-{stage.lower()}-", dir=target.parent))
    try:
        shutil.rmtree(temporary)
        shutil.copytree(source, temporary)
        for path in temporary.rglob("*"):
            if path.is_file() and path.suffix.lower() in {".md", ".json", ".yaml", ".yml", ".csv", ".ps1"}:
                replace_text_atomic(path, {"{{project-slug}}": slug, "{{slug}}": slug, "{{项目名称}}": slug})
        if target.exists():
            backup = target.with_name(f".{target.name}.old")
            if backup.exists():
                shutil.rmtree(backup)
            target.replace(backup)
            try:
                temporary.replace(target)
            except Exception:
                backup.replace(target)
                raise
            shutil.rmtree(backup)
        else:
            temporary.replace(target)
    finally:
        shutil.rmtree(temporary, ignore_errors=True)
    return {"slug": slug, "stage": stage, "target": str(target), "created": True, "skipped": False}


def validate_paths(config: Config, slug: str) -> dict[str, Any]:
    state = load_state(config, slug)
    results = []
    for stage, uri in state["paths"].items():
        if uri is None:
            results.append({"stage": stage.upper(), "uri": None, "path": None, "exists": False, "optional": True})
            continue
        path = config.resolve(uri, slug=slug)
        results.append({"stage": stage.upper(), "uri": uri, "path": str(path), "exists": path.exists(), "optional": False})
    return {"slug": slug, "valid": all(row["exists"] or row["optional"] for row in results), "paths": results, "human_gate_approved": False}


def validate_schema(config: Config, schema_name: str, instance: Path) -> dict[str, Any]:
    schema_path = Path(schema_name)
    if not schema_path.is_absolute():
        schema_path = config.root / "schemas" / schema_name
    schema = read_json(schema_path)
    if instance.suffix.lower() in {".yaml", ".yml"}:
        value = yaml.safe_load(instance.read_text(encoding="utf-8-sig"))
    else:
        value = read_json(instance)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = [
        f"{'/'.join(map(str, error.absolute_path)) or '<root>'}: {error.message}"
        for error in sorted(validator.iter_errors(value), key=lambda item: list(item.absolute_path))
    ]
    return {"schema": str(schema_path), "instance": str(instance), "valid": not errors, "errors": errors, "human_gate_approved": False}


def validate_docs(path: Path) -> dict[str, Any]:
    errors: list[str] = []
    registry = path / "registry.md"
    required = {"Type", "Latest output", "Style card", "Sources", "Source revision", "Output revision", "Stale"}
    if not registry.is_file():
        errors.append("Missing registry.md")
    else:
        rows = _markdown_table(registry)
        if not rows:
            errors.append("registry.md has no parseable table")
        else:
            errors.extend(f"registry column missing: {name}" for name in sorted(required - set(rows[0])))
            for row in rows:
                if not row.get("Type"):
                    continue
                for field in ("Latest output", "Style card"):
                    relative = row.get(field, "")
                    if not relative or not (path / relative).exists():
                        errors.append(f"{row['Type']}: {field} missing: {relative}")
                if row.get("Stale") not in {"yes", "no"}:
                    errors.append(f"{row['Type']}: Stale must be yes or no")
    return {"validator": "docs", "docs_path": str(path), "artifact_evidence_valid": not errors, "errors": errors, "human_gate_approved": False}


def _markdown_table(path: Path) -> list[dict[str, str]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    for index, line in enumerate(lines):
        if line.lstrip().startswith("|") and index + 1 < len(lines) and "---" in lines[index + 1]:
            headers = [cell.strip() for cell in line.strip().strip("|").split("|")]
            result = []
            for row in lines[index + 2:]:
                if not row.lstrip().startswith("|"):
                    break
                values = [cell.strip() for cell in row.strip().strip("|").split("|")]
                if len(values) == len(headers):
                    result.append(dict(zip(headers, values)))
            return result
    return []


def validate_intake(config: Config, intake: Path) -> dict[str, Any]:
    errors: list[str] = []
    manifest_path, ledger_path = intake / "manifest.json", intake / "reading-ledger.csv"
    if not manifest_path.is_file():
        errors.append("Missing manifest.json")
        manifest = None
    else:
        manifest = read_json(manifest_path)
        report = validate_schema(config, "intake-manifest.schema.json", manifest_path)
        errors.extend(report["errors"])
    rows: list[dict[str, str]] = []
    if not ledger_path.is_file():
        errors.append("Missing reading-ledger.csv")
    else:
        with ledger_path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    pending = sum(row.get("status") == "pending" for row in rows)
    if pending:
        errors.append(f"Eligible pending ledger rows: {pending}")
    if manifest:
        if manifest.get("scan", {}).get("is_truncated"):
            errors.append("Manifest reports a truncated scan")
        if manifest.get("eligible_pending") != pending:
            errors.append("Manifest eligible_pending does not match ledger")
    for relative in ("actual-state.md", "evidence-map.md", "stage-gap-matrix.md", "supplement-plan.md"):
        candidate = intake / relative
        if not candidate.is_file():
            errors.append(f"Missing {relative}")
        elif "INTAKE_PLACEHOLDER" in candidate.read_text(encoding="utf-8-sig"):
            errors.append(f"{relative} still contains placeholder content")
    for stage in ("REQ", "UI", "ARCH", "TEST", "CODE", "DOCS"):
        if not (intake / "handoffs" / f"{stage}.md").is_file():
            errors.append(f"Missing handoffs/{stage}.md")
    return {"validator": "intake", "intake_path": str(intake), "artifact_evidence_valid": not errors, "ledger": {"rows": len(rows), "eligible_pending": pending}, "errors": errors, "human_gate_approved": False}


def inventory(config: Config, slug: str, source: Path, max_files: int = 100000, max_bytes: int = 10 * 1024**3, max_file_bytes: int = 100 * 1024**2) -> dict[str, Any]:
    guard_project(config, slug)
    source = source.expanduser().resolve()
    if not source.is_dir():
        raise ValueError("external source must be an existing directory")
    project = config.project_root(slug)
    intake = project / "intake"
    intake.mkdir(parents=True, exist_ok=True)
    excluded_names = {".git", "node_modules", "dist", "build", ".venv", "venv", "__pycache__", ".pytest_cache"}
    sensitive = re.compile(r"(?i)(^|/)(\.env(?:\..+)?|credentials.*|secrets?.*|id_rsa|id_ed25519)$")
    rows: list[dict[str, Any]] = []
    excluded: list[dict[str, str]] = []
    used = 0
    truncated = False
    stamp = utc_now()
    for directory, dirs, files in os.walk(source, followlinks=False):
        relative_dir = Path(directory).relative_to(source)
        kept = []
        for name in dirs:
            relative = (relative_dir / name).as_posix()
            if name in excluded_names or (Path(directory) / name).is_symlink():
                excluded.append({"path": relative, "reason": "generated/dependency/cache or symlink directory"})
            else:
                kept.append(name)
        dirs[:] = kept
        for name in files:
            if len(rows) >= max_files:
                truncated = True
                break
            path = Path(directory) / name
            relative = path.relative_to(source).as_posix()
            stat = path.stat()
            is_sensitive = bool(sensitive.search(relative))
            if is_sensitive:
                status, category, reason, digest = "skipped-sensitive", "sensitive", "potential secret; not read or hashed", ""
            elif stat.st_size > max_file_bytes or used + stat.st_size > max_bytes:
                status, category, reason, digest = "unsupported", "oversized", "byte limit exceeded; not read or hashed", ""
            else:
                used += stat.st_size
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                text_like = path.suffix.lower() in {".md", ".txt", ".json", ".yaml", ".yml", ".toml", ".py", ".js", ".ts", ".tsx", ".ps1", ".sh", ".csv"}
                status, category, reason = ("pending", "text/source", "eligible file") if text_like else ("indexed", "binary", "metadata retained")
            rows.append({
                "path": relative, "bytes": stat.st_size,
                "modified_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat().replace("+00:00", "Z"),
                "extension": path.suffix.lower(), "sha256": digest, "class": category,
                "status": status, "reason": reason, "evidence_ids": "",
                "read_at": "" if status == "pending" else stamp,
            })
        if truncated:
            break
    counts = Counter(row["status"] for row in rows)
    manifest = {
        "version": 2, "slug": slug, "source_path": str(source), "generated_at": stamp,
        "limits": {"max_files": max_files, "max_bytes": max_bytes, "max_file_bytes": max_file_bytes},
        "scan": {"is_truncated": truncated, "truncation_reason": "MaxFiles reached" if truncated else "", "inventory_bytes": used},
        "eligible_pending": counts["pending"], "removed_at_source": 0, "total_ledger_files": len(rows),
        "statuses": dict(counts), "excluded_directories": excluded,
    }
    atomic_write_json(intake / "manifest.json", manifest)
    _atomic_csv(intake / "reading-ledger.csv", rows)
    atomic_write_text(intake / "SOURCE.md", f"# Historical project source\n\n| Field | Value |\n|-------|-------|\n| Slug | {slug} |\n| Source path | `{source}` |\n| Inventory time (UTC) | {stamp} |\n")
    return {"slug": slug, "intake": str(intake), "ledger_files": len(rows), "eligible_pending": counts["pending"], "truncated": truncated, "human_gate_approved": False}


def _atomic_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    fields = ("path", "bytes", "modified_utc", "extension", "sha256", "class", "status", "reason", "evidence_ids", "read_at")
    handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="", delete=False, dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    temp = Path(handle.name)
    try:
        with handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            writer.writerows(sorted(rows, key=lambda row: row["path"]))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def validate_supplement(config: Config, slug: str, target_stage: str | None = None) -> dict[str, Any]:
    intake = config.project_root(slug) / "intake"
    plan, evidence = intake / "supplement-plan.md", intake / "evidence-map.md"
    errors: list[str] = []
    if not plan.is_file() or not evidence.is_file():
        errors.append("supplement-plan.md and evidence-map.md are required")
        rows = []
    else:
        rows = _markdown_table(plan)
        ids = set(re.findall(r"(?m)^\|\s*((?:E|BACKFILL)-[A-Za-z0-9_-]+)\s*\|", evidence.read_text(encoding="utf-8-sig")))
        for row in rows:
            label = row.get("ID", "<missing>")
            if not re.fullmatch(r"SUP-[A-Za-z0-9_-]+", label):
                errors.append(f"{label}: invalid supplement ID")
            if row.get("status") not in {"proposed", "confirmed", "applied", "waived"}:
                errors.append(f"{label}: invalid status")
            refs = set(filter(None, re.split(r"[,; ]+", row.get("evidence_ids", ""))))
            if not refs or not refs <= ids:
                errors.append(f"{label}: undefined or missing evidence IDs")
            if target_stage and row.get("owner_stage") == target_stage and row.get("status") not in {"applied", "waived"}:
                errors.append(f"{label}: must be applied or waived before {target_stage}")
    return {"validator": "supplement", "slug": slug, "target_stage": target_stage, "action_count": len(rows), "provenance_valid": not errors, "errors": errors, "human_gate_approved": False}


def run_regression(config: Config, slug: str, mode: str = "full") -> dict[str, Any]:
    if mode not in {"full", "code-only", "product-only"}:
        raise ValueError("mode must be full, code-only, or product-only")
    state = guard_project(config, slug)
    test_root = config.project_root(slug) / "test"
    runtime_path = test_root / "runtime.yaml"
    if not runtime_path.is_file():
        raise FileNotFoundError(f"portable runtime config missing: {runtime_path}")
    runtime = yaml.safe_load(runtime_path.read_text(encoding="utf-8-sig")) or {}
    started = utc_now()
    failures: list[str] = []
    logs = test_root / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    suites: dict[str, dict[str, Any]] = {}
    for name, enabled in (("code", mode != "product-only"), ("product", mode != "code-only")):
        log = logs / f"{name}.txt"
        command = runtime.get(f"{name}_test_cmd")
        suite = {"command": command, "exit_code": None, "passed": 0, "failed": 0, "skipped": 0, "status": "skipped", "log": str(log)}
        if name == "product":
            suite["report"] = str(logs / "product-report.json")
        if enabled:
            if not command:
                suite.update(exit_code=2, failed=1, status="failed")
                failures.append(f"{name}: command is unconfigured")
            else:
                cwd_uri = runtime.get(f"{name}_root") or ("project://test" if name == "product" else state["paths"]["code"])
                cwd = config.resolve(cwd_uri, slug=slug)
                completed = subprocess.run(command, cwd=cwd, shell=True, text=True, capture_output=True)
                atomic_write_text(log, completed.stdout + completed.stderr)
                suite["exit_code"] = completed.returncode
                suite["status"] = "passed" if completed.returncode == 0 else "failed"
                suite["passed" if completed.returncode == 0 else "failed"] = 1
                if completed.returncode:
                    failures.append(f"{name}: exit {completed.returncode}")
        suites[name] = suite
    finished = utc_now()
    last_code = state["timestamps"].get("last_code_change_at")
    fresh = bool(last_code and _time(started) >= _time(last_code))
    if not last_code:
        failures.append("freshness: last_code_change_at unavailable")
    payload = {
        "schema_version": 1, "slug": slug, "mode": mode, "started_at": started, "finished_at": finished,
        "access_url": runtime.get("access_url"),
        "freshness": {"source": "state.json", "last_code_change_at": last_code, "regression_started_after_code_change": fresh if last_code else None},
        "commands": [suite["command"] for suite in suites.values() if suite["command"]],
        "code": suites["code"], "product": suites["product"],
        "lifecycle": {"start_command": None, "stop_command": None, "health_url": runtime.get("health_url"), "startup_timeout_seconds": int(runtime.get("startup_timeout_seconds", 60)), "started": False, "healthy": None, "stop_exit_code": None},
        "failures": failures, "warnings": [] if mode == "full" else [f"mode={mode} PASS is not full regression evidence"],
        "overall": "FAIL" if failures else "PASS",
        "logs": {key: str(logs / filename) for key, filename in {
            "directory": ".", "code": "code.txt", "product": "product.txt", "product_report": "product-report.json",
            "app_start": "app-start.txt", "app_start_error": "app-start-error.txt", "app_stop": "app-stop.txt",
        }.items()},
    }
    payload["logs"]["directory"] = str(logs)
    report = validate_schema(config, "last-run.schema.json", _write_temp_json(test_root, payload))
    (test_root / ".last-run.validate.json").unlink(missing_ok=True)
    if not report["valid"]:
        raise RuntimeError("last-run schema validation failed: " + "; ".join(report["errors"]))
    atomic_write_json(test_root / "last-run.json", payload)
    full_pass = mode == "full" and payload["overall"] == "PASS" and all(suites[name]["status"] == "passed" for name in suites)
    state["regression"] = {"state": "passed" if full_pass else ("failed" if failures else "partial"), "mode": mode, "last_run": "project://test/last-run.json", "updated_at": finished}
    if full_pass:
        state["timestamps"]["last_regression_at"] = finished
    state["timestamps"]["updated_at"] = finished
    write_state(config, slug, state)
    return payload


def _write_temp_json(root: Path, value: Any) -> Path:
    path = root / ".last-run.validate.json"
    atomic_write_json(path, value)
    return path


def _time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def session_context(config: Config, slug: str | None = None) -> dict[str, Any]:
    selected = slug or active_slug(config)
    if not selected:
        return {"bundle_root": str(config.root), "active_slug": None, "project": None}
    state = load_state(config, selected)
    return {
        "bundle_root": str(config.root),
        "active_slug": selected,
        "project_root": str(config.project_root(selected)),
        "lifecycle": state["lifecycle"],
        "current_stage": state["current_stage"],
        "mode": state["mode"],
        "blocked": state["blocked"],
        "paths": {key: (str(config.resolve(uri, slug=selected)) if uri else None) for key, uri in state["paths"].items()},
        "human_gate_approved": False,
    }


def static_validate(config: Config) -> dict[str, Any]:
    command = [os.environ.get("PYTHON", os.sys.executable), str(config.root / "scripts" / "validate-static-contracts.py")]
    completed = subprocess.run(command, cwd=config.root, text=True, capture_output=True)
    try:
        report = json.loads(completed.stdout)
    except json.JSONDecodeError:
        report = {"valid": False, "errors": [completed.stderr or completed.stdout]}
    report["exit_code"] = completed.returncode
    return report
