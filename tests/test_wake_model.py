from __future__ import annotations

import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.download_wake_model import EXPECTED_SHA256, safe_extract, sha256_file


class WakeModelTests(unittest.TestCase):
    def test_sha256_file(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "sample.bin"
            path.write_bytes(b"aura")
            self.assertEqual(sha256_file(path), hashlib.sha256(b"aura").hexdigest())
            self.assertEqual(len(EXPECTED_SHA256), 64)

    def test_safe_extract_rejects_parent_path(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            archive_path = Path(folder) / "bad.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("../outside.txt", "bad")
            with zipfile.ZipFile(archive_path) as archive:
                with self.assertRaises(RuntimeError):
                    safe_extract(archive, Path(folder) / "extract")


if __name__ == "__main__":
    unittest.main()
