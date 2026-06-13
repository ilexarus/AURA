from __future__ import annotations

import unittest

from aura.voice_utils import (
    contains_wake_phrase,
    extract_google_alternatives,
    pcm_rms,
    strip_leading_wake_phrase,
    is_silent_speech_capture_error,
)


class VoicePipelineTests(unittest.TestCase):
    def test_wake_phrase_detection_is_word_based(self) -> None:
        self.assertTrue(contains_wake_phrase("эй аура", "аура"))
        self.assertFalse(contains_wake_phrase("ауралия", "аура"))

    def test_strip_leading_wake_phrase(self) -> None:
        self.assertEqual(strip_leading_wake_phrase("Аура, открой браузер", "аура"), "открой браузер")
        self.assertEqual(strip_leading_wake_phrase("Привет Аура включи музыку", "аура"), "включи музыку")
        self.assertEqual(strip_leading_wake_phrase("открой браузер", "аура"), "открой браузер")

    def test_pcm_rms(self) -> None:
        self.assertEqual(pcm_rms(b"\x00\x00" * 16), 0.0)
        self.assertGreater(pcm_rms((1000).to_bytes(2, "little", signed=True) * 16), 900.0)

    def test_silence_is_not_treated_as_unknown_command(self) -> None:
        self.assertTrue(is_silent_speech_capture_error("Не услышал команду"))
        self.assertTrue(is_silent_speech_capture_error("Не удалось разобрать речь"))
        self.assertFalse(is_silent_speech_capture_error("Сервис распознавания речи недоступен"))

    def test_google_alternative_parsing(self) -> None:
        payload = {
            "alternative": [
                {"transcript": "открой браузер", "confidence": 0.8},
                {"transcript": "открой браузир"},
                {"transcript": "открой браузер"},
            ]
        }
        self.assertEqual(
            extract_google_alternatives(payload),
            ["открой браузер", "открой браузир"],
        )


if __name__ == "__main__":
    unittest.main()
