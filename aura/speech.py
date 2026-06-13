from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot

from .voice_utils import extract_google_alternatives

try:
    import speech_recognition as sr
except ImportError:
    sr = None


class SpeechWorker(QObject):
    recognized = Signal(object)
    failed = Signal(str)
    finished = Signal()

    def __init__(
        self,
        microphone_index: int | None = None,
        audio_payload: dict[str, object] | None = None,
    ) -> None:
        super().__init__()
        self.microphone_index = microphone_index
        self.audio_payload = audio_payload

    @Slot()
    def listen_once(self) -> None:
        if sr is None:
            self.failed.emit("Модуль распознавания речи не установлен")
            self.finished.emit()
            return

        recognizer = sr.Recognizer()
        recognizer.dynamic_energy_threshold = True
        recognizer.energy_threshold = 250
        recognizer.dynamic_energy_adjustment_damping = 0.12
        recognizer.dynamic_energy_ratio = 1.45
        recognizer.pause_threshold = 0.38
        recognizer.phrase_threshold = 0.12
        recognizer.non_speaking_duration = 0.22
        recognizer.operation_timeout = 7

        try:
            if self.audio_payload is not None:
                pcm = self.audio_payload.get("pcm")
                sample_rate = int(self.audio_payload.get("sample_rate") or 16_000)
                sample_width = int(self.audio_payload.get("sample_width") or 2)
                if not isinstance(pcm, (bytes, bytearray)) or not pcm:
                    raise ValueError("Пустая запись команды")
                audio = sr.AudioData(bytes(pcm), sample_rate, sample_width)
            else:
                with sr.Microphone(device_index=self.microphone_index) as source:
                    # A very short calibration keeps button/hotkey mode responsive.
                    recognizer.adjust_for_ambient_noise(source, duration=0.12)
                    audio = recognizer.listen(source, timeout=4, phrase_time_limit=10)

            response = recognizer.recognize_google(audio, language="ru-RU", show_all=True)
            alternatives = extract_google_alternatives(response)
            if not alternatives:
                raise sr.UnknownValueError()
            self.recognized.emit(alternatives)
        except sr.WaitTimeoutError:
            self.failed.emit("Не услышал команду")
        except sr.UnknownValueError:
            self.failed.emit("Не удалось разобрать речь")
        except sr.RequestError:
            self.failed.emit("Сервис распознавания речи недоступен")
        except (OSError, AttributeError, ValueError) as exc:
            self.failed.emit(f"Микрофон недоступен: {exc}")
        finally:
            self.finished.emit()
