from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest


def test_node_hook_emits_cursor_context_on_failure(tmp_path: Path):
    node = shutil.which("node")
    if not node:
        pytest.skip("Node is not installed")
    source = Path(__file__).resolve().parents[1] / ".cursor" / "hooks" / "session-start.mjs"
    hook = tmp_path / ".cursor" / "hooks" / "session-start.mjs"
    hook.parent.mkdir(parents=True)
    shutil.copy2(source, hook)
    env = os.environ.copy()
    env["PATH"] = ""
    completed = subprocess.run(
        [node, str(hook)],
        cwd=tmp_path,
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )
    payload = json.loads(completed.stdout)
    assert set(payload) == {"additional_context"}
    assert "startup degraded" in payload["additional_context"]
    assert "Warning:" in payload["additional_context"]
