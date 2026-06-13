from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QObject, Property, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtWidgets import QFileDialog

from .actions import ActionError, ActionExecutor
from .engine import CommandMatcher
from .models import ActionStep, VoiceCommand
from .recorder import ActionRecorder
from .settings import AssistantSettings, SettingsStore
from .speech import SpeechWorker
from .storage import CommandStore
from .system_tools import (
    create_backup,
    list_microphones,
    prune_backups,
    restore_backup,
    set_autostart,
    test_microphone,
)
from .update_client import (
    GitHubUpdateClient,
    ReleaseInfo,
    UpdateConfig,
    UpdateError,
    clear_old_updates,
    load_config,
    update_cache_dir,
)
from .voice_assets import resolve_voice_file, voice_pack_is_ready
from .voice_feedback import VoiceFeedbackWorker
from .voice_utils import strip_leading_wake_phrase, is_silent_speech_capture_error
from .wakeword import WakeWordWorker

try:
    import keyboard
except ImportError:
    keyboard = None


ACTION_CATALOG = [
    {"type": "open_url", "label": "Открыть сайт", "hint": "https://example.com"},
    {"type": "open_app", "label": "Открыть программу", "hint": "calc, notepad или путь к EXE"},
    {"type": "open_path", "label": "Открыть файл или папку", "hint": r"C:\Users\Имя\Documents"},
    {"type": "hotkey", "label": "Нажать сочетание", "hint": "ctrl+shift+s"},
    {"type": "key", "label": "Нажать клавишу", "hint": "volumeup, enter, playpause"},
    {"type": "type_text", "label": "Вставить текст", "hint": "Текст для вставки"},
    {"type": "wait", "label": "Подождать", "hint": "Количество секунд, например 2"},
    {"type": "mouse_click", "label": "Клик мышью", "hint": "x,y,left,1"},
    {"type": "mouse_scroll", "label": "Прокрутить", "hint": "Число шагов, например -5"},
    {"type": "activate_window", "label": "Активировать окно", "hint": "Часть заголовка окна"},
    {"type": "wait_window", "label": "Дождаться окна", "hint": "Название окна|10"},
    {"type": "minimize_window", "label": "Свернуть окно", "hint": "Часть заголовка окна"},
    {"type": "maximize_window", "label": "Развернуть окно", "hint": "Часть заголовка окна"},
    {"type": "close_window", "label": "Закрыть окно", "hint": "Часть заголовка окна"},
    {"type": "require_file", "label": "Условие: файл существует", "hint": r"C:\Путь\к\файлу"},
    {"type": "require_window", "label": "Условие: окно открыто", "hint": "Часть заголовка окна"},
    {"type": "require_time", "label": "Условие: время", "hint": "09:00-18:00"},
    {"type": "shell", "label": "Системная команда", "hint": "Команда CMD. Используйте осторожно"},
]
ACTION_LABELS = {item["type"]: item["label"] for item in ACTION_CATALOG}

MODE_TEMPLATES = [
    {
        "id": "work",
        "name": "Рабочий режим",
        "description": "Почта, браузер и папка проекта",
        "phrases": ["рабочий режим", "начать работу"],
        "actions": [
            {"action_type": "open_url", "value": "https://mail.google.com", "delay_after": 1.0},
            {"action_type": "open_app", "value": "explorer"},
        ],
    },
    {
        "id": "gaming",
        "name": "Игровой режим",
        "description": "Запуск Steam и Discord",
        "phrases": ["игровой режим", "пора играть"],
        "actions": [
            {"action_type": "open_url", "value": "steam://open/main", "delay_after": 1.5},
            {"action_type": "open_url", "value": "discord://-/channels/@me"},
        ],
    },
    {
        "id": "focus",
        "name": "Режим концентрации",
        "description": "Рабочий сайт и тихая пауза",
        "phrases": ["режим концентрации", "сосредоточиться"],
        "actions": [
            {"action_type": "open_url", "value": "https://calendar.google.com", "delay_after": 1.0},
            {"action_type": "wait", "value": "1"},
        ],
    },
    {
        "id": "evening",
        "name": "Вечерний режим",
        "description": "Медиа и папка загрузок",
        "phrases": ["вечерний режим", "время отдыхать"],
        "actions": [
            {"action_type": "open_url", "value": "https://youtube.com", "delay_after": 1.0},
            {"action_type": "open_path", "value": "${downloads}"},
        ],
    },
]

TRIGGER_LABELS = {
    "voice": "по голосовой фразе",
    "startup": "при запуске AURA",
    "daily": "каждый день",
}


class ExecutionWorker(QObject):
    progress = Signal(int, int, str)
    finished = Signal(str)
    failed = Signal(str)
    done = Signal()

    def __init__(self, executor: ActionExecutor, command: VoiceCommand) -> None:
        super().__init__()
        self.executor = executor
        self.command = command

    @Slot()
    def run(self) -> None:
        try:
            result = self.executor.execute(
                self.command,
                lambda current, total, text: self.progress.emit(current, total, text),
            )
            self.finished.emit(result)
        except (ActionError, OSError, ValueError) as exc:
            logging.warning("Command execution failed: %s", exc)
            self.failed.emit(str(exc))
        except Exception as exc:
            logging.exception("Unexpected command execution failure")
            self.failed.emit(f"Непредвиденная ошибка: {exc}")
        finally:
            self.done.emit()


class ActionTestWorker(QObject):
    finished = Signal(int, str)
    failed = Signal(int, str)
    done = Signal()

    def __init__(self, index: int, step: ActionStep) -> None:
        super().__init__()
        self.index = index
        self.step = step
        self.executor = ActionExecutor()

    @Slot()
    def run(self) -> None:
        try:
            self.executor.reset_stop()
            self.executor.execute_step(self.step)
            self.finished.emit(self.index, f"Шаг {self.index + 1} выполнен")
        except (ActionError, OSError, ValueError) as exc:
            self.failed.emit(self.index, str(exc))
        except Exception as exc:
            logging.exception("Unexpected action test failure")
            self.failed.emit(self.index, f"Непредвиденная ошибка: {exc}")
        finally:
            self.done.emit()


class ScenarioTestWorker(QObject):
    progress = Signal(int, int, str)
    finished = Signal(str)
    failed = Signal(str)
    done = Signal()

    def __init__(self, command: VoiceCommand) -> None:
        super().__init__()
        self.command = command
        self.executor = ActionExecutor()

    @Slot()
    def run(self) -> None:
        try:
            result = self.executor.execute(
                self.command,
                lambda current, total, text: self.progress.emit(current, total, text),
            )
            self.finished.emit(result)
        except (ActionError, OSError, ValueError) as exc:
            self.failed.emit(str(exc))
        except Exception as exc:
            logging.exception("Unexpected scenario test failure")
            self.failed.emit(f"Непредвиденная ошибка: {exc}")
        finally:
            self.done.emit()


class RecordingWorker(QObject):
    finished = Signal(object)
    failed = Signal(str)
    done = Signal()

    def __init__(self, recorder: ActionRecorder) -> None:
        super().__init__()
        self.recorder = recorder

    @Slot()
    def run(self) -> None:
        try:
            self.finished.emit(self.recorder.run())
        except Exception as exc:
            logging.exception("Action recording failed")
            self.failed.emit(str(exc))
        finally:
            self.done.emit()


class MicrophoneTestWorker(QObject):
    levelChanged = Signal(int)
    finished = Signal(bool, str, int)
    done = Signal()

    def __init__(self, microphone_index: int | None) -> None:
        super().__init__()
        self.microphone_index = microphone_index

    @Slot()
    def run(self) -> None:
        try:
            success, message, peak = test_microphone(
                self.microphone_index,
                on_level=self.levelChanged.emit,
            )
            self.finished.emit(success, message, peak)
        except Exception as exc:
            logging.exception("Microphone test failed")
            self.finished.emit(False, f"Не удалось проверить микрофон: {exc}", 0)
        finally:
            self.done.emit()


class DiagnosticsWorker(QObject):
    finished = Signal(object)
    done = Signal()

    def __init__(
        self,
        data_dir: Path,
        commands_path: Path,
        wake_model_path: Path,
        voice_assets_path: Path,
        update_configured: bool,
        hotkeys_ready: bool,
    ) -> None:
        super().__init__()
        self.data_dir = Path(data_dir)
        self.commands_path = Path(commands_path)
        self.wake_model_path = Path(wake_model_path)
        self.voice_assets_path = Path(voice_assets_path)
        self.update_configured = update_configured
        self.hotkeys_ready = hotkeys_ready

    @Slot()
    def run(self) -> None:
        rows: list[dict[str, str]] = []

        def add(name: str, ok: bool, details: str) -> None:
            rows.append({
                "name": name,
                "status": "Готово" if ok else "Ошибка",
                "details": details,
                "tone": "success" if ok else "error",
            })

        try:
            self.data_dir.mkdir(parents=True, exist_ok=True)
            probe = self.data_dir / ".diagnostic-write-test"
            probe.write_text("ok", encoding="utf-8")
            probe.unlink(missing_ok=True)
            add("Папка данных", True, str(self.data_dir))
        except OSError as exc:
            add("Папка данных", False, str(exc))

        try:
            count = len(list_microphones()) - 1
            add("Микрофоны", count > 0, f"Найдено устройств: {max(0, count)}")
        except Exception as exc:
            add("Микрофоны", False, str(exc))

        add("Фраза активации", self.wake_model_path.is_dir(), "Локальная модель найдена" if self.wake_model_path.is_dir() else "Модель Vosk не найдена")
        add("Голосовые ответы", voice_pack_is_ready(self.voice_assets_path), "Голосовой пакет готов" if voice_pack_is_ready(self.voice_assets_path) else "Голосовой пакет не создан")
        add("Горячие клавиши", self.hotkeys_ready, "Ctrl+Shift+Space и Ctrl+Shift+F12" if self.hotkeys_ready else "Глобальные клавиши не зарегистрированы")
        add("Обновления", self.update_configured, "Репозиторий настроен" if self.update_configured else "update_config.json не настроен")

        try:
            if self.commands_path.is_file():
                json.loads(self.commands_path.read_text(encoding="utf-8"))
            add("Файл команд", True, str(self.commands_path))
        except (OSError, json.JSONDecodeError) as exc:
            add("Файл команд", False, str(exc))

        try:
            request = urllib.request.Request("https://api.github.com", headers={"User-Agent": "AURA-Diagnostics/1.0"})
            with urllib.request.urlopen(request, timeout=5) as response:
                ok = 200 <= int(getattr(response, "status", 200)) < 400
            add("Интернет", ok, "GitHub доступен" if ok else "GitHub вернул ошибку")
        except Exception as exc:
            add("Интернет", False, str(exc))

        self.finished.emit(rows)
        self.done.emit()


class UpdateCheckWorker(QObject):
    found = Signal(object)
    noUpdate = Signal()
    failed = Signal(str)
    done = Signal()

    def __init__(self, client: GitHubUpdateClient, current_version: str, include_prerelease: bool = False) -> None:
        super().__init__()
        self.client = client
        self.current_version = current_version
        self.include_prerelease = include_prerelease

    @Slot()
    def run(self) -> None:
        try:
            release = self.client.check(self.current_version, include_prerelease=self.include_prerelease)
            if release:
                self.found.emit(release)
            else:
                self.noUpdate.emit()
        except UpdateError as exc:
            self.failed.emit(str(exc))
        except Exception as exc:
            logging.exception("Unexpected update check failure")
            self.failed.emit(f"Не удалось проверить обновления: {exc}")
        finally:
            self.done.emit()


class UpdateDownloadWorker(QObject):
    progress = Signal(int)
    finished = Signal(object, str)
    failed = Signal(str)
    done = Signal()

    def __init__(self, client: GitHubUpdateClient, release: ReleaseInfo) -> None:
        super().__init__()
        self.client = client
        self.release = release

    @Slot()
    def run(self) -> None:
        try:
            cache = update_cache_dir()
            installer = self.client.download(self.release, cache, self.progress.emit)
            clear_old_updates(cache, keep=installer)
            self.finished.emit(self.release, str(installer))
        except UpdateError as exc:
            self.failed.emit(str(exc))
        except Exception as exc:
            logging.exception("Unexpected update download failure")
            self.failed.emit(f"Не удалось скачать обновление: {exc}")
        finally:
            self.done.emit()


class AssistantBackend(QObject):
    commandsChanged = Signal()
    statusChanged = Signal()
    transcriptChanged = Signal()
    listeningChanged = Signal()
    busyChanged = Signal()
    recordingChanged = Signal()
    wakeStateChanged = Signal()
    voiceStateChanged = Signal()
    historyChanged = Signal()
    updateStateChanged = Signal()
    confirmationRequested = Signal(str, str)
    updateReady = Signal(str, str)
    recordingReady = Signal(str)
    hotkeyTriggered = Signal()
    stopHotkeyTriggered = Signal()
    actionTestResult = Signal(int, bool, str)
    scenarioTestProgress = Signal(int, int, str)
    scenarioTestFinished = Signal(bool, str)
    testingStateChanged = Signal()
    settingsChanged = Signal()
    microphoneStateChanged = Signal()
    diagnosticsChanged = Signal()
    audioLevelChanged = Signal()
    orbVisualEvent = Signal(str)
    executionStateChanged = Signal()

    def __init__(
        self,
        current_version: str,
        update_config_path: Path,
        updater_path: Path,
        application_path: Path,
        wake_model_path: Path,
        voice_assets_path: Path,
    ) -> None:
        super().__init__()
        self.store = CommandStore()
        self.matcher = CommandMatcher()
        self.executor = ActionExecutor()
        self.current_version = current_version
        self.update_config_path = update_config_path
        self.updater_path = updater_path
        self.application_path = application_path
        self.wake_model_path = Path(wake_model_path)
        self.voice_assets_path = Path(voice_assets_path)

        self._settings_store = SettingsStore(Path(self.store.path).parent)
        self._settings: AssistantSettings = self._settings_store.load()
        self._data_dir = Path(self.store.path).parent
        self._microphones = list_microphones()
        available_indexes = {int(item.get("index", -1)) for item in self._microphones}
        if self._settings.microphone_index is not None and self._settings.microphone_index not in available_indexes:
            self._settings.microphone_index = None
            self._save_settings()
        self._microphone_testing = False
        self._microphone_level = 0
        self._microphone_test_message = ""
        self._audio_level = 0
        self._microphone_test_thread: QThread | None = None
        self._microphone_test_worker: MicrophoneTestWorker | None = None
        self._pending_microphone_test = False
        self._diagnostics: list[dict[str, str]] = []
        self._diagnostics_running = False
        self._diagnostics_thread: QThread | None = None
        self._diagnostics_worker: DiagnosticsWorker | None = None

        self._status = "Готов к работе"
        self._transcript = ""
        self._listening = False
        self._busy = False
        self._recording = False
        self._history: list[dict[str, str]] = []
        self._pending_command: VoiceCommand | None = None
        self._active_command: VoiceCommand | None = None
        self._execution_current = 0
        self._execution_total = 0
        self._execution_text = ""

        self._automation_queue: list[VoiceCommand] = []
        self._automation_last_run: dict[str, str] = {}
        self._startup_automations_queued = False

        self._speech_thread: QThread | None = None
        self._speech_worker: SpeechWorker | None = None
        self._recognition_from_wake = False
        self._execution_thread: QThread | None = None
        self._execution_worker: ExecutionWorker | None = None
        self._recording_thread: QThread | None = None
        self._recording_worker: RecordingWorker | None = None
        self._recorder: ActionRecorder | None = None

        self._testing_action_index = -1
        self._action_test_thread: QThread | None = None
        self._action_test_worker: ActionTestWorker | None = None
        self._pending_action_test: tuple[int, str, str] | None = None
        self._testing_scenario = False
        self._scenario_test_thread: QThread | None = None
        self._scenario_test_worker: ScenarioTestWorker | None = None

        self._wake_enabled = bool(self._settings.wake_enabled)
        self._wake_listening = False
        self._wake_thread: QThread | None = None
        self._wake_worker: WakeWordWorker | None = None
        self._pending_listen = False
        self._pending_recording = False
        self._wake_error_shown = False
        self._pending_captured_audio: dict[str, object] | None = None

        self._voice_pack_ready = voice_pack_is_ready(self.voice_assets_path)
        self._voice_enabled = bool(self._settings.voice_feedback_enabled and self._voice_pack_ready)
        self._voice_speaking = False
        self._voice_thread: QThread | None = None
        self._voice_worker: VoiceFeedbackWorker | None = None
        self._voice_after: object | None = None
        self._voice_queue: list[tuple[str, object | None]] = []
        self._execution_feedback_key = "done"

        self._hotkey_registered = False
        self._hotkey_handle = None
        self._stop_hotkey_handle = None

        self._update_config = self._safe_load_update_config()
        self._update_client = GitHubUpdateClient(self._update_config)
        self._update_thread: QThread | None = None
        self._update_worker: QObject | None = None
        self._update_manual = False
        self._update_busy = False
        self._update_version = ""
        self._update_notes = ""
        self._downloaded_installer: Path | None = None

        self.hotkeyTriggered.connect(self.toggleListening)
        self.stopHotkeyTriggered.connect(self.stopExecution)
        QTimer.singleShot(350, self._register_hotkeys)
        QTimer.singleShot(1400, self.startWakeListening)
        QTimer.singleShot(5000, self._automatic_update_check)

        self._update_timer = QTimer(self)
        self._update_timer.setInterval(self._update_config.check_interval_minutes * 60 * 1000)
        self._update_timer.timeout.connect(self._automatic_update_check)
        if self._update_config.configured:
            self._update_timer.start()

        self._automation_timer = QTimer(self)
        self._automation_timer.setInterval(15_000)
        self._automation_timer.timeout.connect(self._automation_tick)
        self._automation_timer.start()
        QTimer.singleShot(3200, self._queue_startup_automations)

    @Property("QVariantList", notify=commandsChanged)
    def commands(self) -> list[dict[str, object]]:
        result: list[dict[str, object]] = []
        for command in self.store.all():
            actions = [step.to_dict() for step in command.actions]
            preview = "  •  ".join(ACTION_LABELS.get(step.action_type, step.action_type) for step in command.actions[:2])
            if len(command.actions) > 2:
                preview += f"  +{len(command.actions) - 2}"
            first_step = command.actions[0] if command.actions else ActionStep("open_url", "")
            trigger_label = TRIGGER_LABELS.get(command.trigger_type, command.trigger_type)
            if command.trigger_type == "daily" and command.trigger_value:
                trigger_label = f"Каждый день в {command.trigger_value}"
            result.append({
                **command.to_dict(),
                "actions": actions,
                "phrases_text": ", ".join(command.phrases),
                "steps_count": len(command.actions),
                "preview": preview,
                "action_type": first_step.action_type,
                "action_value": first_step.value,
                "action_label": ACTION_LABELS.get(first_step.action_type, first_step.action_type),
                "trigger_label": trigger_label,
                "type_label": "режим компьютера" if command.command_type == "mode" else "обычная команда",
            })
        return result

    @Property("QVariantList", constant=True)
    def actionCatalog(self) -> list[dict[str, str]]:
        return ACTION_CATALOG

    @Property("QVariantList", constant=True)
    def modeTemplates(self) -> list[dict[str, object]]:
        return MODE_TEMPLATES

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=transcriptChanged)
    def transcript(self) -> str:
        return self._transcript

    @Property(bool, notify=listeningChanged)
    def listening(self) -> bool:
        return self._listening

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy

    @Property(int, notify=executionStateChanged)
    def executionCurrent(self) -> int:
        return self._execution_current

    @Property(int, notify=executionStateChanged)
    def executionTotal(self) -> int:
        return self._execution_total

    @Property(str, notify=executionStateChanged)
    def executionText(self) -> str:
        return self._execution_text

    @Property(str, notify=executionStateChanged)
    def activeCommandName(self) -> str:
        return self._active_command.name if self._active_command else ""

    @Property(bool, notify=recordingChanged)
    def recording(self) -> bool:
        return self._recording

    @Property(int, notify=testingStateChanged)
    def testingActionIndex(self) -> int:
        return self._testing_action_index

    @Property(bool, notify=testingStateChanged)
    def testingScenario(self) -> bool:
        return self._testing_scenario

    @Property(bool, notify=wakeStateChanged)
    def wakeEnabled(self) -> bool:
        return self._wake_enabled

    @Property(bool, notify=wakeStateChanged)
    def wakeListening(self) -> bool:
        return self._wake_listening

    @Property(str, notify=wakeStateChanged)
    def wakePhrase(self) -> str:
        return self._settings.wake_phrase

    @Property(bool, notify=voiceStateChanged)
    def voiceFeedbackEnabled(self) -> bool:
        return self._voice_enabled

    @Property(bool, notify=voiceStateChanged)
    def voiceSpeaking(self) -> bool:
        return self._voice_speaking

    @Property("QVariantList", notify=historyChanged)
    def history(self) -> list[dict[str, str]]:
        return self._history[:20]

    @Property(str, constant=True)
    def dataPath(self) -> str:
        return str(self.store.path)

    @Property(str, constant=True)
    def version(self) -> str:
        return self.current_version

    @Property(bool, notify=updateStateChanged)
    def updateBusy(self) -> bool:
        return self._update_busy

    @Property(str, notify=updateStateChanged)
    def updateVersion(self) -> str:
        return self._update_version

    @Property(bool, notify=settingsChanged)
    def firstRunCompleted(self) -> bool:
        return bool(self._settings.first_run_completed)

    @Property("QVariantList", notify=settingsChanged)
    def microphones(self) -> list[dict[str, object]]:
        return self._microphones

    @Property(int, notify=settingsChanged)
    def selectedMicrophoneIndex(self) -> int:
        return -1 if self._settings.microphone_index is None else int(self._settings.microphone_index)

    @Property(bool, notify=microphoneStateChanged)
    def microphoneTesting(self) -> bool:
        return self._microphone_testing

    @Property(int, notify=microphoneStateChanged)
    def microphoneLevel(self) -> int:
        return self._microphone_level

    @Property(str, notify=microphoneStateChanged)
    def microphoneTestMessage(self) -> str:
        return self._microphone_test_message

    @Property(int, notify=audioLevelChanged)
    def audioLevel(self) -> int:
        return self._audio_level

    @Property(str, notify=settingsChanged)
    def animationIntensity(self) -> str:
        return self._settings.animation_intensity

    @Property(bool, notify=settingsChanged)
    def microphoneReactiveAnimation(self) -> bool:
        return bool(self._settings.microphone_reactive_animation)

    @Property(bool, notify=settingsChanged)
    def reduceMotion(self) -> bool:
        return bool(self._settings.reduce_motion)

    @Property(str, notify=settingsChanged)
    def updateChannel(self) -> str:
        return self._settings.update_channel

    @Property(bool, notify=settingsChanged)
    def autostartEnabled(self) -> bool:
        return bool(self._settings.autostart_enabled)

    @Property("QVariantList", notify=diagnosticsChanged)
    def diagnostics(self) -> list[dict[str, str]]:
        return self._diagnostics

    @Property(bool, notify=diagnosticsChanged)
    def diagnosticsRunning(self) -> bool:
        return self._diagnostics_running

    @Property(str, constant=True)
    def backupFolder(self) -> str:
        return str(self._data_dir / "backups")

    @Slot(str, result=str)
    def actionLabel(self, action_type: str) -> str:
        return ACTION_LABELS.get(action_type, action_type)

    @Slot()
    def toggleListening(self) -> None:
        if self._listening or self._busy or self._recording or self._voice_speaking:
            return
        if self._wake_thread is not None:
            self._pending_listen = True
            self._stop_wake_listener()
            return
        self._start_speech_listening()

    def _start_speech_listening(self, audio_payload: dict[str, object] | None = None) -> None:
        if self._speech_thread is not None or self._busy or self._recording or self._voice_speaking:
            return
        self._recognition_from_wake = audio_payload is not None
        self._set_listening(True)
        self._set_status("Распознаю команду…" if audio_payload is not None else "Слушаю…")
        self._transcript = ""
        self.transcriptChanged.emit()

        thread = QThread(self)
        worker = SpeechWorker(
            microphone_index=self._settings.microphone_index,
            audio_payload=audio_payload,
        )
        worker.moveToThread(thread)
        thread.started.connect(worker.listen_once)
        worker.recognized.connect(self._on_recognized)
        worker.failed.connect(self._on_speech_error)
        worker.finished.connect(thread.quit)
        worker.finished.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._speech_finished)
        self._speech_thread = thread
        self._speech_worker = worker
        thread.start()

    @Slot()
    def startWakeListening(self) -> None:
        if not self._wake_enabled or self._wake_thread is not None:
            return
        if self._listening or self._busy or self._recording or self._voice_speaking:
            return
        if not self.wake_model_path.is_dir():
            if not self._wake_error_shown:
                self._set_status("Голосовая активация недоступна: модель не найдена")
                self._wake_error_shown = True
            return

        thread = QThread(self)
        worker = WakeWordWorker(
            model_path=self.wake_model_path,
            wake_phrase=self._settings.wake_phrase,
            microphone_index=self._settings.microphone_index,
        )
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.activated.connect(self._on_wake_activated)
        worker.commandCaptured.connect(self._on_wake_command_captured)
        worker.commandFailed.connect(self._on_wake_command_error)
        worker.levelChanged.connect(self._on_audio_level)
        worker.failed.connect(self._on_wake_error)
        worker.finished.connect(thread.quit)
        worker.finished.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._wake_thread_cleanup)
        self._wake_thread = thread
        self._wake_worker = worker
        self._set_wake_listening(True)
        thread.start()

    @Slot(bool)
    def setVoiceFeedbackEnabled(self, enabled: bool) -> None:
        enabled = bool(enabled)
        if enabled and not self._voice_pack_ready:
            self._set_status("Голосовой пакет не создан. Запустите GENERATE_SILERO_VOICE.cmd")
            return
        if self._voice_enabled == enabled:
            return
        self._voice_enabled = enabled
        if not enabled:
            self._voice_queue.clear()
        self._settings.voice_feedback_enabled = enabled
        self._save_settings()
        self.voiceStateChanged.emit()
        self.settingsChanged.emit()
        self._set_status("Голосовые ответы включены" if enabled else "Голосовые ответы выключены")

    @Slot(bool)
    def setWakeEnabled(self, enabled: bool) -> None:
        enabled = bool(enabled)
        if enabled and not self.wake_model_path.is_dir():
            self._set_status("Не найдена локальная модель активации")
            return
        if self._wake_enabled == enabled:
            return
        self._wake_enabled = enabled
        self._settings.wake_enabled = enabled
        self._save_settings()
        self.wakeStateChanged.emit()
        self.settingsChanged.emit()
        if enabled:
            self._wake_error_shown = False
            self._set_status(f"Активация фразой «{self._settings.wake_phrase.capitalize()}» включена")
            QTimer.singleShot(150, self.startWakeListening)
        else:
            self._stop_wake_listener()
            self._set_status("Голосовая активация выключена")

    @Slot(str)
    def setAnimationIntensity(self, value: str) -> None:
        value = str(value or "normal").strip().lower()
        if value not in {"low", "normal", "high"}:
            value = "normal"
        if self._settings.animation_intensity == value:
            return
        self._settings.animation_intensity = value
        self._save_settings()
        self.settingsChanged.emit()

    @Slot(bool)
    def setMicrophoneReactiveAnimation(self, enabled: bool) -> None:
        enabled = bool(enabled)
        if self._settings.microphone_reactive_animation == enabled:
            return
        self._settings.microphone_reactive_animation = enabled
        if not enabled:
            self._set_audio_level(0)
        self._save_settings()
        self.settingsChanged.emit()

    @Slot(bool)
    def setReduceMotion(self, enabled: bool) -> None:
        enabled = bool(enabled)
        if self._settings.reduce_motion == enabled:
            return
        self._settings.reduce_motion = enabled
        self._save_settings()
        self.settingsChanged.emit()

    @Slot()
    def refreshMicrophones(self) -> None:
        self._microphones = list_microphones()
        self.settingsChanged.emit()

    @Slot(int)
    def setMicrophoneIndex(self, index: int) -> None:
        requested = int(index)
        available = {int(item.get("index", -1)) for item in self._microphones}
        if requested not in available:
            self._set_status("Выбранный микрофон больше недоступен")
            return
        value = None if requested < 0 else requested
        if self._settings.microphone_index == value:
            return
        self._settings.microphone_index = value
        self._save_settings()
        self.settingsChanged.emit()
        self._set_status("Микрофон изменён")
        if self._wake_thread is not None:
            self._stop_wake_listener()
        else:
            QTimer.singleShot(180, self.startWakeListening)

    @Slot(str)
    def setWakePhrase(self, phrase: str) -> None:
        cleaned = " ".join(str(phrase or "").strip().casefold().split())[:40]
        if not cleaned:
            self._set_status("Введите фразу активации")
            return
        if cleaned == self._settings.wake_phrase:
            return
        self._settings.wake_phrase = cleaned
        self._save_settings()
        self.settingsChanged.emit()
        self.wakeStateChanged.emit()
        self._set_status(f"Фраза активации: «{cleaned.capitalize()}»")
        if self._wake_thread is not None:
            self._stop_wake_listener()
        elif self._wake_enabled:
            QTimer.singleShot(180, self.startWakeListening)

    @Slot(str)
    def setUpdateChannel(self, channel: str) -> None:
        value = str(channel or "stable").strip().lower()
        if value not in {"stable", "beta"}:
            value = "stable"
        if self._settings.update_channel == value:
            return
        self._settings.update_channel = value
        self._save_settings()
        self.settingsChanged.emit()
        self._set_status("Канал обновлений: стабильный" if value == "stable" else "Канал обновлений: тестовый")
        QTimer.singleShot(250, self._automatic_update_check)

    @Slot(bool)
    def setAutostartEnabled(self, enabled: bool) -> None:
        enabled = bool(enabled)
        if getattr(sys, "frozen", False):
            executable = self.application_path
            arguments: list[str] = []
        else:
            executable = Path(sys.executable)
            arguments = [str(self.application_path)]
        success, message = set_autostart(enabled, executable, arguments)
        if success:
            self._settings.autostart_enabled = enabled
            self._save_settings()
            self.settingsChanged.emit()
        self._set_status(message)

    @Slot()
    def completeFirstRun(self) -> None:
        if self._settings.first_run_completed:
            return
        self._settings.first_run_completed = True
        self._save_settings()
        self.settingsChanged.emit()
        self._set_status("Первичная настройка завершена")

    @Slot()
    def startMicrophoneTest(self) -> None:
        if self._microphone_testing:
            return
        if self._busy or self._recording or self._listening:
            self._set_status("Сначала завершите текущее действие")
            return
        if self._wake_thread is not None:
            self._pending_microphone_test = True
            self._stop_wake_listener()
            return
        self._start_microphone_test_now()

    def _start_microphone_test_now(self) -> None:
        if self._microphone_testing or self._microphone_test_thread is not None:
            return
        self._microphone_testing = True
        self._microphone_level = 0
        self._microphone_test_message = "Говорите обычным голосом…"
        self.microphoneStateChanged.emit()
        thread = QThread(self)
        worker = MicrophoneTestWorker(self._settings.microphone_index)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.levelChanged.connect(self._on_microphone_level)
        worker.finished.connect(self._on_microphone_test_finished)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._microphone_test_cleanup)
        self._microphone_test_thread = thread
        self._microphone_test_worker = worker
        self._set_status("Проверяю микрофон…")
        thread.start()

    @Slot(int)
    def _on_microphone_level(self, level: int) -> None:
        self._microphone_level = max(0, min(100, int(level)))
        self.microphoneStateChanged.emit()

    @Slot(bool, str, int)
    def _on_microphone_test_finished(self, success: bool, message: str, peak: int) -> None:
        self._microphone_level = max(self._microphone_level, int(peak))
        self._microphone_test_message = message
        self._set_status(message)
        self.microphoneStateChanged.emit()

    @Slot()
    def _microphone_test_cleanup(self) -> None:
        self._microphone_test_thread = None
        self._microphone_test_worker = None
        self._microphone_testing = False
        self.microphoneStateChanged.emit()
        QTimer.singleShot(220, self.startWakeListening)

    @Slot()
    def createBackup(self) -> None:
        try:
            target = create_backup(self._data_dir)
            prune_backups(self._data_dir)
            self._set_status(f"Резервная копия создана: {target.name}")
            self.openBackupsFolder()
        except OSError as exc:
            self._set_status(f"Не удалось создать резервную копию: {exc}")

    @Slot()
    def openBackupsFolder(self) -> None:
        folder = self._data_dir / "backups"
        folder.mkdir(parents=True, exist_ok=True)
        try:
            self.executor.execute_step(ActionStep("open_path", str(folder)))
        except ActionError as exc:
            self._set_status(str(exc))

    @Slot()
    def restoreBackup(self) -> None:
        folder = self._data_dir / "backups"
        folder.mkdir(parents=True, exist_ok=True)
        filename, _filter = QFileDialog.getOpenFileName(
            None,
            "Восстановить резервную копию AURA",
            str(folder),
            "AURA backup (*.zip)",
        )
        if not filename:
            return
        success, message = restore_backup(Path(filename), self._data_dir)
        self._set_status(message)
        if success:
            self.settingsChanged.emit()

    @Slot()
    def runDiagnostics(self) -> None:
        if self._diagnostics_running or self._diagnostics_thread is not None:
            return
        self._diagnostics_running = True
        self._diagnostics = []
        self.diagnosticsChanged.emit()
        thread = QThread(self)
        worker = DiagnosticsWorker(
            data_dir=self._data_dir,
            commands_path=Path(self.store.path),
            wake_model_path=self.wake_model_path,
            voice_assets_path=self.voice_assets_path,
            update_configured=self._update_config.configured,
            hotkeys_ready=self._hotkey_registered or not sys.platform.startswith("win"),
        )
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.finished.connect(self._on_diagnostics_finished)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._diagnostics_cleanup)
        self._diagnostics_thread = thread
        self._diagnostics_worker = worker
        self._set_status("Проверяю AURA…")
        thread.start()

    @Slot(object)
    def _on_diagnostics_finished(self, rows: object) -> None:
        self._diagnostics = [item for item in rows if isinstance(item, dict)] if isinstance(rows, list) else []
        failures = sum(1 for item in self._diagnostics if item.get("tone") == "error")
        self._set_status("Диагностика завершена" if failures == 0 else f"Диагностика: найдено проблем {failures}")
        self.diagnosticsChanged.emit()

    @Slot()
    def _diagnostics_cleanup(self) -> None:
        self._diagnostics_thread = None
        self._diagnostics_worker = None
        self._diagnostics_running = False
        self.diagnosticsChanged.emit()

    @Slot()
    def startRecording(self) -> None:
        if self._recording:
            return
        if self._busy or self._listening:
            self._set_status("Сначала завершите текущее действие")
            return
        if self._wake_thread is not None:
            self._pending_recording = True
            self._stop_wake_listener()
            return
        self._start_recording_now()

    def _start_recording_now(self) -> None:
        if self._recording or self._busy or self._listening:
            return
        recorder = ActionRecorder()
        thread = QThread(self)
        worker = RecordingWorker(recorder)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.finished.connect(self._on_recording_finished)
        worker.failed.connect(self._on_recording_failed)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._recording_cleanup)
        self._recorder = recorder
        self._recording_thread = thread
        self._recording_worker = worker
        self._set_recording(True)
        self._set_status("Записываю действия. Ctrl + Shift + F12 для завершения")
        thread.start()
        self._speak("recording_started")

    @Slot()
    def stopRecording(self) -> None:
        if not self._recording or self._recorder is None:
            return
        self._set_status("Завершаю запись действий…")
        self._recorder.stop()

    def _queue_startup_automations(self) -> None:
        if self._startup_automations_queued:
            return
        self._startup_automations_queued = True
        for command in self.store.all():
            if command.enabled and command.trigger_type == "startup":
                self._automation_queue.append(command)
        self._automation_tick()

    def _automation_tick(self) -> None:
        if self._busy or self._listening or self._recording or self._testing_scenario or self._action_test_thread is not None or self._pending_command is not None:
            return

        now = datetime.now()
        current_time = now.strftime("%H:%M")
        today = now.strftime("%Y-%m-%d")
        queued_ids = {item.id for item in self._automation_queue}
        for command in self.store.all():
            if not command.enabled or command.trigger_type != "daily":
                continue
            if command.trigger_value != current_time:
                continue
            run_key = f"{today}:{current_time}"
            if self._automation_last_run.get(command.id) == run_key or command.id in queued_ids:
                continue
            self._automation_last_run[command.id] = run_key
            self._automation_queue.append(command)
            queued_ids.add(command.id)

        if self._automation_queue:
            command = self._automation_queue.pop(0)
            self._run_automation(command)

    def _run_automation(self, command: VoiceCommand) -> None:
        self._transcript = f"Автоматизация: {command.name}"
        self.transcriptChanged.emit()
        if command.require_confirmation:
            self._pending_command = command
            details = "\n".join(
                f"{index}. {ACTION_LABELS.get(step.action_type, step.action_type)}: {step.value}"
                for index, step in enumerate(command.actions, 1)
            )
            self._set_status(f"Автоматизация «{command.name}» ждёт подтверждения")
            self.confirmationRequested.emit(command.name, details)
            self._speak("confirmation")
            return
        self._execute(command)

    @staticmethod
    def _normalize_daily_time(value: str) -> str:
        text = str(value or "").strip().replace(".", ":")
        try:
            hour_text, minute_text = text.split(":", 1)
            hour = int(hour_text)
            minute = int(minute_text)
        except (ValueError, TypeError):
            return ""
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            return ""
        return f"{hour:02d}:{minute:02d}"

    @Slot(str)
    def executeText(self, text: str) -> None:
        clean = text.strip()
        if not clean:
            self._set_status("Введите тестовую фразу")
            return
        if self._busy or self._recording:
            self._set_status("Сначала дождитесь завершения текущего действия")
            return
        self._transcript = clean
        self.transcriptChanged.emit()
        self._handle_transcript(clean)

    @Slot(int, str, str)
    def testAction(self, index: int, action_type: str, value: str) -> None:
        index = int(index)
        action_type = str(action_type or "").strip()
        value = str(value or "")
        if self._busy or self._recording or self._listening or self._testing_scenario or self._action_test_thread is not None:
            message = "Сначала завершите текущее действие"
            self._set_status(message)
            # Always finish the UI request. Without this signal the step card
            # remains forever in the visual “Проверяю…” state.
            self.actionTestResult.emit(index, False, message)
            return
        if action_type not in ACTION_LABELS:
            message = "Неизвестное действие"
            self._set_status(message)
            self.actionTestResult.emit(index, False, message)
            return
        if action_type == "shell":
            message = "Системные команды проверяются только после сохранения и подтверждения"
            self._set_status(message)
            self.actionTestResult.emit(index, False, message)
            return
        if action_type != "wait" and not value.strip():
            message = "Заполните значение шага"
            self._set_status(message)
            self.actionTestResult.emit(index, False, message)
            return

        # The wake-word worker owns the microphone. Stop it before a test so
        # keyboard, window and media actions are not competing with background
        # listening. The test starts immediately after the worker exits.
        if self._wake_thread is not None:
            self._pending_action_test = (index, action_type, value)
            self._set_status(f"Готовлю проверку шага {index + 1}…")
            self._stop_wake_listener()
            return
        self._start_action_test(index, action_type, value)

    def _start_action_test(self, index: int, action_type: str, value: str) -> None:
        if self._action_test_thread is not None:
            return
        step = ActionStep(action_type=action_type, value=value)
        thread = QThread(self)
        worker = ActionTestWorker(index, step)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.finished.connect(self._on_action_test_finished)
        worker.failed.connect(self._on_action_test_failed)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._action_test_cleanup)
        self._testing_action_index = index
        self._action_test_thread = thread
        self._action_test_worker = worker
        self.testingStateChanged.emit()
        self._set_status(f"Проверяю шаг {index + 1}…")
        thread.start()

    @Slot(str)
    def testScenario(self, actions_json: str) -> None:
        if self._busy or self._recording or self._listening or self._testing_scenario or self._action_test_thread is not None:
            self._set_status("Сначала завершите текущее действие")
            return
        try:
            raw_actions = json.loads(actions_json)
            if not isinstance(raw_actions, list):
                raise TypeError
            actions = [ActionStep.from_dict(item) for item in raw_actions if isinstance(item, dict)]
        except (json.JSONDecodeError, TypeError):
            actions = []
        if not actions:
            self._set_status("Добавьте хотя бы одно действие")
            self.scenarioTestFinished.emit(False, "Нет действий для проверки")
            return
        if any(step.action_type == "shell" for step in actions):
            message = "Сценарий с системной командой нельзя запускать в тестовом режиме"
            self._set_status(message)
            self.scenarioTestFinished.emit(False, message)
            return
        self._stop_wake_listener()
        command = VoiceCommand("Проверка сценария", ["test"], actions)
        thread = QThread(self)
        worker = ScenarioTestWorker(command)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.progress.connect(self._on_scenario_test_progress)
        worker.finished.connect(self._on_scenario_test_finished)
        worker.failed.connect(self._on_scenario_test_failed)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._scenario_test_cleanup)
        self._testing_scenario = True
        self._scenario_test_thread = thread
        self._scenario_test_worker = worker
        self.testingStateChanged.emit()
        self._set_busy(True)
        self._set_status("Проверяю сценарий…")
        thread.start()

    @Slot(int, str)
    def _on_action_test_finished(self, index: int, message: str) -> None:
        self._set_status(message)
        self.actionTestResult.emit(index, True, message)

    @Slot(int, str)
    def _on_action_test_failed(self, index: int, message: str) -> None:
        self._set_status(f"Ошибка шага {index + 1}: {message}")
        self.actionTestResult.emit(index, False, message)

    @Slot()
    def _action_test_cleanup(self) -> None:
        self._action_test_thread = None
        self._action_test_worker = None
        self._testing_action_index = -1
        self.testingStateChanged.emit()
        QTimer.singleShot(180, self.startWakeListening)

    @Slot(int, int, str)
    def _on_scenario_test_progress(self, current: int, total: int, text: str) -> None:
        self._set_status(f"Проверка {current}/{total}: {text}")
        self.scenarioTestProgress.emit(current, total, text)

    @Slot(str)
    def _on_scenario_test_finished(self, _message: str) -> None:
        message = "Все шаги выполнены успешно"
        self._set_status(message)
        self.scenarioTestFinished.emit(True, message)

    @Slot(str)
    def _on_scenario_test_failed(self, message: str) -> None:
        self._set_status(f"Проверка остановлена: {message}")
        self.scenarioTestFinished.emit(False, message)

    @Slot()
    def _scenario_test_cleanup(self) -> None:
        self._scenario_test_thread = None
        self._scenario_test_worker = None
        self._testing_scenario = False
        self.testingStateChanged.emit()
        self._set_busy(False)
        QTimer.singleShot(180, self.startWakeListening)

    @Slot(str, str, str, str, bool, result=bool)
    def saveCommand(self, command_id: str, name: str, phrases_text: str, actions_json: str, require_confirmation: bool) -> bool:
        existing = next((item for item in self.store.all() if item.id == command_id), None)
        return self._save_command_payload(
            command_id,
            name,
            phrases_text,
            actions_json,
            require_confirmation,
            existing.command_type if existing else "command",
            existing.trigger_type if existing else "voice",
            existing.trigger_value if existing else "",
        )

    @Slot(str, str, str, str, bool, str, str, str, result=bool)
    def saveAutomationCommand(
        self,
        command_id: str,
        name: str,
        phrases_text: str,
        actions_json: str,
        require_confirmation: bool,
        command_type: str,
        trigger_type: str,
        trigger_value: str,
    ) -> bool:
        return self._save_command_payload(
            command_id, name, phrases_text, actions_json, require_confirmation,
            command_type, trigger_type, trigger_value,
        )

    def _save_command_payload(
        self,
        command_id: str,
        name: str,
        phrases_text: str,
        actions_json: str,
        require_confirmation: bool,
        command_type: str,
        trigger_type: str,
        trigger_value: str,
    ) -> bool:
        phrases = [item.strip()[:160] for item in phrases_text.replace("\n", ",").split(",") if item.strip()][:20]
        try:
            raw_actions = json.loads(actions_json)
            if not isinstance(raw_actions, list):
                raise TypeError("actions must be a list")
            actions = [ActionStep.from_dict(item) for item in raw_actions[:200] if isinstance(item, dict)]
        except (json.JSONDecodeError, TypeError):
            actions = []

        command_type = str(command_type or "command").strip().lower()
        if command_type not in {"command", "mode"}:
            command_type = "command"
        trigger_type = str(trigger_type or "voice").strip().lower()
        if trigger_type not in {"voice", "startup", "daily"}:
            trigger_type = "voice"
        trigger_value = str(trigger_value or "").strip()
        if trigger_type == "daily":
            trigger_value = self._normalize_daily_time(trigger_value)
            if not trigger_value:
                self._set_status("Для ежедневного запуска укажите время в формате 09:30")
                return False
        else:
            trigger_value = ""

        # Voice phrases are optional for purely automatic scenarios.
        if not name.strip() or not actions or (trigger_type == "voice" and not phrases):
            self._set_status("Заполните название, фразы и добавьте хотя бы одно действие")
            return False
        allowed_types = set(ACTION_LABELS)
        for step in actions:
            if step.action_type not in allowed_types:
                self._set_status("В сценарии есть неизвестное действие")
                return False
            if not step.value.strip() and step.action_type != "wait":
                self._set_status("Заполните значения всех действий")
                return False

        command = VoiceCommand(
            id=command_id or VoiceCommand("", [], []).id,
            name=name.strip()[:120],
            phrases=phrases,
            actions=actions,
            require_confirmation=require_confirmation or any(step.action_type == "shell" for step in actions),
            command_type=command_type,
            trigger_type=trigger_type,
            trigger_value=trigger_value,
        )
        existing = next((item for item in self.store.all() if item.id == command.id), None)
        if existing:
            command.enabled = existing.enabled
        self.store.save(command)
        self.commandsChanged.emit()
        noun = "Режим" if command.command_type == "mode" else "Команда"
        self._set_status(f"{noun} «{command.name}» сохранён")
        return True

    @Slot(str)
    def runCommandById(self, command_id: str) -> None:
        if self._busy or self._recording or self._listening:
            self._set_status("Сначала дождитесь завершения текущего действия")
            return
        command = next((item for item in self.store.all() if item.id == command_id), None)
        if command is None or not command.enabled:
            self._set_status("Сценарий недоступен")
            return
        self._transcript = command.name
        self.transcriptChanged.emit()
        if command.require_confirmation:
            self._pending_command = command
            details = "\n".join(
                f"{index}. {ACTION_LABELS.get(step.action_type, step.action_type)}: {step.value}"
                for index, step in enumerate(command.actions, 1)
            )
            self.confirmationRequested.emit(command.name, details)
            self._set_status("Нужно подтверждение")
            self._speak("confirmation")
            return
        self._execute(command)

    @Slot(str)
    def createModeTemplate(self, template_id: str) -> None:
        template = next((item for item in MODE_TEMPLATES if item["id"] == template_id), None)
        if template is None:
            self._set_status("Шаблон не найден")
            return
        base_name = str(template["name"])
        existing_names = {item.name for item in self.store.all()}
        name = base_name
        suffix = 2
        while name in existing_names:
            name = f"{base_name} {suffix}"
            suffix += 1
        command = VoiceCommand(
            name=name,
            phrases=list(template["phrases"]),
            actions=[ActionStep.from_dict(item) for item in template["actions"]],
            command_type="mode",
        )
        self.store.save(command)
        self.commandsChanged.emit()
        self._set_status(f"Шаблон «{name}» добавлен")

    @Slot(str)
    def deleteCommand(self, command_id: str) -> None:
        command = next((item for item in self.store.all() if item.id == command_id), None)
        self.store.delete(command_id)
        self.commandsChanged.emit()
        self._set_status(f"Команда «{command.name}» удалена" if command else "Команда удалена")

    @Slot(str, bool)
    def setCommandEnabled(self, command_id: str, enabled: bool) -> None:
        self.store.set_enabled(command_id, enabled)
        self.commandsChanged.emit()
        self._set_status("Команда включена" if enabled else "Команда отключена")

    @Slot(bool)
    def answerConfirmation(self, accepted: bool) -> None:
        command = self._pending_command
        self._pending_command = None
        if not command:
            return
        if accepted:
            self._execute(command)
        else:
            self._set_status("Действие отменено")
            self._add_history(command.name, "Отменено")
            self._speak("cancelled", lambda: QTimer.singleShot(150, self.startWakeListening))
            QTimer.singleShot(350, self._automation_tick)

    @Slot()
    def stopExecution(self) -> None:
        if self._recording:
            self.stopRecording()
            return
        if self._action_test_worker is not None:
            self._action_test_worker.executor.stop()
            self._set_status("Останавливаю проверку шага…")
            return
        if self._testing_scenario and self._scenario_test_worker is not None:
            self._scenario_test_worker.executor.stop()
            self._set_status("Останавливаю проверку…")
            return
        if self._busy:
            self.executor.stop()
            self._set_status("Останавливаю сценарий…")

    @Slot()
    def openDataFolder(self) -> None:
        step = ActionStep("open_path", str(Path(self.store.path).parent))
        try:
            self.executor.execute_step(step)
        except ActionError as exc:
            self._set_status(str(exc))

    @Slot()
    def checkForUpdates(self) -> None:
        self._start_update_check(manual=True)

    @Slot()
    def installUpdate(self) -> None:
        installer = self._downloaded_installer
        if not installer or not installer.is_file():
            self._set_status("Файл обновления не найден. Повторите проверку")
            return
        if not getattr(sys, "frozen", False):
            self._set_status("Автоустановка работает в собранной версии AURA")
            return
        if not self.updater_path.is_file():
            self._set_status("Компонент AURAUpdater.exe не найден")
            return
        try:
            create_backup(self._data_dir)
            prune_backups(self._data_dir)
        except OSError:
            logging.exception("Unable to create pre-update backup")
        try:
            helper = update_cache_dir() / f"AURAUpdater-{self._update_version or 'next'}.exe"
            shutil.copy2(self.updater_path, helper)
            subprocess.Popen(
                [
                    str(helper),
                    "--wait-pid",
                    str(os.getpid()),
                    "--installer",
                    str(installer),
                    "--restart",
                    str(self.application_path),
                ],
                cwd=str(helper.parent),
                close_fds=True,
            )
        except OSError as exc:
            logging.exception("Unable to start updater")
            self._set_status(f"Не удалось запустить установку: {exc}")
            return
        self._set_status("AURA закроется и установит обновление")
        QTimer.singleShot(450, QGuiApplication.quit)

    @Slot()
    def quitApp(self) -> None:
        self.shutdown()
        QGuiApplication.quit()

    def shutdown(self) -> None:
        self._unregister_hotkeys()
        self.executor.stop()
        if self._action_test_worker is not None:
            self._action_test_worker.executor.stop()
        if self._scenario_test_worker is not None:
            self._scenario_test_worker.executor.stop()
        self._voice_queue.clear()
        self._stop_wake_listener()
        if self._recorder is not None:
            self._recorder.stop()
        for thread in (
            self._wake_thread,
            self._recording_thread,
            self._voice_thread,
            self._action_test_thread,
            self._scenario_test_thread,
            self._microphone_test_thread,
            self._diagnostics_thread,
        ):
            if thread is not None and thread.isRunning():
                thread.quit()
                thread.wait(1200)

    def _handle_transcript(self, text: str) -> None:
        match = self.matcher.find(text, self.store.all())
        if not match:
            self.orbVisualEvent.emit("error")
            self._set_status("Команда не найдена")
            self._add_history(text, "Не найдено")
            self._speak("not_found", lambda: QTimer.singleShot(150, self.startWakeListening))
            return
        command = match.command
        if command.require_confirmation:
            self._pending_command = command
            self._set_status("Нужно подтверждение")
            details = "\n".join(f"{i}. {ACTION_LABELS.get(s.action_type, s.action_type)}: {s.value}" for i, s in enumerate(command.actions, 1))
            self.confirmationRequested.emit(command.name, details)
            self._speak("confirmation")
            return
        self._execute(command)

    def _execute(self, command: VoiceCommand) -> None:
        if self._busy:
            return
        self._stop_wake_listener()
        self._active_command = command
        self._execution_feedback_key = "done"
        self._execution_current = 0
        self._execution_total = len([step for step in command.actions if step.enabled])
        self._execution_text = "Подготавливаю сценарий"
        self.executionStateChanged.emit()
        self._set_busy(True)
        self._set_status(f"Запускаю «{command.name}»")
        self._speak("executing")
        self._start_execution_worker(command)

    def _start_execution_worker(self, command: VoiceCommand) -> None:
        if not self._busy or self._active_command is not command or self._execution_thread is not None:
            return
        thread = QThread(self)
        worker = ExecutionWorker(self.executor, command)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.progress.connect(self._on_execution_progress)
        worker.finished.connect(self._on_execution_finished)
        worker.failed.connect(self._on_execution_failed)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._execution_cleanup)
        self._execution_thread = thread
        self._execution_worker = worker
        thread.start()

    @Slot(int, int, str)
    def _on_execution_progress(self, current: int, total: int, text: str) -> None:
        self._execution_current = current
        self._execution_total = total
        self._execution_text = text
        self.executionStateChanged.emit()
        self.orbVisualEvent.emit("step")
        self._set_status(f"{current}/{total}  {text}")

    @Slot(str)
    def _on_execution_finished(self, message: str) -> None:
        command = self._active_command
        self._execution_feedback_key = "done"
        self._execution_current = self._execution_total
        self._execution_text = "Готово"
        self.executionStateChanged.emit()
        self.orbVisualEvent.emit("success")
        self._set_status(message)
        self._add_history(self._transcript or (command.name if command else "Команда"), command.name if command else "Выполнено")

    @Slot(str)
    def _on_execution_failed(self, message: str) -> None:
        command = self._active_command
        self._execution_feedback_key = "failed"
        self._execution_text = message
        self.executionStateChanged.emit()
        self.orbVisualEvent.emit("error")
        self._set_status(message)
        self._add_history(self._transcript or (command.name if command else "Команда"), f"Ошибка: {message}")

    @Slot()
    def _execution_cleanup(self) -> None:
        feedback_key = self._execution_feedback_key
        self._execution_thread = None
        self._execution_worker = None
        self._speak(feedback_key, self._finish_execution_cleanup)

    def _finish_execution_cleanup(self) -> None:
        self._set_busy(False)
        self._active_command = None
        self._execution_current = 0
        self._execution_total = 0
        self._execution_text = ""
        self.executionStateChanged.emit()
        QTimer.singleShot(180, self.startWakeListening)
        QTimer.singleShot(350, self._automation_tick)

    @Slot(object)
    def _on_recognized(self, payload: object) -> None:
        if isinstance(payload, str):
            alternatives = [payload]
        elif isinstance(payload, list):
            alternatives = [str(item).strip() for item in payload if str(item).strip()]
        else:
            alternatives = [str(payload).strip()] if str(payload).strip() else []

        prepared: list[str] = []
        for alternative in alternatives:
            text = alternative
            if self._recognition_from_wake:
                text = strip_leading_wake_phrase(text, self._settings.wake_phrase)
            if text and text not in prepared:
                prepared.append(text)

        if not prepared:
            self._on_speech_error("Не удалось разобрать речь")
            return

        # Google's first alternative is not always the best command. Select the
        # alternative that most closely matches the user's saved phrases.
        selected = prepared[0]
        best_score = -1.0
        for alternative in prepared:
            match = self.matcher.find(alternative, self.store.all())
            if match is not None and match.score > best_score:
                selected = alternative
                best_score = match.score

        self._transcript = selected
        self.transcriptChanged.emit()
        self._handle_transcript(selected)

    @Slot(str)
    def _on_speech_error(self, message: str) -> None:
        # Silence, a timeout or an unrecognisable fragment is not an unknown
        # command. The not-found voice response is reserved for a real,
        # non-empty transcript that did not match a saved command.
        cleaned = str(message or "").strip() or "Не удалось распознать речь"
        self._set_status(cleaned)
        if not is_silent_speech_capture_error(cleaned):
            self._add_history("Голосовой ввод", cleaned)

    @Slot()
    def _speech_finished(self) -> None:
        self._set_audio_level(0)
        self._set_listening(False)
        self._speech_thread = None
        self._speech_worker = None
        self._recognition_from_wake = False
        if not self._busy and self._pending_command is None and not self._voice_speaking:
            QTimer.singleShot(250, self.startWakeListening)

    @Slot(object)
    def _on_recording_finished(self, steps: object) -> None:
        recorded = [step for step in steps if isinstance(step, ActionStep)] if isinstance(steps, list) else []
        if not recorded:
            self._set_status("Запись завершена без действий")
            return
        payload = json.dumps([step.to_dict() for step in recorded], ensure_ascii=False)
        self._set_status(f"Записано действий: {len(recorded)}")
        self.recordingReady.emit(payload)

    @Slot(str)
    def _on_recording_failed(self, message: str) -> None:
        self._set_status(f"Не удалось записать действия: {message}")

    @Slot()
    def _recording_cleanup(self) -> None:
        self._recording_thread = None
        self._recording_worker = None
        self._recorder = None
        self._set_recording(False)
        self._speak("recording_stopped", lambda: QTimer.singleShot(180, self.startWakeListening))

    @Slot(str)
    def _on_wake_activated(self, _recognized: str) -> None:
        # The same microphone stream now continues capturing the command.
        # No Windows notification sound is played, so it cannot leak into audio.
        self._set_listening(True)
        self.orbVisualEvent.emit("wake")
        self._set_status("Слушаю команду…")

    @Slot(object)
    def _on_wake_command_captured(self, payload: object) -> None:
        if isinstance(payload, dict):
            self._pending_captured_audio = payload
            self._set_status("Распознаю команду…")

    @Slot(str)
    def _on_wake_command_error(self, message: str) -> None:
        self._pending_captured_audio = None
        self._set_listening(False)
        self.orbVisualEvent.emit("error")
        self._set_status(message)
        self._add_history("Голосовая активация", message)

    @Slot(str)
    def _on_wake_error(self, message: str) -> None:
        logging.warning("Wake-word listener error: %s", message)
        if not self._wake_error_shown:
            self._set_status(message)
            self._wake_error_shown = True
        self._wake_enabled = False
        self._settings.wake_enabled = False
        self._save_settings()
        self.wakeStateChanged.emit()

    @Slot()
    def _wake_thread_cleanup(self) -> None:
        self._set_audio_level(0)
        self._wake_thread = None
        self._wake_worker = None
        self._set_wake_listening(False)
        if self._pending_captured_audio is not None:
            payload = self._pending_captured_audio
            self._pending_captured_audio = None
            QTimer.singleShot(0, lambda: self._start_speech_listening(payload))
        elif self._pending_listen:
            self._pending_listen = False
            self._set_listening(False)
            QTimer.singleShot(0, self._start_speech_listening)
        elif self._pending_recording:
            self._pending_recording = False
            self._set_listening(False)
            QTimer.singleShot(0, self._start_recording_now)
        elif self._pending_action_test is not None:
            pending = self._pending_action_test
            self._pending_action_test = None
            self._set_listening(False)
            QTimer.singleShot(0, lambda: self._start_action_test(*pending))
        elif self._pending_microphone_test:
            self._pending_microphone_test = False
            self._set_listening(False)
            QTimer.singleShot(0, self._start_microphone_test_now)
        else:
            self._set_listening(False)
            if self._wake_enabled and not self._busy and not self._recording and not self._voice_speaking:
                QTimer.singleShot(250, self.startWakeListening)

    def _stop_wake_listener(self) -> None:
        if self._wake_worker is not None:
            self._wake_worker.stop()

    def _speak(self, phrase_key: str, after: object | None = None) -> None:
        if not self._voice_enabled:
            if callable(after):
                QTimer.singleShot(0, after)
            return
        if self._voice_speaking:
            self._voice_queue.append((phrase_key, after))
            return
        path = resolve_voice_file(self.voice_assets_path, phrase_key)
        if path is None:
            logging.warning("Missing AURA voice asset: %s", phrase_key)
            if callable(after):
                QTimer.singleShot(0, after)
            return

        self._stop_wake_listener()
        self._voice_after = after
        self._set_voice_speaking(True)
        thread = QThread(self)
        worker = VoiceFeedbackWorker(path)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.failed.connect(lambda message: logging.warning("Voice feedback failed: %s", message))
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._voice_cleanup)
        self._voice_thread = thread
        self._voice_worker = worker
        thread.start()

    @Slot()
    def _voice_cleanup(self) -> None:
        callback = self._voice_after
        self._voice_after = None
        self._voice_thread = None
        self._voice_worker = None
        self._set_voice_speaking(False)
        if callable(callback):
            QTimer.singleShot(0, callback)
        if self._voice_queue:
            phrase_key, queued_callback = self._voice_queue.pop(0)
            QTimer.singleShot(0, lambda: self._speak(phrase_key, queued_callback))

    def _safe_load_update_config(self) -> UpdateConfig:
        try:
            return load_config(self.update_config_path)
        except UpdateError:
            logging.exception("Unable to load update config")
            return UpdateConfig.from_dict({})

    def _automatic_update_check(self) -> None:
        if self._busy or self._listening or self._recording:
            QTimer.singleShot(60_000, self._automatic_update_check)
            return
        self._start_update_check(manual=False)

    def _start_update_check(self, manual: bool) -> None:
        if self._update_busy:
            if manual:
                self._set_status("Проверка обновлений уже выполняется")
            return
        if not self._update_config.configured:
            if manual:
                self._set_status("Автообновления ещё не настроены издателем")
            return
        self._update_manual = manual
        self._set_update_busy(True)
        if manual:
            self._set_status("Проверяю обновления…")
        thread = QThread(self)
        worker = UpdateCheckWorker(
            self._update_client,
            self.current_version,
            include_prerelease=self._settings.update_channel == "beta",
        )
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.found.connect(self._on_update_found)
        worker.noUpdate.connect(self._on_no_update)
        worker.failed.connect(self._on_update_error)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._update_thread_cleanup)
        self._update_thread = thread
        self._update_worker = worker
        thread.start()

    @Slot(object)
    def _on_update_found(self, release: ReleaseInfo) -> None:
        self._update_version = release.version
        self._update_notes = release.notes
        self.updateStateChanged.emit()
        self._start_update_download_after_check(release)

    def _start_update_download_after_check(self, release: ReleaseInfo) -> None:
        QTimer.singleShot(150, lambda: self._start_update_download(release))

    def _start_update_download(self, release: ReleaseInfo) -> None:
        if self._update_thread is not None:
            QTimer.singleShot(200, lambda: self._start_update_download(release))
            return
        self._set_update_busy(True)
        self._set_status(f"Скачиваю обновление AURA {release.version}…")
        thread = QThread(self)
        worker = UpdateDownloadWorker(self._update_client, release)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.progress.connect(self._on_update_progress)
        worker.finished.connect(self._on_update_downloaded)
        worker.failed.connect(self._on_update_error)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._update_thread_cleanup)
        self._update_thread = thread
        self._update_worker = worker
        thread.start()

    @Slot(int)
    def _on_update_progress(self, percent: int) -> None:
        if percent > 0:
            self._set_status(f"Скачиваю обновление AURA {self._update_version}: {percent}%")

    @Slot(object, str)
    def _on_update_downloaded(self, release: ReleaseInfo, installer_path: str) -> None:
        self._downloaded_installer = Path(installer_path)
        self._set_status(f"Обновление AURA {release.version} готово к установке")
        self.updateReady.emit(release.version, release.notes)

    @Slot()
    def _on_no_update(self) -> None:
        if self._update_manual:
            self._set_status(f"Установлена актуальная версия AURA {self.current_version}")

    @Slot(str)
    def _on_update_error(self, message: str) -> None:
        if self._update_manual:
            self._set_status(message)
        else:
            logging.warning("Automatic update check failed: %s", message)

    @Slot()
    def _update_thread_cleanup(self) -> None:
        self._update_thread = None
        self._update_worker = None
        self._set_update_busy(False)

    def _save_settings(self) -> None:
        try:
            self._settings_store.save(self._settings)
        except OSError:
            logging.exception("Unable to save settings")

    @Slot(int)
    def _on_audio_level(self, value: int) -> None:
        if not self._settings.microphone_reactive_animation:
            return
        self._set_audio_level(value)

    def _set_audio_level(self, value: int) -> None:
        value = max(0, min(100, int(value)))
        # Smooth native microphone data so the orb feels fluid instead of jittery.
        smoothed = value if value == 0 else round(self._audio_level * 0.58 + value * 0.42)
        if abs(smoothed - self._audio_level) < 2 and smoothed not in {0, 100}:
            return
        self._audio_level = smoothed
        self.audioLevelChanged.emit()

    def _set_status(self, value: str) -> None:
        self._status = value
        self.statusChanged.emit()

    def _set_listening(self, value: bool) -> None:
        if self._listening == value:
            return
        self._listening = value
        self.listeningChanged.emit()

    def _set_busy(self, value: bool) -> None:
        if self._busy == value:
            return
        self._busy = value
        self.busyChanged.emit()

    def _set_recording(self, value: bool) -> None:
        if self._recording == value:
            return
        self._recording = value
        self.recordingChanged.emit()

    def _set_wake_listening(self, value: bool) -> None:
        if self._wake_listening == value:
            return
        self._wake_listening = value
        self.wakeStateChanged.emit()

    def _set_voice_speaking(self, value: bool) -> None:
        if self._voice_speaking == value:
            return
        self._voice_speaking = value
        self.voiceStateChanged.emit()

    def _set_update_busy(self, value: bool) -> None:
        self._update_busy = value
        self.updateStateChanged.emit()

    def _add_history(self, phrase: str, result: str) -> None:
        normalized = result.casefold()
        tone = "error" if "ошиб" in normalized or "не найден" in normalized else "warning" if "отмен" in normalized else "success"
        self._history.insert(0, {
            "phrase": phrase,
            "result": result,
            "time": datetime.now().strftime("%H:%M"),
            "tone": tone,
        })
        self._history = self._history[:20]
        self.historyChanged.emit()

    def _register_hotkeys(self) -> None:
        if not sys.platform.startswith("win") or keyboard is None or self._hotkey_registered:
            return
        try:
            self._hotkey_handle = keyboard.add_hotkey("ctrl+shift+space", self.hotkeyTriggered.emit)
            self._stop_hotkey_handle = keyboard.add_hotkey("ctrl+shift+f12", self.stopHotkeyTriggered.emit)
            self._hotkey_registered = True
            logging.info("Global hotkeys registered")
        except Exception:
            logging.exception("Unable to register global hotkeys")
            self._hotkey_registered = False
            self._hotkey_handle = None
            self._stop_hotkey_handle = None

    def _unregister_hotkeys(self) -> None:
        if keyboard is None:
            return
        for handle in (self._hotkey_handle, self._stop_hotkey_handle):
            if handle is None:
                continue
            try:
                keyboard.remove_hotkey(handle)
            except Exception:
                logging.exception("Unable to unregister global hotkey")
        self._hotkey_handle = None
        self._stop_hotkey_handle = None
        self._hotkey_registered = False
