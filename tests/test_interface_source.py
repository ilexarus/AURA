from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = (ROOT / "ui" / "Main.qml").read_text(encoding="utf-8")
BACKEND = (ROOT / "aura" / "backend.py").read_text(encoding="utf-8")


class InterfaceSourceTests(unittest.TestCase):
    def test_command_search_is_present(self) -> None:
        self.assertIn("Поиск команд", QML)
        self.assertIn("commandSearch", QML)

    def test_step_and_scenario_testing_are_connected(self) -> None:
        self.assertIn("backend.testAction", QML)
        self.assertIn("backend.testScenario", QML)
        self.assertIn("def testAction", BACKEND)
        self.assertIn("def testScenario", BACKEND)

    def test_recording_overlay_is_present(self) -> None:
        self.assertIn("id: recordingOverlay", QML)
        self.assertIn("Идёт запись действий", QML)


if __name__ == "__main__":
    unittest.main()
