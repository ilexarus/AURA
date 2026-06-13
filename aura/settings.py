from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(slots=True)
class AssistantSettings:
    wake_enabled: bool = True
    wake_phrase: str = "аура"
    microphone_index: int | None = None
    voice_feedback_enabled: bool = True
    first_run_completed: bool = False
    autostart_enabled: bool = False
    update_channel: str = "stable"

    @classmethod
    def from_dict(cls, payload: dict[str, object]) -> "AssistantSettings":
        microphone = payload.get("microphone_index")
        try:
            microphone_index = int(microphone) if microphone is not None else None
        except (TypeError, ValueError):
            microphone_index = None
        phrase = str(payload.get("wake_phrase") or "аура").strip()[:40] or "аура"
        channel = str(payload.get("update_channel") or "stable").strip().lower()
        if channel not in {"stable", "beta"}:
            channel = "stable"
        return cls(
            wake_enabled=bool(payload.get("wake_enabled", True)),
            wake_phrase=phrase,
            microphone_index=microphone_index,
            voice_feedback_enabled=bool(payload.get("voice_feedback_enabled", True)),
            first_run_completed=bool(payload.get("first_run_completed", True)),
            autostart_enabled=bool(payload.get("autostart_enabled", False)),
            update_channel=channel,
        )


class SettingsStore:
    def __init__(self, data_dir: Path) -> None:
        self.path = Path(data_dir) / "settings.json"
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def load(self) -> AssistantSettings:
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                return AssistantSettings.from_dict(payload)
        except FileNotFoundError:
            pass
        except (OSError, json.JSONDecodeError):
            logging.exception("Unable to read AURA settings")
        settings = AssistantSettings()
        self.save(settings)
        return settings

    def save(self, settings: AssistantSettings) -> None:
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(asdict(settings), ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(self.path)
