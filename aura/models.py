from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any
from uuid import uuid4


@dataclass(slots=True)
class ActionStep:
    """One safe, user-visible action in a command scenario."""

    action_type: str
    value: str = ""
    delay_after: float = 0.0
    enabled: bool = True
    retry_count: int = 0
    continue_on_error: bool = False
    id: str = field(default_factory=lambda: str(uuid4()))

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "ActionStep":
        try:
            delay = max(0.0, min(float(payload.get("delay_after", 0.0)), 60.0))
        except (TypeError, ValueError):
            delay = 0.0
        try:
            retries = max(0, min(int(payload.get("retry_count", 0)), 5))
        except (TypeError, ValueError):
            retries = 0
        return cls(
            id=str(payload.get("id") or uuid4()),
            action_type=str(payload.get("action_type") or "open_url"),
            value=str(payload.get("value") or payload.get("action_value") or ""),
            delay_after=delay,
            enabled=bool(payload.get("enabled", True)),
            retry_count=retries,
            continue_on_error=bool(payload.get("continue_on_error", False)),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class VoiceCommand:
    """A voice phrase mapped to one or more visual action steps."""

    name: str
    phrases: list[str]
    actions: list[ActionStep]
    enabled: bool = True
    require_confirmation: bool = False
    id: str = field(default_factory=lambda: str(uuid4()))

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "VoiceCommand":
        raw_actions = payload.get("actions")
        if isinstance(raw_actions, list) and raw_actions:
            actions = [ActionStep.from_dict(item) for item in raw_actions if isinstance(item, dict)]
        else:
            actions = [
                ActionStep(
                    action_type=str(payload.get("action_type") or "open_url"),
                    value=str(payload.get("action_value") or ""),
                )
            ]
        return cls(
            id=str(payload.get("id") or uuid4()),
            name=str(payload.get("name") or "Новая команда"),
            phrases=[str(item).strip() for item in payload.get("phrases", []) if str(item).strip()],
            actions=actions,
            enabled=bool(payload.get("enabled", True)),
            require_confirmation=bool(payload.get("require_confirmation", False)),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
