from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from .catalog import ACTION_BY_TYPE
from .models import ActionStep, VoiceCommand


@dataclass(frozen=True, slots=True)
class ValidationIssue:
    level: str
    message: str
    step_index: int = -1
    field: str = ""

    def to_dict(self) -> dict[str, object]:
        return {
            "level": self.level,
            "message": self.message,
            "step_index": self.step_index,
            "field": self.field,
        }


def _is_time(value: str) -> bool:
    match = re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", value.strip())
    return match is not None


def validate_step(step: ActionStep, index: int = -1) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    spec = ACTION_BY_TYPE.get(step.action_type)
    if spec is None:
        return [ValidationIssue("error", "Неизвестный тип действия", index, "action_type")]

    value = step.value.strip()
    if spec.requires_value and not value:
        issues.append(ValidationIssue("error", "Заполните значение действия", index, "value"))
        return issues

    if step.action_type == "open_url" and value:
        parsed = urlparse(value if "://" in value else f"https://{value}")
        if not parsed.netloc:
            issues.append(ValidationIssue("error", "Проверьте адрес сайта", index, "value"))
    elif step.action_type == "wait" and value:
        try:
            seconds = float(value.replace(",", "."))
            if not 0 <= seconds <= 60:
                issues.append(ValidationIssue("error", "Пауза должна быть от 0 до 60 секунд", index, "value"))
        except ValueError:
            issues.append(ValidationIssue("error", "Укажите число секунд", index, "value"))
    elif step.action_type == "mouse_click" and value:
        parts = [part.strip() for part in value.split(",")]
        if len(parts) < 2:
            issues.append(ValidationIssue("error", "Формат клика: x,y,left,1", index, "value"))
        else:
            try:
                int(parts[0]); int(parts[1])
            except ValueError:
                issues.append(ValidationIssue("error", "Координаты клика должны быть числами", index, "value"))
    elif step.action_type == "require_time" and value:
        start, separator, end = value.replace(" ", "").partition("-")
        if not separator or not _is_time(start) or not _is_time(end):
            issues.append(ValidationIssue("error", "Формат времени: 09:00-18:00", index, "value"))
    elif step.action_type == "wait_window" and value:
        title, _, timeout = value.partition("|")
        if not title.strip():
            issues.append(ValidationIssue("error", "Укажите название окна", index, "value"))
        if timeout.strip():
            try:
                if not 0.1 <= float(timeout.replace(",", ".")) <= 120:
                    raise ValueError
            except ValueError:
                issues.append(ValidationIssue("error", "Тайм-аут окна должен быть от 0,1 до 120 секунд", index, "value"))
    elif step.action_type in {"open_path", "require_file"} and value:
        if not any(token in value for token in ("${", "%", "~")) and not Path(value).is_absolute():
            issues.append(ValidationIssue("warning", "Лучше использовать полный путь", index, "value"))

    if step.delay_after < 0 or step.delay_after > 60:
        issues.append(ValidationIssue("error", "Пауза после действия должна быть от 0 до 60 секунд", index, "delay_after"))
    if step.retry_count < 0 or step.retry_count > 5:
        issues.append(ValidationIssue("error", "Количество повторов должно быть от 0 до 5", index, "retry_count"))
    if spec.dangerous:
        issues.append(ValidationIssue("warning", "Системная команда потребует подтверждения", index, "action_type"))
    return issues


def validate_command(command: VoiceCommand) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    if not command.name.strip():
        issues.append(ValidationIssue("error", "Укажите название команды", field="name"))
    if command.trigger_type == "voice" and not command.phrases:
        issues.append(ValidationIssue("error", "Добавьте хотя бы одну голосовую фразу", field="phrases"))
    if command.trigger_type == "daily" and not _is_time(command.trigger_value):
        issues.append(ValidationIssue("error", "Укажите время запуска в формате 09:00", field="trigger_value"))
    if not command.actions:
        issues.append(ValidationIssue("error", "Добавьте хотя бы одно действие", field="actions"))
    elif not any(step.enabled for step in command.actions):
        issues.append(ValidationIssue("error", "Включите хотя бы одно действие", field="actions"))

    normalized: set[str] = set()
    for phrase in command.phrases:
        folded = " ".join(phrase.casefold().split())
        if folded in normalized:
            issues.append(ValidationIssue("warning", f"Повторяющаяся фраза: {phrase}", field="phrases"))
        normalized.add(folded)

    for index, step in enumerate(command.actions):
        if step.enabled:
            issues.extend(validate_step(step, index))
    return issues
