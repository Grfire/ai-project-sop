#!/usr/bin/env python3
"""Validate repository Skill, Markdown-link, and project-hook contracts."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

import yaml
from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
SKILLS_ROOT = ROOT / ".cursor" / "skills"
ORCHESTRATOR = (SKILLS_ROOT / "sop-orchestrator" / "SKILL.md").resolve()


def strip_fenced_code(text: str) -> str:
    return re.sub(r"```.*?```|~~~.*?~~~", "", text, flags=re.DOTALL)


def validate_skills(errors: list[str]) -> int:
    skills = sorted(SKILLS_ROOT.rglob("SKILL.md"))
    auto_entries: list[Path] = []
    for path in skills:
        text = path.read_text(encoding="utf-8-sig")
        if not text.startswith("---"):
            errors.append(f"{path.relative_to(ROOT)}: missing YAML frontmatter")
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            errors.append(f"{path.relative_to(ROOT)}: unterminated YAML frontmatter")
            continue
        try:
            metadata = yaml.safe_load(parts[1])
        except yaml.YAMLError as exc:
            errors.append(f"{path.relative_to(ROOT)}: invalid YAML frontmatter: {exc}")
            continue
        if not isinstance(metadata, dict):
            errors.append(f"{path.relative_to(ROOT)}: frontmatter must be a mapping")
            continue
        if not metadata.get("name"):
            errors.append(f"{path.relative_to(ROOT)}: frontmatter.name is required")
        if not metadata.get("description"):
            errors.append(f"{path.relative_to(ROOT)}: frontmatter.description is required")
        if metadata.get("disable-model-invocation") is not True:
            auto_entries.append(path.resolve())

    if auto_entries != [ORCHESTRATOR]:
        rendered = ", ".join(str(path.relative_to(ROOT)) for path in auto_entries) or "<none>"
        errors.append(
            "Exactly one Skill may be an auto-entry and it must be "
            f".cursor/skills/sop-orchestrator/SKILL.md; found: {rendered}"
        )
    return len(skills)


def validate_markdown_links(errors: list[str]) -> int:
    checked = 0
    link_pattern = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^)]+)\)")
    for path in sorted(ROOT.rglob("*.md")):
        if "node_modules" in path.parts:
            continue
        text = strip_fenced_code(path.read_text(encoding="utf-8-sig", errors="replace"))
        for raw_target in link_pattern.findall(text):
            target = raw_target.strip().split()[0].strip("<>")
            if (
                not target
                or target.startswith(("#", "http://", "https://", "mailto:"))
                or "{{" in target
                or "<slug>" in target
                or re.match(r"^[A-Za-z]:[/\\]", target)
            ):
                continue
            decoded = unquote(target.split("#", 1)[0])
            if not decoded:
                continue
            checked += 1
            resolved = (path.parent / decoded).resolve()
            if not resolved.exists():
                errors.append(
                    f"{path.relative_to(ROOT)}: broken local link '{target}'"
                )
    return checked


def validate_project_hooks(errors: list[str]) -> int:
    hooks_path = ROOT / ".cursor" / "hooks.json"
    try:
        payload = json.loads(hooks_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f".cursor/hooks.json: unreadable or invalid JSON: {exc}")
        return 0

    checked = 0
    expected = "node .cursor/hooks/session-start.mjs"
    for definitions in payload.get("hooks", {}).values():
        for definition in definitions:
            command = definition.get("command", "")
            if command != expected:
                errors.append(
                    f".cursor/hooks.json: hook command must be '{expected}', found '{command}'"
                )
            for match in re.findall(r"(?:^|\s)(\.cursor[/\\]hooks[/\\][^\s\"']+)", command):
                checked += 1
                target = (ROOT / match).resolve()
                if not target.is_file():
                    errors.append(
                        f".cursor/hooks.json: project-relative hook target missing: {match}"
                    )
    if checked == 0:
        errors.append(
            ".cursor/hooks.json: no project-relative .cursor/hooks/* command target found"
        )
    return checked


def validate_portable_config(errors: list[str]) -> int:
    try:
        config = yaml.safe_load((ROOT / "sop.yaml").read_text(encoding="utf-8-sig"))
        schema = json.loads(
            (ROOT / "schemas" / "sop-config.schema.json").read_text(encoding="utf-8-sig")
        )
    except (OSError, json.JSONDecodeError, yaml.YAMLError) as exc:
        errors.append(f"portable config unreadable: {exc}")
        return 0
    for error in Draft202012Validator(schema).iter_errors(config):
        errors.append(f"sop.yaml: {error.message}")
    portable_sections = {
        key: config.get(key)
        for key in (
            "bundle_root",
            "projects_root",
            "templates_root",
            "schemas_root",
            "workspaces",
            "project_paths",
        )
    }
    for path, value in _walk_values(portable_sections):
        if isinstance(value, str) and not value.startswith(("bundle://", "project://")):
            errors.append(f"sop.yaml: active path {path} is not a portable URI: {value}")
    return 1


def _walk_values(value: object, prefix: str = ""):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from _walk_values(child, f"{prefix}.{key}".strip("."))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _walk_values(child, f"{prefix}[{index}]")
    else:
        yield prefix, value


def validate_no_active_legacy_paths(errors: list[str]) -> int:
    candidates = [ROOT / "AGENTS.md", ROOT / "README.md"]
    candidates.extend((ROOT / ".cursor" / "skills").rglob("*"))
    candidates.extend((ROOT / "vendor-templates").rglob("*"))
    candidates.extend((ROOT / "projects" / "_template").rglob("*"))
    candidates.extend((ROOT / "docs").rglob("*.md"))
    checked = 0
    for path in sorted(set(candidates)):
        if (
            not path.is_file()
            or path == ROOT / "docs" / "adr" / "0004-portable-bundle-and-python-core.md"
            or path.suffix.lower() not in {".md", ".yaml", ".yml", ".json"}
        ):
            continue
        checked += 1
        text = path.read_text(encoding="utf-8-sig", errors="replace")
        if re.search(r"(?i)\bE:[/\\]workspace\b", text):
            errors.append(
                f"{path.relative_to(ROOT)}: active docs/templates must use sop.yaml/state paths"
            )
    return checked


def main() -> int:
    errors: list[str] = []
    report = {
        "validator": "validate-static-contracts",
        "skills_checked": validate_skills(errors),
        "markdown_links_checked": validate_markdown_links(errors),
        "hook_targets_checked": validate_project_hooks(errors),
        "portable_configs_checked": validate_portable_config(errors),
        "legacy_path_docs_checked": validate_no_active_legacy_paths(errors),
        "valid": not errors,
        "errors": errors,
        "human_gate_approved": False,
        "note": "Static repository evidence only; conversational gates remain authoritative.",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
