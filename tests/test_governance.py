import json

import pytest

from sop.governance import record_gate, reset_gates, touch_code
from sop.state import load_state, new_project, write_state


def _seed_approved_state(bundle, slug):
    state = load_state(bundle, slug)
    for gate, stage in (
        ("REQ_SIGNOFF", "REQ"),
        ("ARCH_SIGNOFF", "ARCH"),
        ("TEST_PACK_READY", "TEST"),
        ("CODE_READY", "CODE"),
        ("REGRESSION_PASS", "TEST"),
        ("DOCS_COMPLETE", "DOCS"),
    ):
        state["approval_refs"][gate] = f"APR-{len(state['approval_refs']) + 1:03d}"
        state["stage_status"][stage] = "approved"
    state["timestamps"]["last_code_change_at"] = "2026-08-18T00:00:00Z"
    state["timestamps"]["last_regression_at"] = "2026-08-18T00:10:00Z"
    state["regression"] = {
        "state": "passed",
        "mode": "full",
        "last_run": "project://test/last-run.json",
        "updated_at": "2026-08-18T00:10:00Z",
    }
    write_state(bundle, slug, state)


def test_gate_requires_human_confirmation_fields(bundle):
    new_project(bundle, "guarded")
    with pytest.raises(ValueError, match="confirmation_quote"):
        record_gate(bundle, "guarded", "REQ_SIGNOFF", "approved", "owner", "")


def test_reset_and_touch_invalidate_and_refresh(bundle):
    new_project(bundle, "runtime-app")
    _seed_approved_state(bundle, "runtime-app")
    result = touch_code(
        bundle,
        "runtime-app",
        "Alice",
        "确认运行时代码变更",
        "runtime behavior changed",
        "2026-08-18T01:00:00Z",
    )
    assert result["reset_gates"] == ["CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE"]
    state = load_state(bundle, "runtime-app")
    assert state["timestamps"]["last_code_change_at"] == "2026-08-18T01:00:00Z"
    assert state["timestamps"]["last_regression_at"] is None
    assert "regression" not in state
    assert "CODE_READY" not in state["approval_refs"]
    assert "REQ_SIGNOFF" in state["approval_refs"]


def test_fresh_regression_is_required_for_regression_gate(bundle):
    new_project(bundle, "fresh-app")
    _seed_approved_state(bundle, "fresh-app")
    state = load_state(bundle, "fresh-app")
    state["approval_refs"].pop("REGRESSION_PASS")
    state["approval_refs"].pop("DOCS_COMPLETE")
    write_state(bundle, "fresh-app", state)
    with pytest.raises(RuntimeError, match="last-run"):
        record_gate(
            bundle,
            "fresh-app",
            "REGRESSION_PASS",
            "approved",
            "Alice",
            "确认回归通过",
        )
