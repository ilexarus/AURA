from __future__ import annotations

import argparse
import ctypes
import logging
import os
import subprocess
import sys
import time
from pathlib import Path


def data_dir() -> Path:
    root = Path(os.getenv("LOCALAPPDATA") or Path.home()) / "AURA"
    root.mkdir(parents=True, exist_ok=True)
    return root


def configure_logging() -> None:
    logging.basicConfig(
        filename=data_dir() / "updater.log",
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        encoding="utf-8",
    )


def wait_for_pid(pid: int, timeout_seconds: int = 90) -> None:
    if pid <= 0:
        return
    if os.name == "nt":
        synchronize = 0x00100000
        handle = ctypes.windll.kernel32.OpenProcess(synchronize, False, pid)
        if handle:
            try:
                ctypes.windll.kernel32.WaitForSingleObject(handle, timeout_seconds * 1000)
                return
            finally:
                ctypes.windll.kernel32.CloseHandle(handle)
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except OSError:
            return
        time.sleep(0.25)


def main() -> int:
    configure_logging()
    parser = argparse.ArgumentParser()
    parser.add_argument("--wait-pid", type=int, required=True)
    parser.add_argument("--installer", required=True)
    parser.add_argument("--restart", required=True)
    args = parser.parse_args()

    installer = Path(args.installer).resolve()
    restart = Path(args.restart).resolve()
    if os.name != "nt":
        logging.error("Updater can run only on Windows")
        return 2
    if not installer.is_file():
        logging.error("Installer not found: %s", installer)
        return 3

    wait_for_pid(args.wait_pid)
    command = [
        str(installer),
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/SP-",
        "/CLOSEAPPLICATIONS",
        f'/LOG="{data_dir() / "setup-update.log"}"',
    ]
    logging.info("Starting installer: %s", command)
    try:
        completed = subprocess.run(command, timeout=600, check=False)
    except Exception:
        logging.exception("Unable to run installer")
        return 4
    if completed.returncode != 0:
        logging.error("Installer exited with code %s", completed.returncode)
        return completed.returncode or 5

    if restart.is_file():
        try:
            subprocess.Popen([str(restart)], cwd=str(restart.parent), close_fds=True)
        except OSError:
            logging.exception("Unable to restart AURA")
            return 6
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
