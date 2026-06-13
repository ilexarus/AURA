from pathlib import Path
import unittest

from updater_launcher import build_installer_command


class UpdaterLauncherTests(unittest.TestCase):
    def test_log_argument_has_no_embedded_quotes(self):
        command = build_installer_command(
            Path(r"C:\Program Files\AURA Update\setup.exe"),
            Path(r"C:\Users\Alex\AppData\Local\AURA\setup-update.log"),
        )
        log_arg = next(item for item in command if item.startswith("/LOG="))
        self.assertNotIn('"', log_arg)
        self.assertEqual(
            log_arg,
            r"/LOG=C:\Users\Alex\AppData\Local\AURA\setup-update.log",
        )

    def test_force_close_is_enabled(self):
        command = build_installer_command(Path("setup.exe"), Path("setup.log"))
        self.assertIn("/CLOSEAPPLICATIONS", command)
        self.assertIn("/FORCECLOSEAPPLICATIONS", command)


if __name__ == "__main__":
    unittest.main()
