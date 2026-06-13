from __future__ import annotations

import json
import tempfile
import unittest
import wave
from pathlib import Path

from aura.settings import AssistantSettings
from aura.voice_assets import VOICE_FILES, resolve_voice_file, voice_pack_is_ready


class VoiceFeedbackTests(unittest.TestCase):
    def test_voice_feedback_enabled_by_default(self) -> None:
        settings = AssistantSettings.from_dict({})
        self.assertTrue(settings.voice_feedback_enabled)

    def test_voice_feedback_setting_can_be_disabled(self) -> None:
        settings = AssistantSettings.from_dict({"voice_feedback_enabled": False})
        self.assertFalse(settings.voice_feedback_enabled)

    def test_unknown_voice_key_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            self.assertIsNone(resolve_voice_file(Path(folder), "unknown"))

    def test_pack_requires_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for filename in VOICE_FILES.values():
                (root / filename).write_bytes(b"not-a-wave")
            self.assertFalse(voice_pack_is_ready(root))

    def test_manifest_enables_complete_pack(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = {}
            for key, filename in VOICE_FILES.items():
                (root / filename).write_bytes(b"wave")
                files[key] = {"file": filename}
            (root / "voice_pack.json").write_text(json.dumps({"files": files}), encoding="utf-8")
            self.assertTrue(voice_pack_is_ready(root))
            self.assertEqual(resolve_voice_file(root, "done"), root / "done.wav")

    def test_packaged_voice_files_are_pcm_wav_when_present(self) -> None:
        voice_dir = Path(__file__).resolve().parents[1] / "assets" / "voice"
        for key, filename in VOICE_FILES.items():
            path = voice_dir / filename
            if not path.is_file():
                continue
            with wave.open(str(path), "rb") as audio:
                self.assertEqual(audio.getnchannels(), 1, key)
                self.assertEqual(audio.getsampwidth(), 2, key)
                self.assertIn(audio.getframerate(), {22050, 24000, 44100, 48000}, key)
                self.assertGreater(audio.getnframes(), 1000, key)


if __name__ == "__main__":
    unittest.main()
