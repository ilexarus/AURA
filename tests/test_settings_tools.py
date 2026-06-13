from __future__ import annotations

import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from aura.settings import AssistantSettings, SettingsStore
from aura.system_tools import create_backup, list_microphones, prune_backups


class SettingsAndToolsTests(unittest.TestCase):
    def test_new_install_starts_first_run_wizard(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            settings = SettingsStore(Path(folder)).load()
            self.assertFalse(settings.first_run_completed)

    def test_existing_settings_skip_first_run_wizard_after_upgrade(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "settings.json"
            path.write_text(json.dumps({"wake_enabled": True}), encoding="utf-8")
            settings = SettingsStore(Path(folder)).load()
            self.assertTrue(settings.first_run_completed)

    def test_invalid_update_channel_falls_back_to_stable(self) -> None:
        settings = AssistantSettings.from_dict({"update_channel": "nightly"})
        self.assertEqual(settings.update_channel, "stable")

    def test_backup_contains_commands_and_settings(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            data_dir = Path(folder)
            (data_dir / "commands.json").write_text("[]", encoding="utf-8")
            (data_dir / "settings.json").write_text("{}", encoding="utf-8")
            backup = create_backup(data_dir)
            with zipfile.ZipFile(backup) as archive:
                self.assertIn("commands.json", archive.namelist())
                self.assertIn("settings.json", archive.namelist())
                self.assertIn("backup-info.json", archive.namelist())

    def test_backup_pruning_keeps_requested_count(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            data_dir = Path(folder)
            backup_dir = data_dir / "backups"
            backup_dir.mkdir()
            for index in range(5):
                path = backup_dir / f"AURA-backup-20260101-00000{index}.zip"
                path.write_bytes(b"x")
                path.touch()
            prune_backups(data_dir, keep=3)
            self.assertEqual(len(list(backup_dir.glob("*.zip"))), 3)

    def test_microphone_list_has_windows_default_entry_without_audio_module(self) -> None:
        with patch("aura.system_tools.sd", None):
            devices = list_microphones()
        self.assertEqual(devices[0]["index"], -1)
        self.assertTrue(devices[0]["default"])

    def test_invalid_animation_intensity_falls_back_to_normal(self) -> None:
        settings = AssistantSettings.from_dict({"animation_intensity": "extreme"})
        self.assertEqual(settings.animation_intensity, "normal")

    def test_animation_preferences_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            store = SettingsStore(Path(folder))
            settings = AssistantSettings(
                animation_intensity="high",
                microphone_reactive_animation=False,
                reduce_motion=True,
            )
            store.save(settings)
            loaded = store.load()
            self.assertEqual(loaded.animation_intensity, "high")
            self.assertFalse(loaded.microphone_reactive_animation)
            self.assertTrue(loaded.reduce_motion)


if __name__ == "__main__":
    unittest.main()
