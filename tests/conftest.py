from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from sop.config import Config


@pytest.fixture()
def bundle(tmp_path: Path) -> Config:
    source = Path(__file__).resolve().parents[1]
    for name in ("sop.yaml",):
        shutil.copy2(source / name, tmp_path / name)
    for name in ("schemas", "projects", "vendor-templates"):
        shutil.copytree(source / name, tmp_path / name)
    return Config.load(tmp_path)
