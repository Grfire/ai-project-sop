"""Source-tree shim so ``python -m sop`` works before installation."""

from pathlib import Path

_SOURCE_PACKAGE = Path(__file__).resolve().parents[1] / "src" / "sop"
if str(_SOURCE_PACKAGE) not in __path__:
    __path__.append(str(_SOURCE_PACKAGE))

__version__ = "0.1.0"
