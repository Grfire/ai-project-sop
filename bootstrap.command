#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  echo "Python >=3.10 is required." >&2
  exit 2
fi
exec "$PYTHON" "$ROOT/scripts/bootstrap.py" --root "$ROOT" "$@"
