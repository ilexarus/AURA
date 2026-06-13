from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VENV = ROOT / ".venv"
LOG = ROOT / "launcher.log"
REQUIRED_MODULES = ("PySide6", "speech_recognition", "pyautogui", "keyboard", "pyperclip")


def write_log(message: str) -> None:
    with LOG.open("a", encoding="utf-8") as handle:
        handle.write(message.rstrip() + "\n")


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    write_log("> " + subprocess.list2cmdline(command))
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        errors="replace",
    )
    if completed.stdout:
        write_log(completed.stdout)
    if check and completed.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {completed.returncode}: {command[0]}")
    return completed


def venv_python() -> Path:
    if os.name == "nt":
        return VENV / "Scripts" / "python.exe"
    return VENV / "bin" / "python"


def modules_available(python: Path) -> bool:
    expression = "import importlib.util as u; assert all(u.find_spec(x) for x in " + repr(REQUIRED_MODULES) + ")"
    return run([str(python), "-c", expression], check=False).returncode == 0


def setup_environment(reset: bool = False) -> Path:
    if reset and VENV.exists():
        shutil.rmtree(VENV, ignore_errors=True)
    if not venv_python().exists():
        print("[AURA] Creating isolated Python environment...")
        run([sys.executable, "-m", "venv", str(VENV)])

    python = venv_python()
    if not modules_available(python):
        print("[AURA] Installing required components...")
        run([str(python), "-m", "pip", "install", "--disable-pip-version-check", "--upgrade", "pip"])
        run([str(python), "-m", "pip", "install", "--disable-pip-version-check", "-r", str(ROOT / "requirements-core.txt")])

    voice_marker = VENV / ".aura_voice_unavailable"
    pyaudio_check = run([str(python), "-c", "import pyaudio"], check=False)
    if pyaudio_check.returncode != 0 and not voice_marker.exists():
        print("[AURA] Installing optional microphone component...")
        result = run(
            [str(python), "-m", "pip", "install", "--disable-pip-version-check", "-r", str(ROOT / "requirements-voice.txt")],
            check=False,
        )
        if result.returncode != 0:
            voice_marker.write_text("Voice mode dependency installation failed.\n", encoding="ascii")
            print("[AURA] Microphone component is unavailable. Text mode will still work.")
    return python


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--setup-only", action="store_true")
    args = parser.parse_args()

    if sys.version_info < (3, 10):
        print("[ERROR] Python 3.10 or newer is required.")
        return 10

    write_log("=" * 60)
    write_log(f"AURA launcher {datetime.now().isoformat(timespec='seconds')}")
    write_log(f"Bootstrap Python: {sys.executable} {sys.version}")
    try:
        python = setup_environment(reset=args.reset)
        if args.setup_only:
            print("[AURA] Environment is ready.")
            return 0
        print("[AURA] Starting AURA...")
        result = run([str(python), str(ROOT / "app.py")], check=False)
        if result.returncode != 0:
            print(f"[ERROR] AURA exited with code {result.returncode}.")
            print(f"Log file: {LOG}")
            return result.returncode
        return 0
    except Exception as exc:
        write_log(f"FATAL: {type(exc).__name__}: {exc}")
        print(f"[ERROR] {exc}")
        print(f"Log file: {LOG}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
