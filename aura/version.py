from __future__ import annotations

import sys
from pathlib import Path


def _read_version() -> str:
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parents[1]))
    try:
        value = (base / "VERSION.txt").read_text(encoding="ascii").strip()
        if value:
            return value
    except OSError:
        pass
    return "0.10.0"


VERSION = _read_version()
