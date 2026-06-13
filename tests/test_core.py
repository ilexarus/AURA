from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from aura.actions import ActionExecutor
from aura.engine import CommandMatcher
from aura.models import ActionStep, VoiceCommand
from aura.recorder import ActionRecorder
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


    def test_recorder_merges_double_click(self) -> None:
        recorder = ActionRecorder()
        # Keep the unit test independent from the foreground window on the
        # Windows GitHub Actions runner. Window activation is tested separately
        # from click coalescing.
        recorder._foreground_window_title = lambda: ""
        recorder._on_click(120, 240, "Button.left", True)
        recorder._on_click(120, 240, "Button.left", True)
        steps = recorder._finalize()
        self.assertEqual(len(steps), 1)
        payload = json.loads(steps[0].value)
        self.assertEqual(payload["clicks"], 2)

    def test_recorded_steps_keep_delays_editable(self) -> None:
        recorder = ActionRecorder()
        recorder._steps = [
            (1.0, ActionStep("key", "enter")),
            (2.25, ActionStep("type_text", "hello")),
        ]
        steps = recorder._finalize()
        self.assertEqual(steps[0].delay_after, 1.25)

    def test_fuzzy_matching(self) -> None:
        command = VoiceCommand("Browser", ["открой браузер"], [ActionStep("open_url", "example.com")])
        result = CommandMatcher().find("открой браузир", [command])
        self.assertIsNotNone(result)
        self.assertEqual(result.command.name, "Browser")

    def test_mode_automation_storage_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            store = CommandStore(Path(folder))
            command = VoiceCommand(
                "Morning mode",
                ["morning mode"],
                [ActionStep("open_url", "example.com")],
                command_type="mode",
                trigger_type="daily",
                trigger_value="09:30",
            )
            store.save(command)
            loaded = next(item for item in store.all() if item.id == command.id)
            self.assertEqual(loaded.command_type, "mode")
            self.assertEqual(loaded.trigger_type, "daily")
            self.assertEqual(loaded.trigger_value, "09:30")

    def test_legacy_command_gets_automation_defaults(self) -> None:
        command = VoiceCommand.from_dict({
            "name": "Legacy",
            "phrases": ["legacy"],
            "actions": [{"action_type": "wait", "value": "0"}],
        })
        self.assertEqual(command.command_type, "command")
        self.assertEqual(command.trigger_type, "voice")
        self.assertNotIn("favorite", command.to_dict())

    def test_legacy_favorite_field_is_ignored(self) -> None:
        command = VoiceCommand.from_dict({
            "name": "Legacy favorite",
            "phrases": ["legacy favorite"],
            "actions": [{"action_type": "wait", "value": "0"}],
            "favorite": True,
        })
        self.assertNotIn("favorite", command.to_dict())

    def test_extended_variables_are_expanded(self) -> None:
        value = ActionExecutor.expand_variables("${user}|${desktop}|${downloads}|${date}|${time}")
        self.assertNotIn("${user}", value)
        self.assertNotIn("${desktop}", value)
        self.assertNotIn("${downloads}", value)

    def test_file_condition_accepts_existing_path(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            executor = ActionExecutor()
            executor.execute_step(ActionStep("require_file", folder))


if __name__ == "__main__":
    unittest.main()
