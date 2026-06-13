from __future__ import annotations

import logging
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot


from .voice_assets import resolve_voice_file


def play_wav_blocking(path: Path) -> None:
    """Play one local PCM WAV file without network access."""
    if not path.is_file():
        raise FileNotFoundError(path)
    if sys.platform.startswith("win"):
        import winsound

        winsound.PlaySound(str(path), winsound.SND_FILENAME | winsound.SND_NODEFAULT)
        return

    # Source-mode fallback for Linux/macOS developers. Production builds target Windows.
    import shutil
    import subprocess

    for player in ("aplay", "paplay", "afplay"):
        executable = shutil.which(player)
        if executable:
            subprocess.run([executable, str(path)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
    logging.info("No local WAV player available for %s", path)


class VoiceFeedbackWorker(QObject):
    failed = Signal(str)
    done = Signal()

    def __init__(self, path: Path) -> None:
        super().__init__()
        self.path = Path(path)

    @Slot()
    def run(self) -> None:
        try:
            play_wav_blocking(self.path)
        except Exception as exc:
            logging.exception("Unable to play AURA voice feedback")
            self.failed.emit(str(exc))
        finally:
            self.done.emit()
