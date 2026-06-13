from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "generate_silero_voice.py"
SPEC = importlib.util.spec_from_file_location("aura_silero_builder", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class SileroVoiceBuilderTests(unittest.TestCase):
    def test_phrase_keys_match_runtime_assets(self) -> None:
        from aura.voice_assets import VOICE_FILES

        self.assertEqual(set(MODULE.PHRASES), set(VOICE_FILES))
        self.assertEqual(MODULE.VOICE_FILES, VOICE_FILES)

    def test_quality_profile_is_marked_noncommercial(self) -> None:
        profile = MODULE.PROFILES["quality"]
        self.assertEqual(profile.model_id, "v5_5_ru")
        self.assertFalse(profile.commercial_use)

    def test_mit_profile_is_marked_for_commercial_use(self) -> None:
        profile = MODULE.PROFILES["mit"]
        self.assertEqual(profile.model_id, "v5_cis_base_nostress")
        self.assertTrue(profile.commercial_use)
        self.assertEqual(profile.license_name, "MIT")

    def test_model_without_eval_is_supported(self) -> None:
        class TorchStub:
            @staticmethod
            def device(name: str) -> str:
                return name

        class ModelStub:
            def __init__(self) -> None:
                self.device = None

            def to(self, device: str) -> None:
                self.device = device

            def apply_tts(self, **_kwargs):
                return [0.0]

        model = ModelStub()
        result = MODULE.prepare_model_for_inference(model, TorchStub)
        self.assertIs(result, model)
        self.assertEqual(model.device, "cpu")

    def test_model_eval_is_called_when_available(self) -> None:
        class TorchStub:
            @staticmethod
            def device(name: str) -> str:
                return name

        class ModelStub:
            def __init__(self) -> None:
                self.eval_called = False

            def to(self, _device: str) -> None:
                pass

            def eval(self) -> None:
                self.eval_called = True

            def apply_tts(self, **_kwargs):
                return [0.0]

        model = ModelStub()
        MODULE.prepare_model_for_inference(model, TorchStub)
        self.assertTrue(model.eval_called)

    def test_invalid_model_is_rejected(self) -> None:
        class TorchStub:
            @staticmethod
            def device(name: str) -> str:
                return name

        with self.assertRaisesRegex(RuntimeError, "apply_tts"):
            MODULE.prepare_model_for_inference(object(), TorchStub)


if __name__ == "__main__":
    unittest.main()
