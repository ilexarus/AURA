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

    def test_settings_center_and_first_run_wizard_are_present(self) -> None:
        self.assertIn('id: settingsDialog', QML)
        self.assertIn('id: firstRunDialog', QML)
        self.assertIn('Проверить AURA', QML)
        self.assertIn('backend.startMicrophoneTest()', QML)
        self.assertIn('backend.createBackup()', QML)
        self.assertIn('backend.setUpdateChannel', QML)

    def test_backend_exposes_settings_and_diagnostics(self) -> None:
        self.assertIn('def refreshMicrophones', BACKEND)
        self.assertIn('def runDiagnostics', BACKEND)
        self.assertIn('def completeFirstRun', BACKEND)
        self.assertIn('def setAutostartEnabled', BACKEND)


    def test_silent_manual_listen_does_not_play_not_found(self) -> None:
        self.assertIn('is_silent_speech_capture_error', BACKEND)
        speech_error = BACKEND.split('def _on_speech_error', 1)[1].split('def _speech_finished', 1)[0]
        self.assertNotIn('_speak("not_found"', speech_error)


    def test_reactive_orb_and_visual_events_are_connected(self) -> None:
        self.assertIn('id: orbStage', QML)
        self.assertIn('function onOrbVisualEvent(eventName)', QML)
        self.assertIn('backend.audioLevel', QML)
        self.assertIn('orbVisualEvent = Signal(str)', BACKEND)
        self.assertIn('worker.levelChanged.connect(self._on_audio_level)', BACKEND)

    def test_animation_settings_are_exposed(self) -> None:
        self.assertIn('Анимация сферы', QML)
        self.assertIn('backend.setAnimationIntensity', QML)
        self.assertIn('backend.setMicrophoneReactiveAnimation', QML)
        self.assertIn('backend.setReduceMotion', QML)
        self.assertIn('def animationIntensity', BACKEND)
        self.assertIn('def reduceMotion', BACKEND)

    def test_modes_automations_and_hud_are_present(self) -> None:
        self.assertIn('Шаблоны режимов', QML)
        self.assertIn('id: executionHud', QML)
        self.assertIn('backend.saveAutomationCommand', QML)
        self.assertIn('triggerCombo', QML)
        self.assertIn('def saveAutomationCommand', BACKEND)
        self.assertIn('def _automation_tick', BACKEND)
        self.assertIn('def createModeTemplate', BACKEND)

    def test_safe_condition_actions_are_exposed(self) -> None:
        self.assertIn('Условие: файл существует', QML)
        catalog = (ROOT / "aura" / "catalog.py").read_text(encoding="utf-8")
        self.assertIn('require_window', catalog)
        self.assertIn('require_time', catalog)

    def test_sidebar_is_compact_without_type_or_trigger_labels(self) -> None:
        sidebar = QML.split('id: commandColumn', 1)[1].split('SoftButton {', 1)[0]
        self.assertNotIn('text: "Тип: " + modelData.type_label', sidebar)
        self.assertNotIn('text: "Запуск: " + modelData.trigger_label', sidebar)
        self.assertIn('text: modelData.preview', sidebar)
        self.assertNotIn('id: favoriteButton', sidebar)
        self.assertNotIn('id: runSidebarButton', sidebar)

    def test_favorites_feature_is_removed(self) -> None:
        self.assertNotIn('text: "Избранное"', QML)
        self.assertNotIn('id: favoriteSwitch', QML)
        self.assertNotIn('id: favoriteModesList', QML)
        self.assertNotIn('def setCommandFavorite', BACKEND)
        self.assertNotIn('favorite: bool', (ROOT / "aura" / "models.py").read_text(encoding="utf-8"))

    def test_editor_footer_keeps_buttons_inside_dialog(self) -> None:
        self.assertIn('id: editorFooter', QML)
        footer = QML.split('id: editorFooter', 1)[1].split('Dialog {', 1)[0]
        self.assertIn('anchors.bottom: parent.bottom', footer)
        self.assertIn('text: backend.testingScenario ? "Проверяю…" : "▶  Пробный запуск"', footer)
        self.assertIn('text: "Отмена"', footer)
        self.assertIn('text: "Сохранить"', footer)

    def test_type_and_trigger_have_explanations(self) -> None:
        self.assertIn('Команда выполняет отдельную задачу', QML)
        self.assertIn('Режим объединяет несколько действий', QML)
        self.assertIn('Сценарий запустится после одной из голосовых фраз', QML)
        self.assertIn('Сценарий запустится автоматически после старта AURA', QML)


    def test_quality_release_features_are_wired(self) -> None:
        self.assertIn('id: commandPalette', QML)
        self.assertIn('id: actionPicker', QML)
        self.assertIn('backend.validateDraft', QML)
        self.assertIn('backend.duplicateCommand', QML)
        self.assertIn('backend.exportCommand', QML)
        self.assertIn('function onToastRequested', QML)


    def test_easy_builder_is_the_default_new_command_flow(self) -> None:
        self.assertIn('id: easyBuilder', QML)
        self.assertIn('Три простых шага, без лишних настроек', QML)
        self.assertIn('function createCommand()', QML)
        create_block = QML.split('function createCommand()', 1)[1].split('function createAdvancedCommand()', 1)[0]
        self.assertIn('easyBuilder.open()', create_block)
        self.assertIn('backend.suggestCommandDraft', QML)

    def test_advanced_options_are_hidden_until_requested(self) -> None:
        self.assertIn('property bool showAutomationSettings: false', QML)
        self.assertIn('text: editor.showAutomationSettings ? "Скрыть автоматизацию" : "Расписание и режим"', QML)
        self.assertIn('property bool advancedOpen: retry_count > 0 || continue_on_error', QML)
        self.assertIn('text: actionCard.advancedOpen ? "Скрыть настройки" : "Дополнительно"', QML)

    def test_easy_builder_supports_native_file_pickers(self) -> None:
        self.assertIn('backend.chooseProgram()', QML)
        self.assertIn('backend.chooseFile()', QML)
        self.assertIn('backend.chooseFolder()', QML)
        self.assertIn('def chooseProgram', BACKEND)
        self.assertIn('def chooseFile', BACKEND)
        self.assertIn('def chooseFolder', BACKEND)

    def test_advanced_step_options_are_persisted(self) -> None:
        self.assertIn('"retry_count": Number(item.retry_count || 0)', QML)
        self.assertIn('"continue_on_error": Boolean(item.continue_on_error)', QML)
        self.assertIn('Продолжить при ошибке', QML)


if __name__ == "__main__":
    unittest.main()
