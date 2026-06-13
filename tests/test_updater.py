from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from aura.update_client import (
    GitHubUpdateClient,
    ReleaseInfo,
    UpdateConfig,
    UpdateError,
    is_newer,
    load_config,
    parse_version,
)


class FakeClient(GitHubUpdateClient):
    def __init__(self, payload: bytes, expected_checksum: str) -> None:
        super().__init__(UpdateConfig.from_dict({}))
        self.payload = payload
        self.expected_checksum = expected_checksum

    def _get_bytes(self, url: str, max_size: int) -> bytes:
        return f"{self.expected_checksum}  AURA-Setup-9.9.9.exe\n".encode("ascii")

    def _download_file(self, url: str, target: Path, progress) -> None:
        target.write_bytes(self.payload)
        if progress:
            progress(100)


class UpdaterTests(unittest.TestCase):
    def test_version_comparison(self) -> None:
        self.assertEqual(parse_version("v1.2.3"), (1, 2, 3, 0))
        self.assertTrue(is_newer("1.2.4", "1.2.3"))
        self.assertFalse(is_newer("1.2.3", "1.2.3"))

    def test_config_requires_real_repository(self) -> None:
        config = UpdateConfig.from_dict({
            "enabled": True,
            "repository": "YOUR_GITHUB_USERNAME/YOUR_REPOSITORY",
        })
        self.assertFalse(config.configured)
        config = UpdateConfig.from_dict({"enabled": True, "repository": "owner/aura"})
        self.assertTrue(config.configured)

    def test_load_config_recovers_invalid_interval(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "update_config.json"
            path.write_text(json.dumps({
                "enabled": True,
                "repository": "owner/aura",
                "check_interval_minutes": "broken",
            }), encoding="utf-8")
            self.assertEqual(load_config(path).check_interval_minutes, 15)

    def test_legacy_hour_interval_is_converted_to_minutes(self) -> None:
        config = UpdateConfig.from_dict({"check_interval_hours": 2})
        self.assertEqual(config.check_interval_minutes, 120)

    def test_update_interval_is_never_below_five_minutes(self) -> None:
        config = UpdateConfig.from_dict({"check_interval_minutes": 1})
        self.assertEqual(config.check_interval_minutes, 5)

    def test_download_verifies_sha256(self) -> None:
        payload = b"installer bytes"
        checksum = hashlib.sha256(payload).hexdigest()
        release = ReleaseInfo(
            version="9.9.9",
            tag_name="v9.9.9",
            notes="",
            installer_name="AURA-Setup-9.9.9.exe",
            installer_url="https://example.invalid/installer",
            checksum_name="AURA-Setup-9.9.9.exe.sha256",
            checksum_url="https://example.invalid/checksum",
        )
        with tempfile.TemporaryDirectory() as folder:
            target = FakeClient(payload, checksum).download(release, Path(folder))
            self.assertEqual(target.read_bytes(), payload)

    def test_download_rejects_wrong_checksum(self) -> None:
        release = ReleaseInfo(
            version="9.9.9",
            tag_name="v9.9.9",
            notes="",
            installer_name="AURA-Setup-9.9.9.exe",
            installer_url="https://example.invalid/installer",
            checksum_name="AURA-Setup-9.9.9.exe.sha256",
            checksum_url="https://example.invalid/checksum",
        )
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(UpdateError):
                FakeClient(b"installer bytes", "0" * 64).download(release, Path(folder))


if __name__ == "__main__":
    unittest.main()
