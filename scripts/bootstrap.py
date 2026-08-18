#!/usr/bin/env python3
"""Cross-platform bootstrap for the portable SOP bundle."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

MIN_PYTHON = (3, 10)
OFFICIAL_PYPI = "https://pypi.org/simple"
OFFICIAL_NPM = "https://registry.npmjs.org"


def run(command: list[str], *, cwd: Path, env: dict[str, str] | None = None) -> bool:
    print("+", " ".join(command))
    actual = command
    if os.name == "nt" and Path(command[0]).suffix.lower() in {".cmd", ".bat"}:
        actual = ["cmd.exe", "/d", "/s", "/c", subprocess.list2cmdline(command)]
    return subprocess.run(actual, cwd=cwd, env=env, check=False).returncode == 0


def command_path(name: str) -> str | None:
    path = shutil.which(name)
    print(f"{'OK  ' if path else 'MISS'} {name}{f' -> {path}' if path else ''}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--pip-index", default=os.getenv("SOP_PIP_INDEX", OFFICIAL_PYPI))
    parser.add_argument("--npm-registry", default=os.getenv("SOP_NPM_REGISTRY", OFFICIAL_NPM))
    parser.add_argument(
        "--playwright-download-host",
        default=os.getenv("SOP_PLAYWRIGHT_DOWNLOAD_HOST", ""),
    )
    parser.add_argument("--skip-product-deps", action="store_true")
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    failures: list[str] = []

    if sys.version_info < MIN_PYTHON:
        print(f"Python >=3.10 required; found {sys.version.split()[0]}", file=sys.stderr)
        return 2
    print(f"OK   Python {sys.version.split()[0]} -> {sys.executable}")

    venv = root / ".venv"
    if not venv.exists() and not run([sys.executable, "-m", "venv", str(venv)], cwd=root):
        return 2
    python = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not run(
        [
            str(python),
            "-m",
            "pip",
            "install",
            "--disable-pip-version-check",
            "--index-url",
            args.pip_index,
            "-r",
            "requirements.txt",
            "-e",
            ".[dev]",
        ],
        cwd=root,
    ):
        failures.append(
            f"Python package install failed; retry with SOP_PIP_INDEX={OFFICIAL_PYPI}"
        )

    node = command_path("node")
    npm = command_path("npm")
    npx = command_path("npx")
    if not all((node, npm, npx)):
        failures.append("Install Node.js LTS with npm/npx")

    product_dirs = [root / "projects" / "_template" / "test" / "product"]
    projects = root / "projects"
    if projects.is_dir():
        product_dirs.extend(
            path / "test" / "product"
            for path in projects.iterdir()
            if path.is_dir() and path.name != "_template"
        )
    installed_product: Path | None = None
    if npm and not args.skip_product_deps:
        env = os.environ.copy()
        env["npm_config_registry"] = args.npm_registry
        if args.playwright_download_host:
            env["PLAYWRIGHT_DOWNLOAD_HOST"] = args.playwright_download_host
        for product in product_dirs:
            if not (product / "package.json").is_file():
                continue
            install_command = (
                [npm, "ci", "--registry", args.npm_registry]
                if (product / "package-lock.json").is_file()
                else [npm, "install", "--registry", args.npm_registry]
            )
            if not run(install_command, cwd=product, env=env):
                failures.append(
                    f"Product dependencies failed at {product}; retry with SOP_NPM_REGISTRY={OFFICIAL_NPM}"
                )
            elif installed_product is None:
                installed_product = product

    if npx and installed_product:
        env = os.environ.copy()
        if args.playwright_download_host:
            env["PLAYWRIGHT_DOWNLOAD_HOST"] = args.playwright_download_host
        playwright_ok = run([npx, "playwright", "--version"], cwd=installed_product, env=env)
        browser_ok = playwright_ok and run(
            [npx, "playwright", "install", "chromium"],
            cwd=installed_product,
            env=env,
        )
        if not browser_ok:
            failures.append(
                "Playwright Chromium install failed; retry with SOP_PLAYWRIGHT_DOWNLOAD_HOST unset or set to a reachable mirror"
            )
        else:
            print("OK   Playwright CLI and Chromium")
    elif npx:
        print("WARN Playwright CLI unavailable until product dependencies are installed")

    docker = command_path("docker")
    if docker:
        print(
            "OK   Docker engine reachable"
            if run([docker, "version"], cwd=root)
            else "WARN Docker CLI found but engine is unavailable"
        )
    else:
        print("WARN Docker is optional and was not found")

    ppt = Path.home() / ".agents" / "skills" / "ppt-studio" / "SKILL.md"
    print(f"{'OK  ' if ppt.is_file() else 'WARN'} PPT skill {'available' if ppt.is_file() else 'optional and not installed'}")
    print("Cursor MCP: ensure Node/npm/npx are on the PATH inherited by Cursor.")

    if failures:
        print("Bootstrap issues:", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1
    print("Bootstrap OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
