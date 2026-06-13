from __future__ import annotations

import json
import logging
import os
from datetime import datetime
from pathlib import Path
from threading import RLock

from .models import ActionStep, VoiceCommand


class CommandStore:
    """Stores commands as readable UTF-8 JSON in the user's profile."""

    def __init__(self, data_dir: Path | None = None) -> None:
        default_dir = Path(os.getenv("APPDATA") or Path.home() / ".config") / "AURA"
        self.data_dir = data_dir or default_dir
        self.path = self.data_dir / "commands.json"
        self._lock = RLock()
        self.data_dir.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self._write(self._starter_commands())

    def all(self) -> list[VoiceCommand]:
        with self._lock:
            try:
                raw = json.loads(self.path.read_text(encoding="utf-8"))
                if not isinstance(raw, list):
                    raise TypeError("commands.json must contain a list")
                commands = [VoiceCommand.from_dict(item) for item in raw if isinstance(item, dict)]
                if not commands and raw:
                    raise TypeError("commands.json contains no valid commands")
                return commands
            except (OSError, json.JSONDecodeError, TypeError) as exc:
                logging.exception("Unable to load commands, restoring starter set")
                self._backup_broken_file(exc)
                commands = self._starter_commands()
                self._write(commands)
                return commands

    def save(self, command: VoiceCommand) -> None:
        with self._lock:
            commands = self.all()
            for index, item in enumerate(commands):
                if item.id == command.id:
                    commands[index] = command
                    break
            else:
                commands.append(command)
            self._write(commands)

    def delete(self, command_id: str) -> None:
        with self._lock:
            self._write([item for item in self.all() if item.id != command_id])

    def set_enabled(self, command_id: str, enabled: bool) -> None:
        with self._lock:
            commands = self.all()
            for item in commands:
                if item.id == command_id:
                    item.enabled = enabled
                    break
            self._write(commands)

    def _backup_broken_file(self, reason: Exception) -> None:
        if not self.path.exists():
            return
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = self.data_dir / f"commands.broken-{timestamp}.json"
        try:
            self.path.replace(backup)
            logging.error("Broken commands file moved to %s: %s", backup, reason)
        except OSError:
            logging.exception("Unable to back up broken commands file")

    def _write(self, commands: list[VoiceCommand]) -> None:
        payload = [item.to_dict() for item in commands]
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(self.path)

    @staticmethod
    def _starter_commands() -> list[VoiceCommand]:
        return [
            VoiceCommand(
                name="Открыть браузер",
                phrases=["открой браузер", "запусти браузер"],
                actions=[ActionStep("open_url", "https://www.google.com")],
            ),
            VoiceCommand(
                name="Рабочее пространство",
                phrases=["начать работу", "открой рабочее пространство"],
                actions=[
                    ActionStep("open_url", "https://mail.google.com", delay_after=1.0),
                    ActionStep("open_app", "explorer"),
                ],
                command_type="mode",
            ),
            VoiceCommand(
                name="Сделать скриншот",
                phrases=["сделай скриншот", "снимок экрана"],
                actions=[ActionStep("hotkey", "win+shift+s")],
            ),
            VoiceCommand(
                name="Увеличить громкость",
                phrases=["сделай громче", "увеличь громкость"],
                actions=[ActionStep("key", "volumeup")],
            ),
        ]
