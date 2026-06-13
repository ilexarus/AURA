from __future__ import annotations

import hashlib
import os
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

MODEL_NAME = "vosk-model-small-ru-0.22"
MODEL_ARCHIVE = f"{MODEL_NAME}.zip"
EXPECTED_SHA256 = "961d5ff98a17f4aa6de69864d0aa71fa5bac682301d2b5d17a3f24c5c99a46d4"
EXPECTED_SIZE = 46_236_750
ROOT = Path(__file__).resolve().parents[1]
MODELS_DIR = ROOT / "models"
TARGET = MODELS_DIR / MODEL_NAME
MARKER = TARGET / "am" / "final.mdl"

DEFAULT_URLS = (
    f"https://alphacephei.com/vosk/models/{MODEL_ARCHIVE}",
    f"https://huggingface.co/localstack/vosk-models/resolve/main/{MODEL_ARCHIVE}?download=true",
    f"https://huggingface.co/rhasspy/vosk-models/resolve/main/ru/{MODEL_ARCHIVE}?download=true",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_archive(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError("Downloaded model archive was not created")
    size = path.stat().st_size
    if size != EXPECTED_SIZE:
        raise RuntimeError(f"Unexpected model size: {size} bytes, expected {EXPECTED_SIZE}")
    actual = sha256_file(path)
    if actual.lower() != EXPECTED_SHA256:
        raise RuntimeError(f"Model checksum mismatch: {actual}")
    if not zipfile.is_zipfile(path):
        raise RuntimeError("Downloaded model file is not a valid ZIP archive")


def safe_extract(archive: zipfile.ZipFile, destination: Path) -> None:
    root = destination.resolve()
    for member in archive.infolist():
        member_path = (destination / member.filename).resolve()
        if root not in member_path.parents and member_path != root:
            raise RuntimeError(f"Unsafe path in model archive: {member.filename}")
    archive.extractall(destination)


def ssl_context() -> ssl.SSLContext:
    try:
        import certifi  # type: ignore
    except Exception:
        return ssl.create_default_context()
    return ssl.create_default_context(cafile=certifi.where())


def download_with_python(url: str, target: Path) -> None:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "AURA/0.8.2 (+https://github.com/ilexarus/AURA)",
            "Accept": "application/zip,application/octet-stream,*/*",
        },
    )
    with urllib.request.urlopen(request, timeout=90, context=ssl_context()) as response, target.open("wb") as output:
        total_header = response.headers.get("Content-Length")
        total = int(total_header) if total_header and total_header.isdigit() else EXPECTED_SIZE
        downloaded = 0
        last_percent = -1
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            output.write(block)
            downloaded += len(block)
            percent = min(100, int(downloaded * 100 / max(total, 1)))
            if percent >= last_percent + 10:
                print(f"  {percent}%")
                last_percent = percent


def download_with_curl(url: str, target: Path) -> None:
    curl = shutil.which("curl.exe") or shutil.which("curl")
    if not curl:
        raise RuntimeError("curl is not installed")
    completed = subprocess.run(
        [
            curl,
            "-L",
            "--fail",
            "--silent",
            "--show-error",
            "--retry",
            "2",
            "--connect-timeout",
            "25",
            "--max-time",
            "240",
            "-o",
            str(target),
            url,
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        errors="replace",
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stdout.strip() or f"curl exited with code {completed.returncode}")


def candidate_urls() -> list[str]:
    override = os.environ.get("AURA_WAKE_MODEL_URL", "").strip()
    urls = [override] if override else []
    urls.extend(DEFAULT_URLS)
    return list(dict.fromkeys(urls))


def local_archives() -> list[Path]:
    return [
        ROOT / MODEL_ARCHIVE,
        MODELS_DIR / MODEL_ARCHIVE,
        Path.home() / "Downloads" / MODEL_ARCHIVE,
    ]


def acquire_archive(target: Path) -> str:
    for local in local_archives():
        if not local.is_file():
            continue
        print(f"Checking local model archive: {local}")
        try:
            verify_archive(local)
            shutil.copy2(local, target)
            return str(local)
        except Exception as exc:
            print(f"  Local archive rejected: {exc}", file=sys.stderr)

    errors: list[str] = []
    for url in candidate_urls():
        for method_name, method in (("Python", download_with_python), ("curl", download_with_curl)):
            target.unlink(missing_ok=True)
            print(f"Downloading model with {method_name}: {url}")
            try:
                method(url, target)
                verify_archive(target)
                return url
            except Exception as exc:
                message = f"{method_name} failed for {url}: {exc}"
                errors.append(message)
                print(f"  {message}", file=sys.stderr)
                time.sleep(1)

    raise RuntimeError("All model download sources failed:\n" + "\n".join(errors))


def install_archive(zip_path: Path) -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aura-model-extract-", dir=MODELS_DIR) as temporary:
        staging = Path(temporary)
        with zipfile.ZipFile(zip_path) as archive:
            safe_extract(archive, staging)
        extracted = staging / MODEL_NAME
        marker = extracted / "am" / "final.mdl"
        if not marker.is_file():
            raise RuntimeError("Model archive does not contain the expected Vosk files")
        if TARGET.exists():
            shutil.rmtree(TARGET, ignore_errors=True)
        shutil.move(str(extracted), str(TARGET))


def main() -> int:
    if MARKER.is_file():
        print(f"Wake model is ready: {TARGET}")
        return 0

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="aura-model-download-") as temporary:
            zip_path = Path(temporary) / MODEL_ARCHIVE
            source = acquire_archive(zip_path)
            print(f"Verified model source: {source}")
            install_archive(zip_path)
    except Exception as exc:
        print(f"Unable to install wake model: {exc}", file=sys.stderr)
        print("Manual fallback:", file=sys.stderr)
        print(f"  1. Download {MODEL_ARCHIVE}", file=sys.stderr)
        print(f"  2. Place it in {ROOT}", file=sys.stderr)
        print("  3. Run REPAIR_VOICE_ACTIVATION.cmd", file=sys.stderr)
        return 1

    if not MARKER.is_file():
        print("Wake model installation finished without the expected marker", file=sys.stderr)
        return 2
    print(f"Wake model installed: {TARGET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
