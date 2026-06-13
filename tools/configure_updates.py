from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "update_config.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", help="GitHub repository in OWNER/REPO format")
    parser.add_argument("--disable", action="store_true")
    args = parser.parse_args()

    repository = (args.repository or input("GitHub repository (OWNER/REPO): ")).strip().strip("/")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        print("[ERROR] Use OWNER/REPO format, for example myname/aura")
        return 2

    payload = json.loads(CONFIG.read_text(encoding="utf-8"))
    payload["repository"] = repository
    payload["enabled"] = not args.disable
    CONFIG.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Update repository configured: {repository}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
