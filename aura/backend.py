from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Property, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QGuiApplication

from .actions import ActionError, ActionExecutor
from .engine import CommandMatcher
from .models import ActionStep, VoiceCommand
from .speech import SpeechWorker
from .storage import CommandStore
from .update_client import (
    GitHubUpdateClient,
    ReleaseInfo,
    UpdateConfig,
    UpdateError,
    clear_old_updates,
    load_config,
    update_cache_dir,
)

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
    {"type": "shell", "label": "Системная команда", "hint": "Команда CMD. Используйте осторожно"},
]
ACTION_LABELS = {item["type"]: item["label"] for item in ACTION_CATALOG}


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


class UpdateCheckWorker(QObject):
    found = Signal(object)
    noUpdate = Signal()
    failed = Signal(str)
    done = Signal()

    def __init__(self, client: GitHubUpdateClient, current_version: str) -> None:
        super().__init__()
        self.client = client
        self.current_version = current_version

    @Slot()
    def run(self) -> None:
        try:
            release = self.client.check(self.current_version)
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
    historyChanged = Signal()
    updateStateChanged = Signal()
    confirmationRequested = Signal(str, str)
    updateReady = Signal(str, str)
    hotkeyTriggered = Signal()
    stopHotkeyTriggered = Signal()

    def __init__(
        self,
        current_version: str,
        update_config_path: Path,
        updater_path: Path,
        application_path: Path,
    ) -> None:
        super().__init__()
        self.store = CommandStore()
        self.matcher = CommandMatcher()
        self.executor = ActionExecutor()
        self.current_version = current_version
        self.update_config_path = update_config_path
        self.updater_path = updater_path
        self.application_path = application_path
        self._status = "Готов к работе"
        self._transcript = ""
        self._listening = False
        self._busy = False
        self._history: list[dict[str, str]] = []
        self._pending_command: VoiceCommand | None = None
        self._active_command: VoiceCommand | None = None
        self._speech_thread: QThread | None = None
        self._speech_worker: SpeechWorker | None = None
        self._execution_thread: QThread | None = None
        self._execution_worker: ExecutionWorker | None = None
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
        QTimer.singleShot(5000, self._automatic_update_check)

        self._update_timer = QTimer(self)
        self._update_timer.setInterval(self._update_config.check_interval_hours * 60 * 60 * 1000)
        self._update_timer.timeout.connect(self._automatic_update_check)
        if self._update_config.configured:
            self._update_timer.start()

    @Property("QVariantList", notify=commandsChanged)
    def commands(self) -> list[dict[str, object]]:
        result: list[dict[str, object]] = []
        for command in self.store.all():
            actions = [step.to_dict() for step in command.actions]
            preview = "  •  ".join(ACTION_LABELS.get(step.action_type, step.action_type) for step in command.actions[:2])
            if len(command.actions) > 2:
                preview += f"  +{len(command.actions) - 2}"
            first_step = command.actions[0] if command.actions else ActionStep("open_url", "")
            result.append({
                **command.to_dict(),
                "actions": actions,
                "phrases_text": ", ".join(command.phrases),
                "steps_count": len(command.actions),
                "preview": preview,
                "action_type": first_step.action_type,
                "action_value": first_step.value,
                "action_label": ACTION_LABELS.get(first_step.action_type, first_step.action_type),
            })
        return result

    @Property("QVariantList", constant=True)
    def actionCatalog(self) -> list[dict[str, str]]:
        return ACTION_CATALOG

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

    @Property("QVariantList", notify=historyChanged)
    def history(self) -> list[dict[str, str]]:
        return self._history[:10]

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

    @Slot(str, result=str)
    def actionLabel(self, action_type: str) -> str:
        return ACTION_LABELS.get(action_type, action_type)

    @Slot()
    def toggleListening(self) -> None:
        if self._listening or self._busy:
            return
        self._set_listening(True)
        self._set_status("Слушаю…")
        self._transcript = ""
        self.transcriptChanged.emit()

        thread = QThread(self)
        worker = SpeechWorker()
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

    @Slot(str)
    def executeText(self, text: str) -> None:
        clean = text.strip()
        if not clean:
            self._set_status("Введите тестовую фразу")
            return
        if self._busy:
            self._set_status("Сначала дождитесь завершения текущей команды")
            return
        self._transcript = clean
        self.transcriptChanged.emit()
        self._handle_transcript(clean)

    @Slot(str, str, str, str, bool, result=bool)
    def saveCommand(self, command_id: str, name: str, phrases_text: str, actions_json: str, require_confirmation: bool) -> bool:
        phrases = [item.strip()[:160] for item in phrases_text.replace("\n", ",").split(",") if item.strip()][:20]
        try:
            raw_actions = json.loads(actions_json)
            if not isinstance(raw_actions, list):
                raise TypeError("actions must be a list")
            actions = [ActionStep.from_dict(item) for item in raw_actions[:200] if isinstance(item, dict)]
        except (json.JSONDecodeError, TypeError):
            actions = []
        if not name.strip() or not phrases or not actions:
            self._set_status("Заполните название, фразы и добавьте хотя бы одно действие")
            return False
        allowed_types = set(ACTION_LABELS)
        for step in actions:
            if step.action_type not in allowed_types:
                self._set_status("В команде есть неизвестное действие")
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
        )
        existing = next((item for item in self.store.all() if item.id == command.id), None)
        if existing:
            command.enabled = existing.enabled
        self.store.save(command)
        self.commandsChanged.emit()
        self._set_status(f"Команда «{command.name}» сохранена")
        return True

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

    @Slot()
    def stopExecution(self) -> None:
        if not self._busy:
            return
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
            # Run the helper from the update cache. Windows locks running EXE files,
            # so the installer must be free to replace the copy inside the app folder.
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

    def _handle_transcript(self, text: str) -> None:
        match = self.matcher.find(text, self.store.all())
        if not match:
            self._set_status("Команда не найдена")
            self._add_history(text, "Не найдено")
            return
        command = match.command
        if command.require_confirmation:
            self._pending_command = command
            self._set_status("Нужно подтверждение")
            details = "\n".join(f"{i}. {ACTION_LABELS.get(s.action_type, s.action_type)}: {s.value}" for i, s in enumerate(command.actions, 1))
            self.confirmationRequested.emit(command.name, details)
            return
        self._execute(command)

    def _execute(self, command: VoiceCommand) -> None:
        if self._busy:
            return
        self._active_command = command
        self._set_busy(True)
        self._set_status(f"Запускаю «{command.name}»")
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
        self._set_status(f"{current}/{total}  {text}")

    @Slot(str)
    def _on_execution_finished(self, message: str) -> None:
        command = self._active_command
        self._set_status(message)
        self._add_history(self._transcript or (command.name if command else "Команда"), command.name if command else "Выполнено")

    @Slot(str)
    def _on_execution_failed(self, message: str) -> None:
        command = self._active_command
        self._set_status(message)
        self._add_history(self._transcript or (command.name if command else "Команда"), f"Ошибка: {message}")

    @Slot()
    def _execution_cleanup(self) -> None:
        self._execution_thread = None
        self._execution_worker = None
        self._active_command = None
        self._set_busy(False)

    @Slot(str)
    def _on_recognized(self, text: str) -> None:
        self._transcript = text
        self.transcriptChanged.emit()
        self._handle_transcript(text)

    @Slot(str)
    def _on_speech_error(self, message: str) -> None:
        self._set_status(message)
        self._add_history("Голосовой ввод", message)

    @Slot()
    def _speech_finished(self) -> None:
        self._set_listening(False)
        self._speech_thread = None
        self._speech_worker = None

    def _safe_load_update_config(self) -> UpdateConfig:
        try:
            return load_config(self.update_config_path)
        except UpdateError:
            logging.exception("Unable to load update config")
            return UpdateConfig.from_dict({})

    def _automatic_update_check(self) -> None:
        if self._busy or self._listening:
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
        worker = UpdateCheckWorker(self._update_client, self.current_version)
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
        # The check thread owns the current worker. Start download after it finishes.
        def begin() -> None:
            self._start_update_download(release)

        QTimer.singleShot(150, begin)

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

    def _set_status(self, value: str) -> None:
        self._status = value
        self.statusChanged.emit()

    def _set_listening(self, value: bool) -> None:
        self._listening = value
        self.listeningChanged.emit()

    def _set_busy(self, value: bool) -> None:
        self._busy = value
        self.busyChanged.emit()

    def _set_update_busy(self, value: bool) -> None:
        self._update_busy = value
        self.updateStateChanged.emit()

    def _add_history(self, phrase: str, result: str) -> None:
        self._history.insert(0, {"phrase": phrase, "result": result})
        self._history = self._history[:10]
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
