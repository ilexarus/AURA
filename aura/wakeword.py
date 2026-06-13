from __future__ import annotations

import json
import logging
import queue
import threading
import time
from collections import deque
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot

from .voice_utils import contains_wake_phrase, normalize_phrase, pcm_rms

try:
    import sounddevice as sd
except Exception:  # pragma: no cover - depends on host audio stack
    sd = None

try:
    from vosk import KaldiRecognizer, Model, SetLogLevel
except Exception:  # pragma: no cover - optional native dependency
    KaldiRecognizer = None
    Model = None
    SetLogLevel = None


_MODEL_CACHE: dict[str, object] = {}
_MODEL_LOCK = threading.Lock()


def _get_cached_model(model_path: Path) -> object:
    key = str(model_path.resolve())
    with _MODEL_LOCK:
        cached = _MODEL_CACHE.get(key)
        if cached is None:
            if Model is None:
                raise RuntimeError("Vosk is unavailable")
            cached = Model(key)
            _MODEL_CACHE[key] = cached
        return cached


class WakeWordWorker(QObject):
    """Listen for the local wake phrase and capture the command in one audio stream."""

    activated = Signal(str)
    commandCaptured = Signal(object)
    commandFailed = Signal(str)
    levelChanged = Signal(int)
    failed = Signal(str)
    finished = Signal()

    def __init__(
        self,
        model_path: Path,
        wake_phrase: str = "аура",
        microphone_index: int | None = None,
        sample_rate: int = 16_000,
    ) -> None:
        super().__init__()
        self.model_path = Path(model_path)
        self.wake_phrase = normalize_phrase(wake_phrase) or "аура"
        self.microphone_index = microphone_index
        self.sample_rate = sample_rate
        self.blocksize = 1280  # 80 ms at 16 kHz, responsive without overloading Vosk.
        self._stop_event = threading.Event()
        self._last_level = -1

    def _emit_level(self, rms: float) -> None:
        # Speech RMS on common Windows microphones is usually within 0..3500.
        # The exponent keeps quiet speech visible without making loud sounds jump.
        normalized = 0 if rms <= 70 else int(min(100.0, ((rms - 70.0) / 2800.0) ** 0.62 * 100.0))
        if abs(normalized - self._last_level) >= 2:
            self._last_level = normalized
            self.levelChanged.emit(normalized)

    def stop(self) -> None:
        self._stop_event.set()

    @Slot()
    def run(self) -> None:
        if sd is None or Model is None or KaldiRecognizer is None:
            self.failed.emit("Локальная голосовая активация не установлена")
            self.finished.emit()
            return
        if not self.model_path.is_dir():
            self.failed.emit("Локальная модель фразы «Аура» не найдена")
            self.finished.emit()
            return

        audio_queue: queue.Queue[bytes] = queue.Queue(maxsize=32)

        def callback(indata: bytes, _frames: int, _time: object, status: object) -> None:
            if status:
                logging.debug("Wake audio status: %s", status)
            if self._stop_event.is_set():
                return
            payload = bytes(indata)
            try:
                audio_queue.put_nowait(payload)
            except queue.Full:
                try:
                    audio_queue.get_nowait()
                except queue.Empty:
                    pass
                try:
                    audio_queue.put_nowait(payload)
                except queue.Full:
                    pass

        detected_text = ""
        command_payload: dict[str, object] | None = None
        command_error = ""
        pre_roll: deque[bytes] = deque(maxlen=3)
        noise_samples: deque[float] = deque(maxlen=35)

        try:
            if SetLogLevel is not None:
                SetLogLevel(-1)
            model = _get_cached_model(self.model_path)
            grammar = json.dumps(
                [self.wake_phrase, f"эй {self.wake_phrase}", f"привет {self.wake_phrase}", "[unk]"],
                ensure_ascii=False,
            )
            recognizer = KaldiRecognizer(model, self.sample_rate, grammar)

            with sd.RawInputStream(
                samplerate=self.sample_rate,
                blocksize=self.blocksize,
                device=self.microphone_index,
                dtype="int16",
                channels=1,
                latency="low",
                callback=callback,
            ):
                while not self._stop_event.is_set() and not detected_text:
                    try:
                        data = audio_queue.get(timeout=0.15)
                    except queue.Empty:
                        continue

                    pre_roll.append(data)
                    level = pcm_rms(data)
                    self._emit_level(level)
                    if level > 0:
                        noise_samples.append(level)

                    if recognizer.AcceptWaveform(data):
                        result = json.loads(recognizer.Result() or "{}")
                        text = str(result.get("text") or "")
                    else:
                        result = json.loads(recognizer.PartialResult() or "{}")
                        text = str(result.get("partial") or "")

                    if contains_wake_phrase(text, self.wake_phrase):
                        detected_text = text
                        self.activated.emit(text)
                        command_payload, command_error = self._capture_command(
                            audio_queue=audio_queue,
                            initial_chunks=list(pre_roll),
                            noise_samples=list(noise_samples),
                        )
                        break
        except Exception as exc:  # native audio errors vary by Windows driver
            logging.exception("Wake-word listener failed")
            if not self._stop_event.is_set():
                self.failed.emit(f"Голосовая активация недоступна: {exc}")
        finally:
            self.levelChanged.emit(0)
            if not self._stop_event.is_set():
                if command_payload is not None:
                    self.commandCaptured.emit(command_payload)
                elif detected_text and command_error:
                    self.commandFailed.emit(command_error)
            self.finished.emit()

    def _capture_command(
        self,
        audio_queue: queue.Queue[bytes],
        initial_chunks: list[bytes],
        noise_samples: list[float],
    ) -> tuple[dict[str, object] | None, str]:
        """Capture speech immediately after activation without reopening the microphone."""
        started_at = time.monotonic()
        command_started_at: float | None = None
        silence_started_at: float | None = None
        chunks = list(initial_chunks)

        useful_noise = sorted(value for value in noise_samples if value > 0)
        if useful_noise:
            # Use a low percentile so the wake word itself does not get mistaken
            # for the room's baseline when AURA has only just started listening.
            noise_floor = useful_noise[int((len(useful_noise) - 1) * 0.20)]
        else:
            noise_floor = 120.0
        speech_threshold = min(3500.0, max(190.0, noise_floor * 1.65 + 70.0))

        while not self._stop_event.is_set():
            now = time.monotonic()
            elapsed = now - started_at
            if elapsed >= 10.0:
                break

            try:
                data = audio_queue.get(timeout=0.12)
            except queue.Empty:
                continue

            chunks.append(data)
            level = pcm_rms(data)
            self._emit_level(level)

            # Ignore the tail of the wake word itself, then react to the command.
            if elapsed < 0.28:
                continue

            is_voice = level >= speech_threshold
            if command_started_at is None:
                if is_voice:
                    command_started_at = now
                    silence_started_at = None
                elif elapsed >= 2.8:
                    return None, "Не услышал команду после слова «Аура»"
                else:
                    # Slowly follow the real room noise while waiting for speech.
                    noise_floor = noise_floor * 0.94 + level * 0.06
                    speech_threshold = min(3500.0, max(190.0, noise_floor * 1.65 + 70.0))
                continue

            if is_voice:
                silence_started_at = None
            elif silence_started_at is None:
                silence_started_at = now
            elif now - silence_started_at >= 0.38 and now - command_started_at >= 0.25:
                break

        if self._stop_event.is_set():
            return None, ""
        if command_started_at is None:
            return None, "Не услышал команду после слова «Аура»"

        return {
            "pcm": b"".join(chunks),
            "sample_rate": self.sample_rate,
            "sample_width": 2,
            "wake_phrase": self.wake_phrase,
        }, ""
