from __future__ import annotations

import ctypes
import json
import os
import shlex
import subprocess
import sys
import threading
import time
import webbrowser
from datetime import datetime
from pathlib import Path
from typing import Any, Callable

from .models import ActionStep, VoiceCommand


class ActionError(RuntimeError):
    pass


class ExecutionCancelled(ActionError):
    pass


def _pyautogui() -> Any:
    try:
        import pyautogui
    except Exception as exc:
        raise ActionError(f"Модуль управления клавиатурой недоступен: {exc}") from exc
    pyautogui.FAILSAFE = True
    return pyautogui


def _copy_to_clipboard(value: str) -> None:
    try:
        import pyperclip
        pyperclip.copy(value)
    except Exception as exc:
        raise ActionError(f"Не удалось скопировать текст: {exc}") from exc


class ActionExecutor:
    """Executes action types exposed by the visual scenario builder."""

    APP_ALIASES = {
        "calc": {"win32": ["calc.exe"], "darwin": ["open", "-a", "Calculator"], "linux": ["gnome-calculator"]},
        "notepad": {"win32": ["notepad.exe"], "darwin": ["open", "-a", "TextEdit"], "linux": ["gedit"]},
        "explorer": {"win32": ["explorer.exe"], "darwin": ["open", str(Path.home())], "linux": ["xdg-open", str(Path.home())]},
    }

    def __init__(self) -> None:
        self._stop_event = threading.Event()

    def _stop_flag(self) -> threading.Event:
        event = getattr(self, "_stop_event", None)
        if event is None:
            event = threading.Event()
            self._stop_event = event
        return event

    def reset_stop(self) -> None:
        self._stop_flag().clear()

    def stop(self) -> None:
        self._stop_flag().set()

    def ensure_running(self) -> None:
        if self._stop_flag().is_set():
            raise ExecutionCancelled("Сценарий остановлен")

    def interruptible_sleep(self, seconds: float) -> None:
        seconds = max(0.0, min(float(seconds), 60.0))
        if self._stop_flag().wait(seconds):
            raise ExecutionCancelled("Сценарий остановлен")

    def execute(
        self,
        command: VoiceCommand,
        progress: Callable[[int, int, str], None] | None = None,
    ) -> str:
        self.reset_stop()
        enabled_steps = [step for step in command.actions if step.enabled]
        if not enabled_steps:
            raise ActionError("В команде нет включённых действий")

        for index, step in enumerate(enabled_steps, start=1):
            self.ensure_running()
            if progress:
                progress(index, len(enabled_steps), self.describe(step))
            attempts = step.retry_count + 1
            last_error: ActionError | None = None
            for attempt in range(attempts):
                try:
                    self.execute_step(step)
                    last_error = None
                    break
                except ExecutionCancelled:
                    raise
                except ActionError as exc:
                    last_error = exc
                    if attempt + 1 < attempts:
                        self.interruptible_sleep(0.6)
            if last_error:
                if step.continue_on_error:
                    if progress:
                        progress(index, len(enabled_steps), f"Пропущено: {last_error}")
                else:
                    raise last_error
            if step.delay_after > 0:
                self.interruptible_sleep(step.delay_after)
        return f"Выполнено: {command.name}"

    def execute_step(self, step: ActionStep) -> None:
        self.ensure_running()
        handlers = {
            "open_url": self._open_url,
            "open_app": self._open_app,
            "open_path": self._open_path,
            "hotkey": self._hotkey,
            "key": self._key,
            "type_text": self._type_text,
            "wait": self._wait,
            "mouse_click": self._mouse_click,
            "mouse_scroll": self._mouse_scroll,
            "activate_window": self._activate_window,
            "wait_window": self._wait_window,
            "minimize_window": self._minimize_window,
            "maximize_window": self._maximize_window,
            "close_window": self._close_window,
            "require_file": self._require_file,
            "require_window": self._require_window,
            "require_time": self._require_time,
            "shell": self._shell,
        }
        handler = handlers.get(step.action_type)
        if handler is None:
            raise ActionError(f"Неизвестное действие: {step.action_type}")
        value = self.expand_variables(step.value.strip())
        if step.action_type != "wait" and not value:
            raise ActionError("У действия не заполнено значение")
        handler(value)

    @staticmethod
    def expand_variables(value: str) -> str:
        home = Path.home()
        downloads = home / "Downloads"
        desktop = home / "Desktop"
        last_download = ""
        try:
            files = [item for item in downloads.iterdir() if item.is_file()]
            if files:
                last_download = str(max(files, key=lambda item: item.stat().st_mtime))
        except OSError:
            pass
        replacements = {
            "${home}": str(home),
            "${user}": home.name,
            "${downloads}": str(downloads),
            "${desktop}": str(desktop),
            "${last_download}": last_download,
            "${date}": datetime.now().strftime("%Y-%m-%d"),
            "${time}": datetime.now().strftime("%H:%M"),
        }
        if sys.platform.startswith("win"):
            try:
                hwnd = ctypes.windll.user32.GetForegroundWindow()
                length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
                buffer = ctypes.create_unicode_buffer(length + 1)
                ctypes.windll.user32.GetWindowTextW(hwnd, buffer, length + 1)
                replacements["${active_window}"] = buffer.value
            except Exception:
                replacements["${active_window}"] = ""
        else:
            replacements["${active_window}"] = ""
        try:
            import pyperclip
            replacements["${clipboard}"] = str(pyperclip.paste())
        except Exception:
            replacements["${clipboard}"] = ""
        result = os.path.expandvars(os.path.expanduser(value))
        for key, replacement in replacements.items():
            result = result.replace(key, replacement)
        return result

    @staticmethod
    def describe(step: ActionStep) -> str:
        labels = {
            "open_url": "Открываю сайт",
            "open_app": "Запускаю программу",
            "open_path": "Открываю файл или папку",
            "hotkey": "Нажимаю сочетание клавиш",
            "key": "Нажимаю клавишу",
            "type_text": "Вставляю текст",
            "wait": "Ожидаю",
            "mouse_click": "Нажимаю мышью",
            "mouse_scroll": "Прокручиваю страницу",
            "activate_window": "Активирую окно",
            "wait_window": "Ожидаю окно",
            "minimize_window": "Сворачиваю окно",
            "maximize_window": "Разворачиваю окно",
            "close_window": "Закрываю окно",
            "require_file": "Проверяю файл",
            "require_window": "Проверяю окно",
            "require_time": "Проверяю время",
            "shell": "Выполняю системную команду",
        }
        return labels.get(step.action_type, step.action_type)

    @staticmethod
    def _open_url(value: str) -> None:
        url = value if "://" in value else f"https://{value}"
        if not webbrowser.open(url):
            raise ActionError("Не удалось открыть ссылку")

    def _open_app(self, value: str) -> None:
        alias = self.APP_ALIASES.get(value.lower())
        platform = "win32" if sys.platform.startswith("win") else "darwin" if sys.platform == "darwin" else "linux"
        if alias:
            command = alias[platform]
        else:
            expanded = os.path.expandvars(os.path.expanduser(value.strip().strip('"')))
            path = Path(expanded)
            if path.exists() and sys.platform.startswith("win"):
                try:
                    os.startfile(str(path))  # type: ignore[attr-defined]
                    return
                except OSError as exc:
                    raise ActionError(f"Не удалось запустить программу: {exc}") from exc
            command = [str(path)] if path.exists() else shlex.split(value, posix=not sys.platform.startswith("win"))
        try:
            subprocess.Popen(command, close_fds=not sys.platform.startswith("win"))
        except (OSError, ValueError) as exc:
            raise ActionError(f"Не удалось запустить программу: {exc}") from exc

    @staticmethod
    def _open_path(value: str) -> None:
        path = Path(os.path.expandvars(os.path.expanduser(value))).resolve()
        if not path.exists():
            raise ActionError("Файл или папка не найдены")
        try:
            if sys.platform.startswith("win"):
                os.startfile(str(path))  # type: ignore[attr-defined]
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(path)])
            else:
                subprocess.Popen(["xdg-open", str(path)])
        except OSError as exc:
            raise ActionError(f"Не удалось открыть путь: {exc}") from exc

    @staticmethod
    def _hotkey(value: str) -> None:
        keys = [item.strip().lower() for item in value.replace(" ", "").split("+") if item.strip()]
        if not keys:
            raise ActionError("Укажите сочетание, например ctrl+shift+s")
        _pyautogui().hotkey(*keys)

    @staticmethod
    def _key(value: str) -> None:
        _pyautogui().press(value.strip().lower())

    @staticmethod
    def _type_text(value: str) -> None:
        _copy_to_clipboard(value)
        automation = _pyautogui()
        automation.hotkey("command" if sys.platform == "darwin" else "ctrl", "v")

    def _wait(self, value: str) -> None:
        try:
            seconds = float(value.replace(",", ".") or "1")
        except ValueError as exc:
            raise ActionError("Для ожидания укажите число секунд") from exc
        self.interruptible_sleep(seconds)

    @staticmethod
    def _parse_mouse(value: str) -> tuple[int, int, str, int]:
        try:
            if value.lstrip().startswith("{"):
                data = json.loads(value)
                return int(data["x"]), int(data["y"]), str(data.get("button", "left")), int(data.get("clicks", 1))
            parts = [item.strip() for item in value.split(",")]
            return int(parts[0]), int(parts[1]), parts[2] if len(parts) > 2 else "left", int(parts[3]) if len(parts) > 3 else 1
        except (ValueError, KeyError, IndexError, json.JSONDecodeError, TypeError) as exc:
            raise ActionError("Клик должен иметь формат x,y,button,clicks") from exc

    @classmethod
    def _mouse_click(cls, value: str) -> None:
        x, y, button, clicks = cls._parse_mouse(value)
        _pyautogui().click(x=x, y=y, button=button, clicks=max(1, min(clicks, 3)), interval=0.12)

    @staticmethod
    def _mouse_scroll(value: str) -> None:
        try:
            amount = int(float(value.replace(",", ".")))
        except ValueError as exc:
            raise ActionError("Для прокрутки укажите целое число") from exc
        _pyautogui().scroll(amount)

    @staticmethod
    def _require_windows() -> None:
        if not sys.platform.startswith("win"):
            raise ActionError("Управление окнами доступно только в Windows")

    @classmethod
    def _find_window(cls, title_part: str, timeout: float = 0.0) -> int:
        cls._require_windows()
        needle = title_part.casefold().strip()
        if not needle:
            raise ActionError("Укажите часть названия окна")
        user32 = ctypes.windll.user32
        deadline = time.monotonic() + timeout
        while True:
            found: list[int] = []
            callback_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_int, ctypes.c_int)

            def enum_callback(hwnd: int, _lparam: int) -> bool:
                if not user32.IsWindowVisible(hwnd):
                    return True
                length = user32.GetWindowTextLengthW(hwnd)
                if length <= 0:
                    return True
                buffer = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buffer, length + 1)
                if needle in buffer.value.casefold():
                    found.append(hwnd)
                    return False
                return True

            user32.EnumWindows(callback_type(enum_callback), 0)
            if found:
                return found[0]
            if time.monotonic() >= deadline:
                raise ActionError(f"Окно не найдено: {title_part}")
            time.sleep(0.2)

    @classmethod
    def _activate_window(cls, value: str) -> None:
        hwnd = cls._find_window(value)
        user32 = ctypes.windll.user32
        user32.ShowWindow(hwnd, 9)
        if not user32.SetForegroundWindow(hwnd):
            raise ActionError("Не удалось активировать окно")

    @classmethod
    def _wait_window(cls, value: str) -> None:
        title, _, timeout_text = value.partition("|")
        try:
            timeout = float(timeout_text.replace(",", ".")) if timeout_text.strip() else 10.0
        except ValueError as exc:
            raise ActionError("Формат ожидания окна: название|секунды") from exc
        cls._find_window(title, max(0.1, min(timeout, 120.0)))

    @classmethod
    def _minimize_window(cls, value: str) -> None:
        ctypes.windll.user32.ShowWindow(cls._find_window(value), 6)

    @classmethod
    def _maximize_window(cls, value: str) -> None:
        ctypes.windll.user32.ShowWindow(cls._find_window(value), 3)

    @classmethod
    def _close_window(cls, value: str) -> None:
        ctypes.windll.user32.PostMessageW(cls._find_window(value), 0x0010, 0, 0)

    @staticmethod
    def _require_file(value: str) -> None:
        path = Path(os.path.expandvars(os.path.expanduser(value))).resolve()
        if not path.exists():
            raise ActionError(f"Условие не выполнено: путь не найден: {path}")

    @classmethod
    def _require_window(cls, value: str) -> None:
        cls._find_window(value, timeout=0.0)

    @staticmethod
    def _require_time(value: str) -> None:
        text = value.strip().replace(" ", "")
        start_text, separator, end_text = text.partition("-")
        if not separator:
            raise ActionError("Формат условия времени: 09:00-18:00")
        try:
            start_hour, start_minute = [int(part) for part in start_text.split(":", 1)]
            end_hour, end_minute = [int(part) for part in end_text.split(":", 1)]
            start = start_hour * 60 + start_minute
            end = end_hour * 60 + end_minute
        except (ValueError, TypeError) as exc:
            raise ActionError("Формат условия времени: 09:00-18:00") from exc
        if not (0 <= start < 1440 and 0 <= end < 1440):
            raise ActionError("Укажите корректное время")
        now = datetime.now().hour * 60 + datetime.now().minute
        allowed = start <= now <= end if start <= end else now >= start or now <= end
        if not allowed:
            raise ActionError("Условие не выполнено: текущее время вне заданного диапазона")

    @staticmethod
    def _shell(value: str) -> None:
        try:
            subprocess.Popen(value, shell=True)
        except OSError as exc:
            raise ActionError(f"Не удалось выполнить команду: {exc}") from exc
