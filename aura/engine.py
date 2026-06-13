from __future__ import annotations

import re
from dataclasses import dataclass
from difflib import SequenceMatcher

from .models import VoiceCommand


@dataclass(slots=True)
class MatchResult:
    command: VoiceCommand
    score: float
    phrase: str


class CommandMatcher:
    """Tolerant matching for small speech-recognition errors."""

    @staticmethod
    def normalize(text: str) -> str:
        text = text.lower().replace("ё", "е")
        text = re.sub(r"[^a-zа-я0-9+ ]+", " ", text, flags=re.IGNORECASE)
        return " ".join(text.split())

    def find(self, transcript: str, commands: list[VoiceCommand]) -> MatchResult | None:
        spoken = self.normalize(transcript)
        if not spoken:
            return None

        best: MatchResult | None = None
        for command in commands:
            if not command.enabled:
                continue
            for raw_phrase in command.phrases:
                phrase = self.normalize(raw_phrase)
                if not phrase:
                    continue
                if phrase == spoken:
                    score = 1.0
                elif phrase in spoken or spoken in phrase:
                    shorter = min(len(phrase), len(spoken))
                    longer = max(len(phrase), len(spoken))
                    score = 0.86 + 0.14 * (shorter / max(longer, 1))
                else:
                    score = SequenceMatcher(None, spoken, phrase).ratio()
                if best is None or score > best.score:
                    best = MatchResult(command, score, raw_phrase)
        return best if best and best.score >= 0.69 else None
