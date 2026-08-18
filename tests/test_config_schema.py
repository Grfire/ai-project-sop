from __future__ import annotations

import shutil
from pathlib import Path

import pytest
import yaml

from sop.config import Config


def test_config_accepts_only_portable_active_paths(bundle):
    assert bundle.data["project_paths"]["code"].startswith("bundle://")
    assert bundle.data["migration"]["legacy_sources"]["code"].startswith("E:/")


def test_config_rejects_absolute_active_path(bundle, tmp_path: Path):
    root = tmp_path / "invalid"
    root.mkdir()
    shutil.copytree(bundle.root / "schemas", root / "schemas")
    data = dict(bundle.data)
    data["projects_root"] = "E:/not-portable/projects"
    (root / "sop.yaml").write_text(
        yaml.safe_dump(data, sort_keys=False), encoding="utf-8"
    )
    with pytest.raises(ValueError, match="invalid sop.yaml"):
        Config.load(root)
