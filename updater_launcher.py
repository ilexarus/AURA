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


def show_error(message: str) -> None:
    logging.error(message)
    if os.name == "nt":
        try:
            ctypes.windll.user32.MessageBoxW(None, message, "AURA Update", 0x10)
        except Exception:
            logging.exception("Unable to show updater error dialog")


def wait_for_pid(pid: int, timeout_seconds: int = 90) -> None:
    if pid <= 0:
        return
    if os.name == "nt":
        synchronize = 0x00100000
        handle = ctypes.windll.kernel32.OpenProcess(synchronize, False, pid)
        if handle:
            try:
                result = ctypes.windll.kernel32.WaitForSingleObject(handle, timeout_seconds * 1000)
                if result == 0:
                    return
                logging.warning("Timed out waiting for AURA process %s to exit", pid)
            finally:
                ctypes.windll.kernel32.CloseHandle(handle)
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except OSError:
            return
        time.sleep(0.25)


def build_installer_command(installer: Path, log_path: Path) -> list[str]:
    # Do not embed quotation marks in the /LOG argument. subprocess will quote the
    # complete argument when needed. Embedded quotes were escaped by Python on
    # Windows and Inno Setup rejected the command line before creating its log.
    return [
        str(installer),
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/SP-",
        "/CLOSEAPPLICATIONS",
        "/FORCECLOSEAPPLICATIONS",
        f"/LOG={log_path}",
    ]


def restart_aura(restart: Path, attempts: int = 8) -> bool:
    for attempt in range(1, attempts + 1):
        if restart.is_file():
            try:
                subprocess.Popen([str(restart)], cwd=str(restart.parent), close_fds=True)
                logging.info("AURA restarted successfully on attempt %s", attempt)
                return True
            except OSError:
                logging.exception("Unable to restart AURA on attempt %s", attempt)
        time.sleep(1.0)
    return False


def main() -> int:
    configure_logging()
    parser = argparse.ArgumentParser()
    parser.add_argument("--wait-pid", type=int, required=True)
    parser.add_argument("--installer", required=True)
    parser.add_argument("--restart", required=True)
    args = parser.parse_args()

    installer = Path(args.installer).resolve()
    restart = Path(args.restart).resolve()
    setup_log = data_dir() / "setup-update.log"

    if os.name != "nt":
        logging.error("Updater can run only on Windows")
        return 2
    if not installer.is_file():
        show_error(f"Update installer was not found:\n{installer}")
        return 3

    try:
        size = installer.stat().st_size
    except OSError:
        size = -1
    logging.info("Updater started. Installer=%s size=%s restart=%s", installer, size, restart)

    wait_for_pid(args.wait_pid)
    setup_log.unlink(missing_ok=True)
    command = build_installer_command(installer, setup_log)
    logging.info("Starting installer: %s", command)

    try:
        completed = subprocess.run(command, timeout=600, check=False)
    except Exception as exc:
        logging.exception("Unable to run installer")
        show_error(f"AURA could not start the update installer.\n\n{exc}\n\nSee:\n{data_dir() / 'updater.log'}")
        return 4

    logging.info("Installer finished with exit code %s", completed.returncode)
    if completed.returncode != 0:
        if setup_log.is_file():
            details = f"Installation log:\n{setup_log}"
        else:
            details = (
                "The installer stopped before Inno Setup could create its log.\n"
                "The downloaded installer can be started manually from:\n"
                f"{installer}"
            )
        show_error(
            "AURA update failed.\n\n"
            f"Installer exit code: {completed.returncode}\n\n"
            f"{details}"
        )
        return completed.returncode or 5

    if not restart_aura(restart):
        show_error(
            "AURA was updated, but could not be restarted automatically.\n\n"
            "Start AURA from the desktop shortcut."
        )
        return 6
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
