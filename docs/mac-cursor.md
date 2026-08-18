# macOS Cursor setup

## Clone and bootstrap

```bash
git clone <repository-url>
cd ai-project-sop
chmod +x bootstrap.command
./bootstrap.command
```

Bootstrap requires Python >=3.10 and Node.js with npm/npx. It creates `.venv`,
installs the Python package and test dependencies, installs product-test npm
dependencies with the lockfile, installs Playwright Chromium, and reports
optional Docker/PPT availability.

Official package sources are the default. For a mirror:

```bash
SOP_PIP_INDEX=https://your-pypi/simple \
SOP_NPM_REGISTRY=https://your-npm-registry \
SOP_PLAYWRIGHT_DOWNLOAD_HOST=https://your-playwright-host \
./bootstrap.command
```

## Cursor and MCP PATH

Start Cursor from a shell that can resolve `node`, `npm`, and `npx`, or ensure
their installation directory is included in the environment inherited by the
Cursor application. On Apple Silicon package-manager installs, verify:

```bash
command -v python3
command -v node
command -v npm
command -v npx
```

The session hook calls `node .cursor/hooks/session-start.mjs`. The launcher
prefers `.venv/bin/python`, then `python3`, `python`, and `py`; failure still
returns valid Cursor JSON with a warning. The project MCP definition uses npx,
so an IDE launched without the Node PATH can have a working Python CLI but a
missing Playwright server.

## Migrate a legacy project

Review before writing:

```bash
.venv/bin/python -m sop --root . migrate plan <slug>
.venv/bin/python -m sop --root . migrate apply <slug>
```

Both commands above are dry-run. Apply only after reviewing all sources,
targets, exclusions, and slug checks:

```bash
.venv/bin/python -m sop --root . migrate apply <slug> --execute
```

For an exported legacy workspace mounted somewhere other than the configured
historical root, add `--legacy-root /path/to/export`. Migration refuses to
overwrite any Bundle target.

## Validate

```bash
.venv/bin/python -m pytest -q --basetemp .pytest-tmp/current-run
.venv/bin/python scripts/validate-static-contracts.py
.venv/bin/python -m sop --root . project list
node .cursor/hooks/session-start.mjs
```

The PowerShell unified smoke is retained for Windows CI and is not required on
macOS.
