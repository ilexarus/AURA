from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    args = parser.parse_args()
    version = args.version.strip().lstrip("vV")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:\.\d+)?", version):
        print("[ERROR] Version must look like 0.4.1")
        return 2
    (ROOT / "VERSION.txt").write_text(version + "\n", encoding="ascii")
    print(f"Version set to {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
