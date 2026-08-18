"""Stable gate, reset, lifecycle, and governance operations."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Any

from .config import Config
from .io import append_markdown_atomic, atomic_write_text, read_json
from .state import guard_project, load_state, utc_now, write_state

GATES = (
    "INTAKE_COMPLETE",
    "REQ_SIGNOFF",
    "UI_SIGNOFF",
    "ARCH_SIGNOFF",
    "TEST_PACK_READY",
    "CODE_READY",
    "REGRESSION_PASS",
    "DOCS_COMPLETE",
)
GATE_META = {
    "INTAKE_COMPLETE": ("INTAKE", "项目接管分析师"),
    "REQ_SIGNOFF": ("REQ", "需求分析师"),
    "UI_SIGNOFF": ("UI", "原型设计师"),
    "ARCH_SIGNOFF": ("ARCH", "架构师"),
    "TEST_PACK_READY": ("TEST", "测试架构师"),
    "CODE_READY": ("CODE", "研发工程师"),
    "REGRESSION_PASS": ("TEST", "测试架构师"),
    "DOCS_COMPLETE": ("DOCS", "文档专员"),
}
PREREQUISITES = {
    "INTAKE_COMPLETE": (),
    "REQ_SIGNOFF": (),
    "UI_SIGNOFF": ("REQ_SIGNOFF",),
    "ARCH_SIGNOFF": ("REQ_SIGNOFF",),
    "TEST_PACK_READY": ("REQ_SIGNOFF", "ARCH_SIGNOFF"),
    "CODE_READY": ("REQ_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY"),
    "REGRESSION_PASS": ("REQ_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY"),
    "DOCS_COMPLETE": ("REQ_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS"),
}
RESET_MATRIX = {
    "product": GATES[1:],
    "visual": GATES[2:],
    "architecture": GATES[3:],
    "test_pack": GATES[4:],
    "runtime_code": ("CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE"),
    "documentation": ("DOCS_COMPLETE",),
}


def _require_confirmation(decision_maker: str, confirmation_quote: str) -> tuple[str, str]:
    if not decision_maker or not decision_maker.strip():
        raise ValueError("decision_maker from the conversation is required")
    if not confirmation_quote or len(confirmation_quote.strip()) < 2:
        raise ValueError("confirmation_quote from the conversation is required")
    return decision_maker.strip(), confirmation_quote.strip().replace("|", "/")


def _next_id(path: Path, prefix: str) -> str:
    maximum = 0
    if path.is_file():
        for match in re.finditer(rf"(?m)^###\s+{prefix}-(\d+)", path.read_text(encoding="utf-8-sig")):
            maximum = max(maximum, int(match.group(1)))
    return f"{prefix}-{maximum + 1:03d}"


def _gate_approved(state: dict[str, Any], gate: str) -> bool:
    stage = GATE_META[gate][0]
    status = state["stage_status"][stage]
    valid_status = status not in {"not_started", "na"} if stage == "TEST" else status == "approved"
    return valid_status and bool(state["approval_refs"].get(gate))


def assert_prerequisites(state: dict[str, Any], gate: str) -> None:
    for required in PREREQUISITES[gate]:
        if not _gate_approved(state, required):
            raise RuntimeError(f"{gate} requires current approved cache for {required}")


def assert_fresh_regression(config: Config, slug: str, state: dict[str, Any]) -> dict[str, Any]:
    path = config.project_root(slug) / "test" / "last-run.json"
    if not path.is_file():
        raise RuntimeError("fresh full regression requires test/last-run.json")
    run = read_json(path)
    if run.get("slug") != slug or run.get("mode") != "full" or run.get("overall") != "PASS":
        raise RuntimeError("regression evidence must match slug with mode=full and overall=PASS")
    freshness = run.get("freshness") or {}
    code_at = state["timestamps"].get("last_code_change_at")
    if (
        freshness.get("regression_started_after_code_change") is not True
        or not code_at
        or freshness.get("last_code_change_at") != code_at
        or _parse_time(run.get("finished_at")) < _parse_time(code_at)
    ):
        raise RuntimeError("regression evidence is stale relative to the last code change")
    return run


def _parse_time(value: str | None) -> datetime:
    if not value:
        raise ValueError("required timestamp is missing")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def record_gate(
    config: Config,
    slug: str,
    gate: str,
    decision: str,
    decision_maker: str,
    confirmation_quote: str,
    *,
    evidence: str = "",
    scope: str = "",
    waiver_reason: str = "",
    risk_owner: str = "",
    expiry: str = "",
) -> dict[str, Any]:
    if gate not in GATES:
        raise ValueError(f"unknown gate: {gate}")
    if decision not in {"approved", "rejected", "waived"}:
        raise ValueError("decision must be approved, rejected, or waived")
    maker, quote = _require_confirmation(decision_maker, confirmation_quote)
    state = guard_project(config, slug)
    if decision == "approved":
        assert_prerequisites(state, gate)
        if gate in {"REGRESSION_PASS", "DOCS_COMPLETE"}:
            assert_fresh_regression(config, slug, state)
        if gate == "REQ_SIGNOFF" and not (
            state["governance"].get("data_classification")
            and state["governance"].get("compliance_owner")
        ):
            raise RuntimeError("REQ_SIGNOFF requires data_classification and compliance_owner")
        if gate == "ARCH_SIGNOFF" and state.get("ui_input_mode") not in {"complete", "partial", "none"}:
            raise RuntimeError("ARCH_SIGNOFF requires ui_input_mode")
    if decision == "waived":
        if gate == "UI_SIGNOFF":
            raise RuntimeError("UI_SIGNOFF cannot be waived to completion")
        if not waiver_reason or not risk_owner or not expiry:
            raise ValueError("waiver requires waiver_reason, risk_owner, and expiry")

    root = config.project_root(slug)
    approvals = root / "APPROVALS.md"
    decisions = root / "DECISIONS.md"
    stamp = utc_now()
    apr_id = _next_id(approvals, "APR")
    dec_id = _next_id(decisions, "DEC") if decision == "waived" else "none"
    approval_record = f"""### {apr_id} — {gate}

| Field | Value |
|-------|-------|
| Project slug | {slug} |
| Decision | {decision} |
| Approver | {maker} |
| Confirmed at | {stamp} |
| Scope / version | {scope} |
| Evidence snapshot / links | {evidence} |
| Confirmation quote | {quote} |
| Decision reference | {dec_id} |

Machine evidence is not approval authority. This records the conversational decision."""
    # Records are written before the cache. A failure can omit a cache, but can
    # never leave an unrecorded machine approval.
    append_markdown_atomic(approvals, approval_record)
    if decision == "waived":
        append_markdown_atomic(decisions, f"""### {dec_id} — waiver {gate}

| Field | Value |
|-------|-------|
| Recorded at | {stamp} |
| Decision maker | {maker} |
| Type | waiver |
| Context | {gate} |
| Decision | waived: {waiver_reason} |
| Risk owner | {risk_owner} |
| Expiry / review trigger | {expiry} |
| Explicit confirmation quote | {quote} |""")
        state["governance"]["active_waiver_ids"].append(dec_id)
    elif decision == "approved":
        stage = GATE_META[gate][0]
        state["stage_status"][stage] = "approved"
        state["approval_refs"][gate] = apr_id
        if gate == "INTAKE_COMPLETE":
            state["timestamps"]["intake_completed_at"] = stamp
        elif gate == "TEST_PACK_READY":
            state["timestamps"]["test_pack_at"] = stamp
            state["mode"] = "packaging"
        elif gate == "REGRESSION_PASS":
            state["mode"] = "regression"
        elif gate == "DOCS_COMPLETE":
            state["timestamps"]["docs_completed_at"] = stamp
    else:
        state = _invalidate_from_gate(state, gate, evidence or "rejected in conversation", stamp)
    state["timestamps"]["updated_at"] = stamp
    write_state(config, slug, state)
    return {"slug": slug, "gate_id": gate, "decision": decision, "approval_id": apr_id, "human_gate_approved": False}


def _invalidate_from_gate(state: dict[str, Any], gate: str, reason: str, stamp: str) -> dict[str, Any]:
    for invalid in GATES[GATES.index(gate):]:
        state["approval_refs"].pop(invalid, None)
        stage = GATE_META[invalid][0]
        state["stage_status"][stage] = "blocked" if invalid == gate else "in_progress"
    state["blocked"] = {"gate_id": gate, "owner_role": GATE_META[gate][1], "reason": reason, "since": stamp}
    if "REGRESSION_PASS" in GATES[GATES.index(gate):]:
        state["timestamps"]["last_regression_at"] = None
        state.pop("regression", None)
    return state


def reset_gates(
    config: Config,
    slug: str,
    change_class: str,
    decision_maker: str,
    confirmation_quote: str,
    reason: str,
    *,
    target_status: str = "in_progress",
) -> dict[str, Any]:
    if change_class not in RESET_MATRIX:
        raise ValueError(f"unknown change class: {change_class}")
    if target_status not in {"in_progress", "blocked"}:
        raise ValueError("target_status must be in_progress or blocked")
    maker, quote = _require_confirmation(decision_maker, confirmation_quote)
    if not reason.strip():
        raise ValueError("reason is required")
    state = guard_project(config, slug)
    gates = RESET_MATRIX[change_class]
    superseded = [state["approval_refs"][gate] for gate in gates if gate in state["approval_refs"]]
    for gate in gates:
        state["approval_refs"].pop(gate, None)
        state["stage_status"][GATE_META[gate][0]] = target_status
    if "REGRESSION_PASS" in gates:
        state["timestamps"]["last_regression_at"] = None
        state.pop("regression", None)
    if "TEST_PACK_READY" in gates:
        state["timestamps"]["test_pack_at"] = None
    if "DOCS_COMPLETE" in gates:
        state["timestamps"]["docs_completed_at"] = None
    state["mode"] = None if {"REGRESSION_PASS", "TEST_PACK_READY"} & set(gates) else state.get("mode")
    stamp = utc_now()
    state["blocked"] = (
        {"gate_id": gates[0], "owner_role": GATE_META[gates[0]][1], "reason": reason, "since": stamp}
        if target_status == "blocked" else None
    )
    state["timestamps"]["updated_at"] = stamp
    # Invalidation is committed first: later record failure remains fail-closed.
    write_state(config, slug, state)
    decisions = config.project_root(slug) / "DECISIONS.md"
    dec_id = _next_id(decisions, "DEC")
    append_markdown_atomic(decisions, f"""### {dec_id} — reset {change_class}

| Field | Value |
|-------|-------|
| Recorded at | {stamp} |
| Decision maker | {maker} |
| Type | change |
| Context | {reason.replace('|', '/')} |
| Decision | Reset gates {', '.join(gates)} to {target_status} |
| Superseded approval IDs | {', '.join(superseded) or 'none'} |
| Explicit confirmation quote | {quote} |""")
    return {"slug": slug, "change_class": change_class, "reset_gates": list(gates), "superseded": superseded, "decision_id": dec_id}


def touch_code(
    config: Config,
    slug: str,
    decision_maker: str,
    confirmation_quote: str,
    reason: str,
    timestamp: str | None = None,
) -> dict[str, Any]:
    report = reset_gates(config, slug, "runtime_code", decision_maker, confirmation_quote, reason)
    state = load_state(config, slug)
    stamp = timestamp or utc_now()
    old = state["timestamps"].get("last_code_change_at")
    if old and _parse_time(stamp) < _parse_time(old):
        raise ValueError("last_code_change_at cannot move backwards")
    state["timestamps"]["last_code_change_at"] = stamp
    state["timestamps"]["updated_at"] = stamp
    write_state(config, slug, state)
    return {"slug": slug, "last_code_change_at": stamp, "reset_gates": list(RESET_MATRIX["runtime_code"]), "reset_decision_id": report["decision_id"]}


def set_lifecycle(
    config: Config,
    slug: str,
    lifecycle: str,
    decision_maker: str,
    confirmation_quote: str,
    reason: str = "",
) -> dict[str, Any]:
    if lifecycle not in {"active", "paused", "cancelled", "archived"}:
        raise ValueError("invalid lifecycle")
    maker, quote = _require_confirmation(decision_maker, confirmation_quote)
    state = guard_project(config, slug, intent="lifecycle")
    current = state["lifecycle"]
    if current == lifecycle:
        raise RuntimeError(f"lifecycle is already {lifecycle}")
    if current == "cancelled":
        raise RuntimeError("cancelled projects cannot be reactivated")
    if current == "archived" and lifecycle != "active":
        raise RuntimeError("archived projects can only be reactivated to active")
    stamp = utc_now()
    state["lifecycle"] = lifecycle
    state["timestamps"]["lifecycle_changed_at"] = stamp
    state["timestamps"]["updated_at"] = stamp
    decisions = config.project_root(slug) / "DECISIONS.md"
    dec_id = _next_id(decisions, "DEC")
    append_markdown_atomic(decisions, f"""### {dec_id} — lifecycle {current} -> {lifecycle}

| Field | Value |
|-------|-------|
| Recorded at | {stamp} |
| Decision maker | {maker} |
| Type | lifecycle |
| Decision | {reason or f'Set lifecycle to {lifecycle}'} |
| Explicit confirmation quote | {quote} |""")
    write_state(config, slug, state)
    return {"slug": slug, "from": current, "lifecycle": lifecycle, "decision_id": dec_id}


def record_cancellation(config: Config, slug: str, decision_maker: str, confirmation_quote: str, reason: str) -> dict[str, Any]:
    maker, quote = _require_confirmation(decision_maker, confirmation_quote)
    state = guard_project(config, slug, intent="cancellation")
    if state["lifecycle"] != "cancelled":
        raise RuntimeError("cancellation follow-up requires lifecycle=cancelled")
    decisions = config.project_root(slug) / "DECISIONS.md"
    dec_id = _next_id(decisions, "DEC")
    append_markdown_atomic(decisions, f"""### {dec_id} — cancellation record

| Field | Value |
|-------|-------|
| Recorded at | {utc_now()} |
| Decision maker | {maker} |
| Type | cancellation |
| Decision | {reason.replace('|', '/')} |
| Explicit confirmation quote | {quote} |""")
    return {"slug": slug, "lifecycle": "cancelled", "decision_id": dec_id, "human_gate_approved": False}


def write_governance(config: Config, slug: str, updates: dict[str, Any]) -> dict[str, Any]:
    state = guard_project(config, slug)
    allowed = {
        "data_classification", "regulated_data", "residency", "retention",
        "access_audit", "third_party_transfer", "compliance_owner", "active_waiver_ids",
    }
    unknown = set(updates) - allowed - {"ui_input_mode"}
    if unknown:
        raise ValueError(f"unknown governance fields: {sorted(unknown)}")
    if "ui_input_mode" in updates:
        if updates["ui_input_mode"] not in {"complete", "partial", "none"}:
            raise ValueError("ui_input_mode must be complete, partial, or none")
        state["ui_input_mode"] = updates.pop("ui_input_mode")
    state["governance"].update(updates)
    state["timestamps"]["updated_at"] = utc_now()
    write_state(config, slug, state)
    return {"slug": slug, "governance": state["governance"], "human_gate_approved": False}
