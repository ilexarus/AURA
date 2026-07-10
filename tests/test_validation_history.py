from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from aura.history import ActivityStore
from aura.models import ActionStep, VoiceCommand
from aura.validation import validate_command, validate_step


class ValidationAndHistoryTests(unittest.TestCase):
    def test_valid_command_has_no_errors(self) -> None:
        command = VoiceCommand("Поиск", ["найди новости"], [ActionStep("open_search", "новости")])
        self.assertFalse(any(issue.level == "error" for issue in validate_command(command)))

    def test_invalid_wait_is_reported(self) -> None:
        issues = validate_step(ActionStep("wait", "не число"), 2)
        self.assertTrue(any(issue.level == "error" and issue.step_index == 2 for issue in issues))

    def test_voice_command_requires_phrase(self) -> None:
        issues = validate_command(VoiceCommand("Тест", [], [ActionStep("wait", "1")]))
        self.assertTrue(any(issue.field == "phrases" for issue in issues))

    def test_activity_history_survives_restart(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            first = ActivityStore(Path(folder), limit=25)
            first.add("Команда", "Выполнено", "success")
            second = ActivityStore(Path(folder), limit=25)
            rows = second.all()
            self.assertEqual(rows[0]["title"], "Команда")
            self.assertEqual(rows[0]["tone"], "success")

    def test_history_is_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            store = ActivityStore(Path(folder), limit=20)
            for index in range(30):
                store.add(str(index), "ok")
            self.assertEqual(len(store.all()), 20)


if __name__ == "__main__":
    unittest.main()
