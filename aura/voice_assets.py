from __future__ import annotations

import json
from pathlib import Path


VOICE_FILES: dict[str, str] = {
    "executing": "executing.wav",
    "done": "done.wav",
    "not_found": "not_found.wav",
    "failed": "failed.wav",
    "confirmation": "confirmation.wav",
    "recording_started": "recording_started.wav",
    "recording_stopped": "recording_stopped.wav",
    "cancelled": "cancelled.wav",
}

VOICE_PACK_MANIFEST = "voice_pack.json"


def load_voice_manifest(base_dir: Path) -> dict[str, object] | None:
    path = Path(base_dir) / VOICE_PACK_MANIFEST
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def voice_pack_is_ready(base_dir: Path) -> bool:
    manifest = load_voice_manifest(base_dir)
    if not manifest:
        return False
    files = manifest.get("files")
    if not isinstance(files, dict):
        return False
    root = Path(base_dir)
    for key, filename in VOICE_FILES.items():
        entry = files.get(key)
        if not isinstance(entry, dict) or entry.get("file") != filename:
            return False
        if not (root / filename).is_file():
            return False
    return True


def resolve_voice_file(base_dir: Path, phrase_key: str) -> Path | None:
    if not voice_pack_is_ready(base_dir):
        return None
    filename = VOICE_FILES.get(phrase_key)
    if not filename:
        return None
    path = Path(base_dir) / filename
    return path if path.is_file() else None
