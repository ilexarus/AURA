from __future__ import annotations

import math
import re
from collections.abc import Iterable

_WORD_RE = re.compile(r"[^0-9a-zа-яё]+", re.IGNORECASE)


def normalize_phrase(value: str) -> str:
    """Normalize recognized text and user wake phrases for safe comparison."""
    return " ".join(_WORD_RE.sub(" ", value.casefold()).split())


def contains_wake_phrase(text: str, wake_phrase: str) -> bool:
    normalized_text = f" {normalize_phrase(text)} "
    normalized_phrase = normalize_phrase(wake_phrase)
    return bool(normalized_phrase and f" {normalized_phrase} " in normalized_text)


def strip_leading_wake_phrase(text: str, wake_phrase: str) -> str:
    """Remove a leading wake phrase while keeping the actual command intact."""
    phrase_words = normalize_phrase(wake_phrase).split()
    if not phrase_words:
        return text.strip()
    phrase_pattern = r"\s+".join(re.escape(word) for word in phrase_words)
    pattern = re.compile(
        rf"^\s*(?:(?:эй|привет)\s+)?{phrase_pattern}(?:\s*[,.:;!\-]\s*|\s+)*",
        re.IGNORECASE,
    )
    cleaned = pattern.sub("", text, count=1).strip()
    return cleaned or text.strip()


def pcm_rms(data: bytes) -> float:
    """Return RMS for little-endian 16-bit mono PCM."""
    if len(data) < 2:
        return 0.0
    usable = len(data) - (len(data) % 2)
    samples = memoryview(data[:usable]).cast("h")
    if not samples:
        return 0.0
    square_sum = sum(int(sample) * int(sample) for sample in samples)
    return math.sqrt(square_sum / len(samples))


def extract_google_alternatives(payload: object) -> list[str]:
    """Extract unique transcripts from Google's extended recognition response."""
    candidates: list[str] = []
    if isinstance(payload, str):
        candidates.append(payload)
    elif isinstance(payload, dict):
        alternatives = payload.get("alternative")
        if isinstance(alternatives, Iterable) and not isinstance(alternatives, (str, bytes, dict)):
            for item in alternatives:
                if isinstance(item, dict):
                    transcript = str(item.get("transcript") or "").strip()
                    if transcript:
                        candidates.append(transcript)
    elif isinstance(payload, Iterable) and not isinstance(payload, (str, bytes, dict)):
        for item in payload:
            if isinstance(item, str) and item.strip():
                candidates.append(item.strip())

    unique: list[str] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = candidate.casefold().strip()
        if key and key not in seen:
            seen.add(key)
            unique.append(candidate.strip())
    return unique


_SILENT_SPEECH_CAPTURE_ERRORS = frozenset({
    "не услышал команду",
    "не удалось разобрать речь",
    "пустая запись команды",
})


def is_silent_speech_capture_error(message: str) -> bool:
    """Return True when speech capture ended without a usable command."""
    normalized = " ".join(str(message or "").casefold().split())
    return normalized in _SILENT_SPEECH_CAPTURE_ERRORS
