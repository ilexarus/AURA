from __future__ import annotations

import json
import math
import os
import shutil
import sys
import time
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Callable

try:
    import sounddevice as sd
except ImportError:  # pragma: no cover - optional native dependency
    sd = None


def list_microphones() -> list[dict[str, object]]:
    result: list[dict[str, object]] = [{"index": -1, "name": "Устройство Windows по умолчанию", "default": True}]
    if sd is None:
        return result
    try:
        devices = sd.query_devices()
        default_input = -1
        try:
            default_input = int(sd.default.device[0])
        except (TypeError, ValueError, IndexError):
            pass
        for index, device in enumerate(devices):
            try:
                channels = int(device.get("max_input_channels", 0))
            except (AttributeError, TypeError, ValueError):
                channels = 0
            if channels <= 0:
                continue
            name = str(device.get("name") or f"Микрофон {index}").strip()
            result.append({"index": index, "name": name, "default": index == default_input})
    except Exception:
        return result
    return result


def _rms_int16(payload: bytes) -> float:
    if not payload:
        return 0.0
    samples = memoryview(payload).cast("h")
    if not samples:
        return 0.0
    total = sum(int(sample) * int(sample) for sample in samples)
    return math.sqrt(total / len(samples))


def test_microphone(
    microphone_index: int | None,
    duration: float = 2.4,
    on_level: Callable[[int], None] | None = None,
) -> tuple[bool, str, int]:
    if sd is None:
        return False, "Модуль sounddevice не установлен", 0
    device = None if microphone_index is None or microphone_index < 0 else microphone_index
    peak = 0
    started = time.monotonic()
    try:
        with sd.RawInputStream(
            samplerate=16_000,
            blocksize=800,
            device=device,
            dtype="int16",
            channels=1,
            latency="low",
        ) as stream:
            while time.monotonic() - started < duration:
                data, overflowed = stream.read(800)
                if overflowed:
                    continue
                level = min(100, int(_rms_int16(bytes(data)) / 38.0))
                peak = max(peak, level)
                if on_level:
                    on_level(level)
    except Exception as exc:
        return False, f"Микрофон недоступен: {exc}", peak
    if peak < 3:
        return False, "Сигнал почти не слышен. Проверьте громкость и разрешения Windows", peak
    if peak < 12:
        return True, "Микрофон работает, но сигнал тихий", peak
    return True, "Микрофон работает нормально", peak


def create_backup(data_dir: Path) -> Path:
    data_dir = Path(data_dir)
    backup_dir = data_dir / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    target = backup_dir / f"AURA-backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}.zip"
    included = 0
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name in ("commands.json", "settings.json"):
            path = data_dir / name
            if path.is_file():
                archive.write(path, arcname=name)
                included += 1
        metadata = {
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "files": included,
        }
        archive.writestr("backup-info.json", json.dumps(metadata, ensure_ascii=False, indent=2))
    return target


def prune_backups(data_dir: Path, keep: int = 8) -> None:
    backup_dir = Path(data_dir) / "backups"
    if not backup_dir.is_dir():
        return
    backups = sorted(backup_dir.glob("AURA-backup-*.zip"), key=lambda item: item.stat().st_mtime, reverse=True)
    for path in backups[max(1, keep):]:
        path.unlink(missing_ok=True)


def set_autostart(enabled: bool, executable: Path, arguments: list[str] | None = None) -> tuple[bool, str]:
    if not sys.platform.startswith("win"):
        return False, "Автозапуск настраивается только в Windows"
    try:
        import winreg

        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_SET_VALUE) as key:
            if enabled:
                parts = [f'"{Path(executable).resolve()}"']
                for argument in arguments or []:
                    parts.append(f'"{argument}"')
                parts.append('--minimized')
                command = ' '.join(parts)
                winreg.SetValueEx(key, "AURA", 0, winreg.REG_SZ, command)
            else:
                try:
                    winreg.DeleteValue(key, "AURA")
                except FileNotFoundError:
                    pass
        return True, "Автозапуск включён" if enabled else "Автозапуск выключен"
    except Exception as exc:
        return False, f"Не удалось изменить автозапуск: {exc}"


def restore_backup(backup_path: Path, data_dir: Path) -> tuple[bool, str]:
    backup_path = Path(backup_path)
    data_dir = Path(data_dir)
    if not backup_path.is_file():
        return False, "Файл резервной копии не найден"
    try:
        with zipfile.ZipFile(backup_path, "r") as archive:
            names = set(archive.namelist())
            for name in ("commands.json", "settings.json"):
                if name not in names:
                    continue
                source = archive.open(name)
                target = data_dir / name
                temporary = target.with_suffix(target.suffix + ".restore")
                with source, temporary.open("wb") as output:
                    shutil.copyfileobj(source, output)
                temporary.replace(target)
        return True, "Резервная копия восстановлена. Перезапустите AURA"
    except (OSError, zipfile.BadZipFile) as exc:
        return False, f"Не удалось восстановить копию: {exc}"
