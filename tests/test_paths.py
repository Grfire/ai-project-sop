from pathlib import Path

import pytest


def test_resolves_bundle_and_project_uris(bundle):
    assert bundle.resolve("bundle://workspaces/code/project/demo", slug="demo") == (
        bundle.root / "workspaces" / "code" / "project" / "demo"
    )
    assert bundle.resolve("project://test/catalog.yaml", slug="demo") == (
        bundle.root / "projects" / "demo" / "test" / "catalog.yaml"
    )


def test_rejects_escape_and_internal_absolute_path(bundle, tmp_path: Path):
    with pytest.raises(ValueError, match="escapes"):
        bundle.resolve("bundle://../outside")
    with pytest.raises(ValueError, match="internal paths"):
        bundle.resolve(str(tmp_path.resolve()))
    assert bundle.resolve(str(tmp_path.resolve()), allow_external=True) == tmp_path.resolve()
