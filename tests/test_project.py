from sop.state import active_slug, load_state, new_project


def test_new_project_is_portable_and_active(bundle):
    result = new_project(bundle, "portable-app")
    assert result["active"] is True
    assert active_slug(bundle) == "portable-app"
    state = load_state(bundle, "portable-app")
    assert state["slug"] == "portable-app"
    assert state["paths"]["req"] == "bundle://workspaces/req/projects/portable-app"
    assert state["paths"]["test"] == "project://test"
    assert not (bundle.project_root("portable-app") / "intake").exists()
