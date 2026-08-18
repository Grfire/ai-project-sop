from pathlib import Path

from sop.operations import session_context
from sop.state import new_project


def test_session_context_resolves_portable_paths(bundle):
    new_project(bundle, "context-app")
    context = session_context(bundle)
    assert context["active_slug"] == "context-app"
    assert context["lifecycle"] == "active"
    assert Path(context["paths"]["code"]).parts[-4:] == ("workspaces", "code", "project", "context-app")
    assert Path(context["paths"]["test"]).parts[-3:] == ("projects", "context-app", "test")
    assert context["human_gate_approved"] is False
