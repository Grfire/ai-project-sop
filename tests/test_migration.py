from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest
import yaml

import sop.migration as migration_module
from sop.migration import migration_apply, migration_plan
from sop.state import load_state, new_project


def _legacy_project(bundle, tmp_path: Path, slug: str) -> Path:
    legacy = tmp_path / "legacy"
    sources = {
        "governance": legacy / "ai-project-sop" / "projects" / slug,
        "req": legacy / "ai_req_analysis" / "projects" / slug,
        "ui": legacy / "ai-font-design" / "projects" / slug,
        "arch": legacy / "ai_architecture_design" / "projects" / slug,
        "code": legacy / "ai_code" / "project" / slug,
    }
    for path in sources.values():
        path.mkdir(parents=True)
        (path / "kept.txt").write_text("kept", encoding="utf-8")

    template = json.loads(
        (bundle.projects_root / "_template" / "state.json")
        .read_text(encoding="utf-8")
        .replace("{{project-slug}}", slug)
    )
    template["approval_refs"] = {"REQ_SIGNOFF": "APR-001"}
    template["stage_status"]["REQ"] = "approved"
    ppt = legacy / "ai_pptx" / "projects" / f"{slug}_ppt169_20260818"
    ppt.mkdir(parents=True)
    (ppt / "deck.pptx").write_bytes(b"ppt")
    template["paths"] = {
        "intake": f"E:/workspace/ai-project-sop/projects/{slug}/intake",
        "req": f"E:/workspace/ai_req_analysis/projects/{slug}",
        "ppt_path": f"E:/workspace/ai_pptx/projects/{ppt.name}",
        "ui": f"E:/workspace/ai-font-design/projects/{slug}",
        "arch": f"E:/workspace/ai_architecture_design/projects/{slug}",
        "code": f"E:/workspace/ai_code/project/{slug}",
        "test": f"E:/workspace/ai-project-sop/projects/{slug}/test",
        "docs": f"E:/workspace/ai-project-sop/projects/{slug}/docs",
    }
    governance = sources["governance"]
    (governance / "state.json").write_text(json.dumps(template), encoding="utf-8")
    (governance / "APPROVALS.md").write_text("### APR-001\n", encoding="utf-8")
    (governance / "DECISIONS.md").write_text("# decisions\n", encoding="utf-8")
    (governance / "SOP.md").write_text(
        f"REQ `E:/workspace/ai_req_analysis/projects/{slug}`", encoding="utf-8"
    )
    test = governance / "test"
    test.mkdir()
    (test / "catalog.yaml").write_text(
        yaml.safe_dump({"version": 1, "slug": slug, "source": {}}),
        encoding="utf-8",
    )
    (test / "runtime.yaml").write_text(
        yaml.safe_dump({"code_root": f"E:/workspace/ai_code/project/{slug}"}),
        encoding="utf-8",
    )
    (sources["code"] / "node_modules").mkdir()
    (sources["code"] / "node_modules" / "ignored.js").write_text("x", encoding="utf-8")
    (sources["req"] / ".env").write_text("SECRET=x", encoding="utf-8")
    return legacy


def test_migration_plan_and_apply_preserve_governance(bundle, tmp_path: Path):
    slug = "legacy-app"
    legacy = _legacy_project(bundle, tmp_path, slug)
    plan = migration_plan(bundle, slug, legacy)
    assert plan["ready"] is True
    assert plan["mode"] == "dry-run"
    assert not bundle.project_root(slug).exists()

    dry_run = migration_apply(bundle, slug, legacy)
    assert dry_run["mode"] == "dry-run"
    assert not bundle.project_root(slug).exists()

    result = migration_apply(bundle, slug, legacy, execute=True)
    assert result["applied"] is True
    state = load_state(bundle, slug)
    assert state["approval_refs"] == {"REQ_SIGNOFF": "APR-001"}
    assert state["paths"]["req"] == f"bundle://workspaces/req/projects/{slug}"
    assert state["paths"]["ppt_path"] == (
        f"bundle://workspaces/ppt/projects/{slug}_ppt169_20260818"
    )
    assert (bundle.project_root(slug) / "APPROVALS.md").is_file()
    assert not (bundle.resolve(state["paths"]["req"], slug=slug) / ".env").exists()
    assert not (bundle.resolve(state["paths"]["code"], slug=slug) / "node_modules").exists()
    assert (bundle.resolve(state["paths"]["ppt_path"], slug=slug) / "deck.pptx").is_file()
    runtime = yaml.safe_load(
        (bundle.project_root(slug) / "test" / "runtime.yaml").read_text(encoding="utf-8")
    )
    assert runtime["code_root"] == state["paths"]["code"]
    catalog = yaml.safe_load(
        (bundle.project_root(slug) / "test" / "catalog.yaml").read_text(encoding="utf-8")
    )
    assert catalog["source"]["prd"].startswith("bundle://")


def _in_place_project(bundle, tmp_path: Path, slug: str) -> dict[str, Path]:
    new_project(bundle, slug, set_active=False)
    governance = bundle.project_root(slug)
    siblings = tmp_path / "old-siblings"
    sources = {
        "governance": governance,
        "req": siblings / "req" / slug,
        "ui": siblings / "ui" / slug,
        "arch": siblings / "arch" / slug,
        "code": siblings / "code" / slug,
    }
    for key, path in sources.items():
        if key != "governance":
            path.mkdir(parents=True)
            (path / f"{key}.txt").write_text(key, encoding="utf-8")

    ppt = siblings / "ppt" / f"{slug}_ppt169_20260818"
    ppt.mkdir(parents=True)
    (ppt / "deck.pptx").write_bytes(b"ppt")
    sources["ppt"] = ppt

    state_path = governance / "state.json"
    state = json.loads(state_path.read_text(encoding="utf-8"))
    state["approval_refs"] = {"REQ_SIGNOFF": "APR-001"}
    state["stage_status"]["REQ"] = "approved"
    state["paths"] = {
        "intake": str(governance / "intake"),
        "req": str(sources["req"]),
        "ppt_path": str(ppt),
        "ui": str(sources["ui"]),
        "arch": str(sources["arch"]),
        "code": str(sources["code"]),
        "test": str(governance / "test"),
        "docs": str(governance / "docs"),
    }
    state_path.write_text(json.dumps(state), encoding="utf-8")
    (governance / "APPROVALS.md").write_text("### APR-001\n", encoding="utf-8")
    (governance / "DECISIONS.md").write_text("# keep decisions\n", encoding="utf-8")
    (governance / "intake").mkdir(exist_ok=True)
    (governance / "intake" / "keep.md").write_text("intake", encoding="utf-8")
    (governance / "docs").mkdir(exist_ok=True)
    (governance / "docs" / "keep.md").write_text("docs", encoding="utf-8")
    (governance / "test" / "keep.txt").write_text("test-extra", encoding="utf-8")
    (governance / "SOP.md").write_text(
        f"REQ `{sources['req']}`", encoding="utf-8"
    )
    (governance / "test" / "catalog.yaml").write_text(
        yaml.safe_dump({"version": 1, "slug": slug, "source": {}}),
        encoding="utf-8",
    )
    (governance / "test" / "runtime.yaml").write_text(
        yaml.safe_dump({"code_root": str(sources["code"])}),
        encoding="utf-8",
    )
    bundle.data["migration"]["legacy_sources"] = {
        key: str(path.parent / "{slug}")
        for key, path in sources.items()
        if key != "ppt"
    }
    return sources


def test_in_place_governance_updates_only_metadata(bundle, tmp_path: Path):
    slug = "in-place-app"
    sources = _in_place_project(bundle, tmp_path, slug)
    governance = sources["governance"]
    plan = migration_plan(bundle, slug)
    governance_row = next(row for row in plan["sources"] if row["stage"] == "governance")
    assert plan["ready"] is True
    assert governance_row["action"] == "update-in-place"

    result = migration_apply(bundle, slug, execute=True)
    assert result["governance_action"] == "update-in-place"
    state = load_state(bundle, slug)
    assert state["approval_refs"] == {"REQ_SIGNOFF": "APR-001"}
    assert state["paths"]["req"] == f"bundle://workspaces/req/projects/{slug}"
    assert (governance / "APPROVALS.md").read_text(encoding="utf-8") == "### APR-001\n"
    assert (governance / "DECISIONS.md").read_text(encoding="utf-8") == "# keep decisions\n"
    assert (governance / "intake" / "keep.md").is_file()
    assert (governance / "docs" / "keep.md").is_file()
    assert (governance / "test" / "keep.txt").is_file()
    for key in ("req", "ui", "arch", "code"):
        target = bundle.resolve(state["paths"][key], slug=slug)
        assert (target / f"{key}.txt").is_file()
    assert (bundle.resolve(state["paths"]["ppt_path"], slug=slug) / "deck.pptx").is_file()


def test_in_place_failure_restores_metadata_and_targets(
    bundle, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    slug = "rollback-app"
    sources = _in_place_project(bundle, tmp_path, slug)
    governance = sources["governance"]
    originals = {
        relative: (governance / relative).read_bytes()
        for relative in migration_module.METADATA_PATHS
    }
    original_replace = migration_module._atomic_replace_metadata
    calls = 0

    def fail_second(source: Path, destination: Path) -> None:
        nonlocal calls
        calls += 1
        if calls == 2:
            raise OSError("simulated metadata replacement failure")
        original_replace(source, destination)

    monkeypatch.setattr(migration_module, "_atomic_replace_metadata", fail_second)
    with pytest.raises(OSError, match="simulated"):
        migration_apply(bundle, slug, execute=True)

    for relative, content in originals.items():
        assert (governance / relative).read_bytes() == content
    for key in ("req", "ui", "arch", "code"):
        assert not bundle.resolve(
            bundle.configured_project_paths(slug)[key], slug=slug
        ).exists()
    assert not (
        bundle.resolve(bundle.data["workspaces"]["ppt"], slug=slug)
        / sources["ppt"].name
    ).exists()
    assert (governance / "intake" / "keep.md").is_file()


def test_plan_skips_optional_stages_but_requires_governance(bundle, tmp_path: Path):
    slug = "partial-app"
    legacy = _legacy_project(bundle, tmp_path, slug)
    shutil.rmtree(legacy / "ai-font-design")
    plan = migration_plan(bundle, slug, legacy)
    assert plan["ready"] is True
    ui = next(row for row in plan["sources"] if row["stage"] == "ui")
    assert ui["action"] == "skip-missing"

    shutil.rmtree(legacy / "ai-project-sop")
    missing_governance = migration_plan(bundle, slug, legacy)
    assert missing_governance["ready"] is False


def test_in_place_plan_refuses_existing_workspace_target(bundle, tmp_path: Path):
    slug = "conflict-app"
    _in_place_project(bundle, tmp_path, slug)
    req_target = bundle.resolve(
        bundle.configured_project_paths(slug)["req"], slug=slug
    )
    req_target.mkdir(parents=True)
    (req_target / "existing.txt").write_text("do not overwrite", encoding="utf-8")

    plan = migration_plan(bundle, slug)
    assert plan["ready"] is False
    req = next(row for row in plan["sources"] if row["stage"] == "req")
    assert "target already exists" in req["errors"][0]
    with pytest.raises(RuntimeError, match="not ready"):
        migration_apply(bundle, slug, execute=True)
    assert (req_target / "existing.txt").read_text(encoding="utf-8") == "do not overwrite"
