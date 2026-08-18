"""Argument parser for the portable SOP command line."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Callable

from .config import Config
from .governance import (
    GATES,
    RESET_MATRIX,
    record_cancellation,
    record_gate,
    reset_gates,
    set_lifecycle,
    touch_code,
    write_governance,
)
from .operations import (
    inventory,
    run_regression,
    scaffold,
    session_context,
    static_validate,
    validate_docs,
    validate_intake,
    validate_paths,
    validate_schema,
    validate_supplement,
)
from .state import activate, active_slug, list_projects, new_project


def _json(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def _selected(config: Config, explicit: str | None) -> str:
    slug = explicit or active_slug(config)
    if not slug:
        raise ValueError("no slug supplied and projects/CURRENT.md is unset")
    return slug


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sop", description="Portable AI project SOP bundle CLI")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="bundle root containing sop.yaml")
    top = parser.add_subparsers(dest="group", required=True)

    project = top.add_parser("project")
    sub = project.add_subparsers(dest="action", required=True)
    command = sub.add_parser("new")
    command.add_argument("slug")
    command.add_argument("--origin", choices=("new", "historical"), default="new")
    command.add_argument("--no-activate", action="store_true")
    command = sub.add_parser("activate")
    command.add_argument("slug")
    sub.add_parser("list")

    paths = top.add_parser("paths")
    sub = paths.add_subparsers(dest="action", required=True)
    command = sub.add_parser("resolve")
    command.add_argument("uri")
    command.add_argument("--slug")
    command.add_argument("--external", action="store_true")
    command = sub.add_parser("validate")
    command.add_argument("--slug")

    command = top.add_parser("scaffold")
    command.add_argument("stage", choices=("REQ", "UI", "ARCH", "CODE"))
    command.add_argument("--slug")
    command.add_argument("--force", action="store_true")

    gate = top.add_parser("gate")
    sub = gate.add_subparsers(dest="action", required=True)
    command = sub.add_parser("record")
    command.add_argument("gate_id", choices=GATES)
    command.add_argument("decision", choices=("approved", "rejected", "waived"))
    command.add_argument("--slug")
    _confirmation_args(command)
    command.add_argument("--evidence", default="")
    command.add_argument("--scope", default="")
    command.add_argument("--waiver-reason", default="")
    command.add_argument("--risk-owner", default="")
    command.add_argument("--expiry", default="")
    command = sub.add_parser("reset")
    command.add_argument("change_class", choices=RESET_MATRIX)
    command.add_argument("--slug")
    _confirmation_args(command)
    command.add_argument("--reason", required=True)
    command.add_argument("--target-status", choices=("in_progress", "blocked"), default="in_progress")
    command = sub.add_parser("touch-code")
    command.add_argument("--slug")
    _confirmation_args(command)
    command.add_argument("--reason", required=True)
    command.add_argument("--timestamp")

    lifecycle = top.add_parser("lifecycle")
    sub = lifecycle.add_subparsers(dest="action", required=True)
    command = sub.add_parser("set")
    command.add_argument("lifecycle", choices=("active", "paused", "cancelled", "archived"))
    command.add_argument("--slug")
    _confirmation_args(command)
    command.add_argument("--reason", default="")
    command = sub.add_parser("cancel")
    command.add_argument("--slug")
    _confirmation_args(command)
    command.add_argument("--reason", required=True)

    command = top.add_parser("governance")
    sub = command.add_subparsers(dest="action", required=True)
    write = sub.add_parser("write")
    write.add_argument("--slug")
    write.add_argument("--data-classification", choices=("public", "internal", "confidential", "restricted"))
    write.add_argument("--regulated-data", action="append")
    write.add_argument("--residency")
    write.add_argument("--retention")
    write.add_argument("--access-audit")
    write.add_argument("--third-party-transfer")
    write.add_argument("--compliance-owner")
    write.add_argument("--ui-input-mode", choices=("complete", "partial", "none"))

    docs = top.add_parser("docs")
    sub = docs.add_subparsers(dest="action", required=True)
    command = sub.add_parser("validate")
    command.add_argument("path", nargs="?", type=Path)
    command.add_argument("--slug")

    session = top.add_parser("session")
    sub = session.add_subparsers(dest="action", required=True)
    command = sub.add_parser("context")
    command.add_argument("--slug")

    schema = top.add_parser("schema")
    sub = schema.add_subparsers(dest="action", required=True)
    command = sub.add_parser("validate")
    command.add_argument("schema")
    command.add_argument("instance", type=Path)

    static = top.add_parser("static")
    static.add_subparsers(dest="action", required=True).add_parser("validate")

    intake_parser = top.add_parser("intake")
    sub = intake_parser.add_subparsers(dest="action", required=True)
    command = sub.add_parser("validate")
    command.add_argument("path", nargs="?", type=Path)
    command.add_argument("--slug")
    command = sub.add_parser("inventory")
    command.add_argument("source", type=Path)
    command.add_argument("--slug")
    command.add_argument("--max-files", type=int, default=100000)
    command.add_argument("--max-bytes", type=int, default=10 * 1024**3)
    command.add_argument("--max-file-bytes", type=int, default=100 * 1024**2)
    command = sub.add_parser("supplement")
    command.add_argument("--slug")
    command.add_argument("--target-stage", choices=("INTAKE", "REQ", "UI", "ARCH", "TEST", "CODE", "DOCS"))

    test = top.add_parser("test")
    sub = test.add_subparsers(dest="action", required=True)
    command = sub.add_parser("regression")
    command.add_argument("--slug")
    command.add_argument("--mode", choices=("full", "code-only", "product-only"), default="full")
    return parser


def _confirmation_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--decision-maker", required=True)
    parser.add_argument("--confirmation-quote", required=True)


def dispatch(args: argparse.Namespace, config: Config) -> Any:
    group, action = args.group, getattr(args, "action", None)
    if group == "project":
        if action == "new":
            return new_project(config, args.slug, args.origin, not args.no_activate)
        if action == "activate":
            return activate(config, args.slug)
        return list_projects(config)
    if group == "paths":
        if action == "resolve":
            slug = args.slug or active_slug(config)
            return {"input": args.uri, "resolved": str(config.resolve(args.uri, slug=slug, allow_external=args.external))}
        return validate_paths(config, _selected(config, args.slug))
    if group == "scaffold":
        return scaffold(config, _selected(config, args.slug), args.stage, args.force)
    if group == "gate":
        slug = _selected(config, args.slug)
        if action == "record":
            return record_gate(config, slug, args.gate_id, args.decision, args.decision_maker, args.confirmation_quote, evidence=args.evidence, scope=args.scope, waiver_reason=args.waiver_reason, risk_owner=args.risk_owner, expiry=args.expiry)
        if action == "reset":
            return reset_gates(config, slug, args.change_class, args.decision_maker, args.confirmation_quote, args.reason, target_status=args.target_status)
        return touch_code(config, slug, args.decision_maker, args.confirmation_quote, args.reason, args.timestamp)
    if group == "lifecycle":
        slug = _selected(config, args.slug)
        if action == "set":
            return set_lifecycle(config, slug, args.lifecycle, args.decision_maker, args.confirmation_quote, args.reason)
        return record_cancellation(config, slug, args.decision_maker, args.confirmation_quote, args.reason)
    if group == "governance":
        slug = _selected(config, args.slug)
        names = ("data_classification", "regulated_data", "residency", "retention", "access_audit", "third_party_transfer", "compliance_owner", "ui_input_mode")
        updates = {name: getattr(args, name) for name in names if getattr(args, name) is not None}
        return write_governance(config, slug, updates)
    if group == "docs":
        slug = args.slug or active_slug(config)
        path = args.path or (config.project_root(_selected(config, slug)) / "docs")
        return validate_docs(path.resolve())
    if group == "session":
        return session_context(config, args.slug)
    if group == "schema":
        return validate_schema(config, args.schema, args.instance.resolve())
    if group == "static":
        return static_validate(config)
    if group == "intake":
        slug = args.slug or active_slug(config)
        if action == "validate":
            path = args.path or (config.project_root(_selected(config, slug)) / "intake")
            return validate_intake(config, path.resolve())
        if action == "inventory":
            return inventory(config, _selected(config, slug), args.source, args.max_files, args.max_bytes, args.max_file_bytes)
        return validate_supplement(config, _selected(config, slug), args.target_stage)
    if group == "test":
        return run_regression(config, _selected(config, args.slug), args.mode)
    raise RuntimeError(f"unhandled command: {group} {action}")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        config = Config.load(args.root)
        result = dispatch(args, config)
        _json(result)
        if isinstance(result, dict) and (
            result.get("valid") is False
            or result.get("artifact_evidence_valid") is False
            or result.get("provenance_valid") is False
            or result.get("overall") == "FAIL"
        ):
            return 1
        return 0
    except Exception as exc:
        print(json.dumps({"error": str(exc), "type": type(exc).__name__}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
