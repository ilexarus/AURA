from __future__ import annotations

import hashlib
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: make_checksum.py FILE")
        return 2
    path = Path(sys.argv[1]).resolve()
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    output = path.with_suffix(path.suffix + ".sha256")
    output.write_text(f"{digest.hexdigest()}  {path.name}\n", encoding="ascii")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
