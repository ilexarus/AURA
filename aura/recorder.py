from __future__ import annotations

import ctypes
import json
import sys
import threading
import time
from typing import Any

from .models import ActionStep


MODIFIER_NAMES = {
    "Key.ctrl": "ctrl",
    "Key.ctrl_l": "ctrl",
    "Key.ctrl_r": "ctrl",
    "Key.shift": "shift",
    "Key.shift_l": "shift",
    "Key.shift_r": "shift",
    "Key.alt": "alt",
    "Key.alt_l": "alt",
    "Key.alt_r": "alt",
    "Key.cmd": "win",
    "Key.cmd_l": "win",
    "Key.cmd_r": "win",
}
SPECIAL_KEYS = {
    "Key.enter": "enter",
    "Key.tab": "tab",
    "Key.backspace": "backspace",
    "Key.delete": "delete",
    "Key.esc": "esc",
    "Key.space": "space",
    "Key.left": "left",
    "Key.right": "right",
    "Key.up": "up",
    "Key.down": "down",
    "Key.home": "home",
    "Key.end": "end",
    "Key.page_up": "pageup",
    "Key.page_down": "pagedown",
    "Key.insert": "insert",
    "Key.media_volume_up": "volumeup",
    "Key.media_volume_down": "volumedown",
    "Key.media_volume_mute": "volumemute",
    "Key.media_play_pause": "playpause",
}


class ActionRecorder:
    """Records user input and turns it into editable AURA action steps."""

    def __init__(self) -> None:
        self._stop = threading.Event()
        self._steps: list[tuple[float, ActionStep]] = []
        self._text_buffer = ""
        self._text_started = 0.0
        self._modifiers: set[str] = set()
        self._handled_keys: set[str] = set()
        self._lock = threading.RLock()
        self._active_window_title = ""

    def stop(self) -> None:
        self._stop.set()

    def run(self) -> list[ActionStep]:
        try:
            from pynput import keyboard, mouse
        except Exception as exc:
            raise RuntimeError(f"Не удалось загрузить модуль записи: {exc}") from exc

        keyboard_listener = keyboard.Listener(on_press=self._on_press, on_release=self._on_release)
        mouse_listener = mouse.Listener(on_click=self._on_click, on_scroll=self._on_scroll)
        keyboard_listener.start()
        mouse_listener.start()
        try:
            while not self._stop.wait(0.1):
                pass
        finally:
            keyboard_listener.stop()
            mouse_listener.stop()
            keyboard_listener.join(timeout=1.0)
            mouse_listener.join(timeout=1.0)
            with self._lock:
                self._flush_text(time.monotonic())
        return self._finalize()

    def _append(self, timestamp: float, step: ActionStep) -> None:
        self._steps.append((timestamp, step))

    def _flush_text(self, timestamp: float) -> None:
        if not self._text_buffer:
            return
        self._append(self._text_started or timestamp, ActionStep("type_text", self._text_buffer))
        self._text_buffer = ""
        self._text_started = 0.0

    @staticmethod
    def _key_string(key: Any) -> str:
        return str(key)

    @staticmethod
    def _key_char(key: Any) -> str | None:
        char = getattr(key, "char", None)
        return char if isinstance(char, str) and char else None

    @staticmethod
    def _foreground_window_title() -> str:
        if not sys.platform.startswith("win"):
            return ""
        try:
            user32 = ctypes.windll.user32
            hwnd = user32.GetForegroundWindow()
            if not hwnd:
                return ""
            length = user32.GetWindowTextLengthW(hwnd)
            if length <= 0:
                return ""
            buffer = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buffer, length + 1)
            return buffer.value.strip()
        except Exception:
            return ""

    def _maybe_append_active_window(self, timestamp: float) -> None:
        title = self._foreground_window_title()
        if not title or title == self._active_window_title:
            return
        self._active_window_title = title
        if title.casefold().startswith("aura"):
            return
        # Window titles can contain a changing document suffix. Keep a practical,
        # editable fragment while avoiding very long values.
        value = title[:120]
        self._append(timestamp, ActionStep("activate_window", value))

    def _on_press(self, key: Any) -> bool | None:
        now = time.monotonic()
        key_string = self._key_string(key)
        with self._lock:
            modifier = MODIFIER_NAMES.get(key_string)
            if modifier:
                self._modifiers.add(modifier)
                return None

            special = SPECIAL_KEYS.get(key_string)
            char = self._key_char(key)
            if {"ctrl", "shift"}.issubset(self._modifiers) and (special == "f12" or key_string.endswith("f12")):
                self._stop.set()
                return False

            token = special or (char.lower() if char else key_string.replace("Key.", "").strip("'"))
            if self._modifiers.intersection({"ctrl", "alt", "win"}):
                self._flush_text(now)
                self._maybe_append_active_window(now)
                order = ["ctrl", "alt", "shift", "win"]
                combo = "+".join(sorted(self._modifiers, key=order.index) + [token])
                if combo not in self._handled_keys:
                    self._append(now, ActionStep("hotkey", combo))
                    self._handled_keys.add(combo)
                return None

            if char:
                if not self._text_buffer:
                    self._maybe_append_active_window(now)
                    self._text_started = now
                self._text_buffer += char
                return None
            if special == "space":
                if not self._text_buffer:
                    self._maybe_append_active_window(now)
                    self._text_started = now
                self._text_buffer += " "
                return None
            if special:
                self._flush_text(now)
                self._maybe_append_active_window(now)
                self._append(now, ActionStep("key", special))
        return None

    def _on_release(self, key: Any) -> None:
        key_string = self._key_string(key)
        with self._lock:
            modifier = MODIFIER_NAMES.get(key_string)
            if modifier:
                self._modifiers.discard(modifier)
            if not self._modifiers:
                self._handled_keys.clear()

    def _on_click(self, x: int, y: int, button: Any, pressed: bool) -> None:
        if not pressed:
            return
        now = time.monotonic()
        with self._lock:
            self._flush_text(now)
            self._maybe_append_active_window(now)
            button_name = str(button).split(".")[-1]
            payload = {"x": int(x), "y": int(y), "button": button_name, "clicks": 1}

            if self._steps and self._steps[-1][1].action_type == "mouse_click":
                previous_time, previous_step = self._steps[-1]
                try:
                    previous = json.loads(previous_step.value)
                except (TypeError, json.JSONDecodeError):
                    previous = {}
                same_point = abs(int(previous.get("x", -9999)) - int(x)) <= 3 and abs(int(previous.get("y", -9999)) - int(y)) <= 3
                if same_point and previous.get("button") == button_name and now - previous_time <= 0.45:
                    previous["clicks"] = min(int(previous.get("clicks", 1)) + 1, 3)
                    previous_step.value = json.dumps(previous, ensure_ascii=False)
                    self._steps[-1] = (now, previous_step)
                    return

            self._append(now, ActionStep("mouse_click", json.dumps(payload, ensure_ascii=False)))

    def _on_scroll(self, _x: int, _y: int, _dx: int, dy: int) -> None:
        now = time.monotonic()
        with self._lock:
            self._flush_text(now)
            self._maybe_append_active_window(now)
            self._append(now, ActionStep("mouse_scroll", str(int(dy))))

    def _finalize(self) -> list[ActionStep]:
        if not self._steps:
            return []
        steps = [item[1] for item in self._steps]
        for index in range(len(self._steps) - 1):
            delay = self._steps[index + 1][0] - self._steps[index][0]
            steps[index].delay_after = 0.0 if delay < 0.12 else round(min(delay, 30.0), 2)
        return steps[:200]
