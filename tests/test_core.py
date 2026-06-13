from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from aura.actions import ActionExecutor
from aura.engine import CommandMatcher
from aura.models import ActionStep, VoiceCommand
from aura.storage import CommandStore


class RecordingExecutor(ActionExecutor):
    def __init__(self) -> None:
        self.values: list[str] = []

    def execute_step(self, step: ActionStep) -> None:
        self.values.append(step.value)


class CoreTests(unittest.TestCase):
    def test_legacy_command_migration(self) -> None:
        command = VoiceCommand.from_dict({
            "name": "Legacy",
            "phrases": ["test"],
            "action_type": "open_url",
            "action_value": "example.com",
        })
        self.assertEqual(len(command.actions), 1)
        self.assertEqual(command.actions[0].value, "example.com")

    def test_multistep_storage(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            store = CommandStore(Path(folder))
            command = VoiceCommand(
                "Work",
                ["start work"],
                [ActionStep("open_url", "example.com"), ActionStep("wait", "0")],
            )
            store.save(command)
            loaded = next(item for item in store.all() if item.id == command.id)
            self.assertEqual(len(loaded.actions), 2)
            json.loads(store.path.read_text(encoding="utf-8"))

    def test_action_sequence_preserves_order(self) -> None:
        executor = RecordingExecutor()
        command = VoiceCommand(
            "Sequence",
            ["sequence"],
            [
                ActionStep("open_url", "first"),
                ActionStep("open_app", "second"),
                ActionStep("key", "third"),
            ],
        )
        result = executor.execute(command)
        self.assertEqual(executor.values, ["first", "second", "third"])
        self.assertEqual(result, "Выполнено: Sequence")

    def test_corrupted_storage_is_backed_up(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            data_dir = Path(folder)
            store = CommandStore(data_dir)
            store.path.write_text("{broken", encoding="utf-8")
            restored = store.all()
            self.assertTrue(restored)
            backups = list(data_dir.glob("commands.broken-*.json"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(encoding="utf-8"), "{broken")

    def test_fuzzy_matching(self) -> None:
        command = VoiceCommand("Browser", ["открой браузер"], [ActionStep("open_url", "example.com")])
        result = CommandMatcher().find("открой браузир", [command])
        self.assertIsNotNone(result)
        self.assertEqual(result.command.name, "Browser")


if __name__ == "__main__":
    unittest.main()
