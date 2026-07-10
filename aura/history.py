from __future__ import annotations

import json
import logging
from datetime import datetime
from pathlib import Path
from threading import RLock


class ActivityStore:
    """Small persistent activity log used by the dashboard and diagnostics."""

    def __init__(self, data_dir: Path, limit: int = 100) -> None:
        self.path = Path(data_dir) / "history.json"
        self.limit = max(20, min(int(limit), 500))
        self._lock = RLock()

    def all(self) -> list[dict[str, str]]:
        with self._lock:
            try:
                payload = json.loads(self.path.read_text(encoding="utf-8"))
                if isinstance(payload, list):
                    return [item for item in payload if isinstance(item, dict)][: self.limit]
            except FileNotFoundError:
                return []
            except (OSError, json.JSONDecodeError):
                logging.exception("Unable to read activity history")
            return []

    def add(self, title: str, result: str, tone: str = "neutral") -> list[dict[str, str]]:
        with self._lock:
            rows = self.all()
            rows.insert(0, {
                "title": str(title)[:180],
                "result": str(result)[:300],
                "tone": tone if tone in {"success", "error", "warning", "neutral"} else "neutral",
                "time": datetime.now().strftime("%H:%M"),
                "timestamp": datetime.now().isoformat(timespec="seconds"),
            })
            rows = rows[: self.limit]
            self._write(rows)
            return rows

    def clear(self) -> None:
        with self._lock:
            self._write([])

    def _write(self, rows: list[dict[str, str]]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(self.path)
