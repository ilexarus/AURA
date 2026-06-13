from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import shutil
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


class UpdateError(RuntimeError):
    pass


@dataclass(slots=True)
class UpdateConfig:
    enabled: bool
    provider: str
    repository: str
    check_interval_hours: int
    auto_download: bool
    asset_name_template: str
    checksum_name_template: str

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "UpdateConfig":
        try:
            interval = int(payload.get("check_interval_hours", 12))
        except (TypeError, ValueError):
            interval = 12
        return cls(
            enabled=bool(payload.get("enabled", False)),
            provider=str(payload.get("provider") or "github").strip().lower(),
            repository=str(payload.get("repository") or "").strip(),
            check_interval_hours=max(1, min(interval, 168)),
            auto_download=bool(payload.get("auto_download", True)),
            asset_name_template=str(payload.get("asset_name_template") or "AURA-Setup-{version}.exe"),
            checksum_name_template=str(payload.get("checksum_name_template") or "AURA-Setup-{version}.exe.sha256"),
        )

    @property
    def configured(self) -> bool:
        return (
            self.enabled
            and self.provider == "github"
            and "/" in self.repository
            and "YOUR_GITHUB" not in self.repository.upper()
            and "YOUR_REPOSITORY" not in self.repository.upper()
        )


@dataclass(slots=True)
class ReleaseInfo:
    version: str
    tag_name: str
    notes: str
    installer_name: str
    installer_url: str
    checksum_name: str
    checksum_url: str


def parse_version(value: str) -> tuple[int, int, int, int]:
    clean = value.strip().lower().lstrip("v")
    match = re.match(r"^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?", clean)
    if not match:
        raise UpdateError(f"Некорректная версия: {value}")
    numbers = [int(item or 0) for item in match.groups(default="0")]
    return tuple(numbers)  # type: ignore[return-value]


def is_newer(candidate: str, current: str) -> bool:
    return parse_version(candidate) > parse_version(current)


def load_config(path: Path) -> UpdateConfig:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        logging.info("Update config not found: %s", path)
        return UpdateConfig.from_dict({})
    except (OSError, json.JSONDecodeError) as exc:
        raise UpdateError(f"Не удалось прочитать настройки обновлений: {exc}") from exc
    if not isinstance(payload, dict):
        raise UpdateError("update_config.json должен содержать объект JSON")
    return UpdateConfig.from_dict(payload)


class GitHubUpdateClient:
    API_VERSION = "2026-03-10"
    USER_AGENT = "AURA-Updater/1.0"
    MAX_INSTALLER_SIZE = 500 * 1024 * 1024

    def __init__(self, config: UpdateConfig) -> None:
        self.config = config

    def check(self, current_version: str) -> ReleaseInfo | None:
        if not self.config.configured:
            return None
        owner_repo = self.config.repository.strip().strip("/")
        url = f"https://api.github.com/repos/{owner_repo}/releases/latest"
        payload = self._get_json(url)
        tag_name = str(payload.get("tag_name") or "").strip()
        candidate = tag_name.lstrip("vV")
        if not candidate or not is_newer(candidate, current_version):
            return None

        assets = payload.get("assets")
        if not isinstance(assets, list):
            raise UpdateError("В выпуске GitHub нет списка файлов")
        installer_name = self.config.asset_name_template.format(version=candidate, tag=tag_name)
        checksum_name = self.config.checksum_name_template.format(version=candidate, tag=tag_name)
        installer_url = self._asset_url(assets, installer_name)
        checksum_url = self._asset_url(assets, checksum_name)
        if not installer_url:
            raise UpdateError(f"В выпуске не найден файл {installer_name}")
        if not checksum_url:
            raise UpdateError(f"В выпуске не найден файл контрольной суммы {checksum_name}")
        return ReleaseInfo(
            version=candidate,
            tag_name=tag_name,
            notes=str(payload.get("body") or "").strip(),
            installer_name=installer_name,
            installer_url=installer_url,
            checksum_name=checksum_name,
            checksum_url=checksum_url,
        )

    def download(
        self,
        release: ReleaseInfo,
        destination_dir: Path,
        progress: Callable[[int], None] | None = None,
    ) -> Path:
        destination_dir.mkdir(parents=True, exist_ok=True)
        checksum_text = self._get_bytes(release.checksum_url, max_size=128 * 1024).decode("utf-8", errors="replace")
        expected = self._parse_checksum(checksum_text)

        target = destination_dir / release.installer_name
        temporary = target.with_suffix(target.suffix + ".part")
        try:
            self._download_file(release.installer_url, temporary, progress)
            actual = self._sha256(temporary)
            if actual.lower() != expected.lower():
                raise UpdateError("Контрольная сумма обновления не совпала. Установка отменена")
            temporary.replace(target)
            return target
        finally:
            temporary.unlink(missing_ok=True)

    def _get_json(self, url: str) -> dict[str, Any]:
        raw = self._get_bytes(url, max_size=5 * 1024 * 1024)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise UpdateError("GitHub вернул некорректный ответ") from exc
        if not isinstance(payload, dict):
            raise UpdateError("GitHub вернул неожиданный формат ответа")
        return payload

    def _get_bytes(self, url: str, max_size: int) -> bytes:
        request = urllib.request.Request(
            url,
            headers={
                "Accept": "application/vnd.github+json",
                "User-Agent": self.USER_AGENT,
                "X-GitHub-Api-Version": self.API_VERSION,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                length = int(response.headers.get("Content-Length") or 0)
                if length and length > max_size:
                    raise UpdateError("Ответ сервера слишком большой")
                data = response.read(max_size + 1)
                if len(data) > max_size:
                    raise UpdateError("Ответ сервера слишком большой")
                return data
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                raise UpdateError("Репозиторий или опубликованный выпуск не найден") from exc
            raise UpdateError(f"GitHub вернул ошибку HTTP {exc.code}") from exc
        except urllib.error.URLError as exc:
            raise UpdateError(f"Не удалось подключиться к серверу обновлений: {exc.reason}") from exc
        except TimeoutError as exc:
            raise UpdateError("Сервер обновлений не ответил вовремя") from exc

    def _download_file(self, url: str, target: Path, progress: Callable[[int], None] | None) -> None:
        request = urllib.request.Request(
            url,
            headers={"User-Agent": self.USER_AGENT, "Accept": "application/octet-stream"},
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response, target.open("wb") as output:
                total = int(response.headers.get("Content-Length") or 0)
                if total and total > self.MAX_INSTALLER_SIZE:
                    raise UpdateError("Файл обновления слишком большой")
                copied = 0
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    copied += len(chunk)
                    if copied > self.MAX_INSTALLER_SIZE:
                        raise UpdateError("Файл обновления слишком большой")
                    output.write(chunk)
                    if progress:
                        progress(int(copied * 100 / total) if total else 0)
        except urllib.error.URLError as exc:
            raise UpdateError(f"Не удалось скачать обновление: {exc.reason}") from exc
        except OSError as exc:
            raise UpdateError(f"Не удалось сохранить обновление: {exc}") from exc

    @staticmethod
    def _asset_url(assets: list[Any], name: str) -> str:
        for asset in assets:
            if isinstance(asset, dict) and str(asset.get("name") or "") == name:
                return str(asset.get("browser_download_url") or "")
        return ""

    @staticmethod
    def _parse_checksum(text: str) -> str:
        match = re.search(r"\b([a-fA-F0-9]{64})\b", text)
        if not match:
            raise UpdateError("Файл контрольной суммы имеет неверный формат")
        return match.group(1)

    @staticmethod
    def _sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()


def update_cache_dir() -> Path:
    root = Path(os.getenv("LOCALAPPDATA") or tempfile.gettempdir()) / "AURA" / "updates"
    root.mkdir(parents=True, exist_ok=True)
    return root


def clear_old_updates(directory: Path, keep: Path | None = None) -> None:
    try:
        for item in directory.iterdir():
            if keep and item.resolve() == keep.resolve():
                continue
            if item.is_file() and (item.suffix.lower() in {".exe", ".part", ".sha256"}):
                item.unlink(missing_ok=True)
            elif item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
    except OSError:
        logging.exception("Unable to clear old update files")
