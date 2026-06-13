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
        self.assertIn("function testAction(index)", QML)
        self.assertIn("editor.testAction(actionCard.index)", QML)
        self.assertIn("backend.testAction", QML)
        self.assertIn("backend.testScenario", QML)
        self.assertIn("def testAction", BACKEND)
        self.assertIn("def _start_action_test", BACKEND)
        self.assertIn("def testScenario", BACKEND)

    def test_recording_overlay_is_present(self) -> None:
        self.assertIn("id: recordingOverlay", QML)
        self.assertIn("Идёт запись действий", QML)

    def test_step_enabled_role_does_not_collide_with_item_enabled(self) -> None:
        self.assertIn('"step_enabled"', QML)
        self.assertIn('required property bool step_enabled', QML)
        self.assertNotIn('property bool stepEnabled: model.enabled', QML)
        self.assertIn('actionModel.setProperty(actionCard.index, "step_enabled", checked)', QML)

    def test_single_step_button_is_not_blocked_by_step_enabled_state(self) -> None:
        start = QML.index('id: testStepButton')
        end = QML.index('ToolButton {', start + 10)
        block = QML[start:end]
        self.assertNotIn('actionCard.stepEnabled', block)
        self.assertIn('onClicked: editor.testAction(actionCard.index)', block)

    def test_rejected_step_test_reports_result_to_qml(self) -> None:
        self.assertIn('self.actionTestResult.emit(index, False, message)', BACKEND)


if __name__ == "__main__":
    unittest.main()
