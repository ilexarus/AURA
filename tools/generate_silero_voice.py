from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request
import wave
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PHRASES: dict[str, str] = {
    "executing": "Выполн+яю.",
    "done": "Гот+ово.",
    "not_found": "Я не наш+ёл так+ую ком+анду.",
    "failed": "Не удал+ось в+ыполнить ком+анду.",
    "confirmation": "Подтверд+ите д+ействие.",
    "recording_started": "З+апись начат+а.",
    "recording_stopped": "З+апись завершен+а.",
    "cancelled": "Д+ействие отменен+о.",
}

VOICE_FILES: dict[str, str] = {key: f"{key}.wav" for key in PHRASES}


@dataclass(frozen=True, slots=True)
class VoiceProfile:
    name: str
    model_id: str
    model_url: str
    speaker: str
    license_name: str
    attribution: str
    commercial_use: bool


PROFILES: dict[str, VoiceProfile] = {
    "quality": VoiceProfile(
        name="quality",
        model_id="v5_5_ru",
        model_url="https://models.silero.ai/models/tts/ru/v5_5_ru.pt",
        speaker="eugene",
        license_name="CC BY-NC 4.0",
        attribution="Silero Models by Silero Team",
        commercial_use=False,
    ),
    "mit": VoiceProfile(
        name="mit",
        model_id="v5_cis_base_nostress",
        model_url="https://models.silero.ai/models/tts/ru/v5_cis_base_nostress.pt",
        speaker="ru_bel_dmitriy",
        license_name="MIT",
        attribution="Silero CIS Base TTS by Silero Team",
        commercial_use=True,
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate the local AURA voice pack with Silero TTS.")
    parser.add_argument("--profile", choices=sorted(PROFILES), default=os.getenv("AURA_VOICE_PROFILE", "quality"))
    parser.add_argument("--speaker", default=os.getenv("AURA_VOICE_SPEAKER", ""))
    parser.add_argument("--output", type=Path, default=Path("assets") / "voice")
    parser.add_argument("--cache", type=Path, default=Path(".cache") / "silero")
    parser.add_argument("--sample-rate", type=int, choices=(24000, 48000), default=48000)
    parser.add_argument("--threads", type=int, default=max(1, min(4, os.cpu_count() or 1)))
    parser.add_argument("--force-download", action="store_true")
    parser.add_argument("--no-processing", action="store_true")
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_file(url: str, destination: Path, *, attempts: int = 4) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".download")
    headers = {"User-Agent": "AURA-voice-pack-builder/0.8.2"}
    last_error: Exception | None = None

    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=90) as response, temporary.open("wb") as target:
                total = int(response.headers.get("Content-Length") or 0)
                received = 0
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    target.write(chunk)
                    received += len(chunk)
                    if total:
                        print(f"[AURA] Model download: {received * 100 // total}%", end="\r", flush=True)
            print()
            if temporary.stat().st_size < 1_000_000:
                raise RuntimeError("Downloaded model is unexpectedly small")
            temporary.replace(destination)
            return
        except (OSError, RuntimeError, urllib.error.URLError) as exc:
            last_error = exc
            temporary.unlink(missing_ok=True)
            if attempt < attempts:
                delay = min(2**attempt, 8)
                print(f"[AURA] Download failed, retrying in {delay}s: {exc}")
                time.sleep(delay)

    raise RuntimeError(f"Unable to download Silero model: {last_error}")


def prepare_model_for_inference(model: Any, torch_module: Any) -> Any:
    """Move a packaged Silero model to CPU without assuming nn.Module methods.

    Current Silero v5 packages expose ``to`` and ``apply_tts``, but the loaded
    wrapper is not guaranteed to implement ``eval``. Older AURA builds called
    ``eval`` unconditionally and failed with recent v5_5_ru packages.
    """
    move_to = getattr(model, "to", None)
    if callable(move_to):
        move_to(torch_module.device("cpu"))

    set_eval = getattr(model, "eval", None)
    if callable(set_eval):
        set_eval()

    if not callable(getattr(model, "apply_tts", None)):
        raise RuntimeError("Loaded Silero package does not provide apply_tts")
    return model


def load_model(model_path: Path, threads: int) -> Any:
    try:
        import torch
    except ImportError as exc:
        raise RuntimeError(
            "PyTorch is not installed. Run GENERATE_SILERO_VOICE.cmd or install the CPU build of torch."
        ) from exc

    torch.set_num_threads(max(1, threads))
    importer = torch.package.PackageImporter(str(model_path))
    model = importer.load_pickle("tts_models", "model")
    return prepare_model_for_inference(model, torch)


def as_float_audio(value: Any) -> "Any":
    import numpy as np

    if hasattr(value, "detach"):
        value = value.detach().cpu().numpy()
    data = np.asarray(value, dtype=np.float32).reshape(-1)
    if not data.size:
        raise RuntimeError("Silero returned empty audio")
    data = np.nan_to_num(data, nan=0.0, posinf=0.0, neginf=0.0)
    return data


def _trim_silence(data: "Any", sample_rate: int) -> "Any":
    import numpy as np

    threshold = max(0.0015, float(np.max(np.abs(data))) * 0.012)
    indices = np.flatnonzero(np.abs(data) >= threshold)
    if not len(indices):
        return data
    padding = int(sample_rate * 0.045)
    start = max(0, int(indices[0]) - padding)
    end = min(len(data), int(indices[-1]) + padding + 1)
    return data[start:end]


def process_audio(data: "Any", sample_rate: int) -> "Any":
    """Make short UI phrases cleaner without adding an artificial robot effect."""
    import numpy as np

    data = data.astype(np.float32, copy=True)
    data -= float(np.mean(data))
    data = _trim_silence(data, sample_rate)

    # Gentle pre-emphasis to improve consonant clarity on laptop speakers.
    if len(data) > 1:
        emphasized = data.copy()
        emphasized[1:] = data[1:] - 0.08 * data[:-1]
        data = emphasized

    # Soft compression keeps all short phrases at a similar perceived level.
    data = np.tanh(data * 1.28) / math.tanh(1.28)

    peak = float(np.max(np.abs(data))) if len(data) else 0.0
    if peak > 0:
        data *= 0.91 / peak

    fade_frames = min(int(sample_rate * 0.014), max(0, len(data) // 8))
    if fade_frames:
        fade = np.linspace(0.0, 1.0, fade_frames, dtype=np.float32)
        data[:fade_frames] *= fade
        data[-fade_frames:] *= fade[::-1]
    return np.clip(data, -1.0, 1.0)


def write_pcm16(path: Path, data: "Any", sample_rate: int) -> None:
    import numpy as np

    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def generate_pack(args: argparse.Namespace) -> dict[str, object]:
    profile = PROFILES[args.profile]
    speaker = args.speaker.strip() or profile.speaker
    cache_path = args.cache / f"{profile.model_id}.pt"
    if args.force_download:
        cache_path.unlink(missing_ok=True)
    if not cache_path.is_file():
        print(f"[AURA] Downloading Silero model {profile.model_id}...")
        download_file(profile.model_url, cache_path)
    else:
        print(f"[AURA] Using cached Silero model: {cache_path}")

    print(f"[AURA] Loading voice model, speaker={speaker}, sample_rate={args.sample_rate}...")
    model = load_model(cache_path, args.threads)
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output / "voice_pack.json"
    manifest_path.unlink(missing_ok=True)
    staging = args.output / ".voice_staging"
    if staging.exists():
        import shutil

        shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True, exist_ok=True)

    files: dict[str, dict[str, object]] = {}
    for index, (key, text) in enumerate(PHRASES.items(), start=1):
        print(f"[AURA] Generating {index}/{len(PHRASES)}: {key}")
        try:
            audio = model.apply_tts(text=text, speaker=speaker, sample_rate=args.sample_rate)
        except Exception as exc:
            raise RuntimeError(f"Silero failed on phrase {key!r} with speaker {speaker!r}: {exc}") from exc
        data = as_float_audio(audio)
        if not args.no_processing:
            data = process_audio(data, args.sample_rate)
        path = staging / VOICE_FILES[key]
        write_pcm16(path, data, args.sample_rate)
        files[key] = {
            "file": path.name,
            "text": text.replace("+", ""),
            "sha256": sha256_file(path),
            "frames": int(len(data)),
        }

    manifest: dict[str, object] = {
        "format": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator": "AURA Silero voice pack builder 0.8.2",
        "profile": profile.name,
        "model": profile.model_id,
        "model_sha256": sha256_file(cache_path),
        "speaker": speaker,
        "sample_rate": args.sample_rate,
        "license": profile.license_name,
        "commercial_use": profile.commercial_use,
        "attribution": profile.attribution,
        "files": files,
    }
    for filename in VOICE_FILES.values():
        (staging / filename).replace(args.output / filename)
    staging.rmdir()
    temporary_manifest = manifest_path.with_suffix(".json.tmp")
    temporary_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary_manifest.replace(manifest_path)
    print(f"[AURA] Voice pack is ready: {args.output.resolve()}")
    print(f"[AURA] License profile: {profile.license_name}")
    return manifest


def main() -> int:
    args = parse_args()
    try:
        generate_pack(args)
        return 0
    except Exception as exc:
        print(f"[AURA] Voice generation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
