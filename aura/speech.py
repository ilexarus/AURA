from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot

try:
    import speech_recognition as sr
except ImportError:
    sr = None


class SpeechWorker(QObject):
    recognized = Signal(str)
    failed = Signal(str)
    finished = Signal()

    def __init__(self, microphone_index: int | None = None) -> None:
        super().__init__()
        self.microphone_index = microphone_index

    @Slot()
    def listen_once(self) -> None:
        if sr is None:
            self.failed.emit("Модуль распознавания речи не установлен")
            self.finished.emit()
            return
        recognizer = sr.Recognizer()
        recognizer.dynamic_energy_threshold = True
        recognizer.pause_threshold = 0.65
        try:
            with sr.Microphone(device_index=self.microphone_index) as source:
                recognizer.adjust_for_ambient_noise(source, duration=0.4)
                audio = recognizer.listen(source, timeout=5, phrase_time_limit=9)
            self.recognized.emit(recognizer.recognize_google(audio, language="ru-RU"))
        except sr.WaitTimeoutError:
            self.failed.emit("Не услышал команду")
        except sr.UnknownValueError:
            self.failed.emit("Не удалось разобрать речь")
        except sr.RequestError:
            self.failed.emit("Сервис распознавания речи недоступен")
        except (OSError, AttributeError) as exc:
            self.failed.emit(f"Микрофон недоступен: {exc}")
        finally:
            self.finished.emit()
