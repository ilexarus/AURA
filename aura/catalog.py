from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True, slots=True)
class ActionSpec:
    type: str
    label: str
    description: str
    hint: str
    category: str
    icon: str
    requires_value: bool = True
    dangerous: bool = False

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


ACTION_SPECS: tuple[ActionSpec, ...] = (
    ActionSpec("open_url", "Открыть сайт", "Откроет страницу в браузере по умолчанию.", "https://example.com", "Открытие", "↗"),
    ActionSpec("open_search", "Найти в интернете", "Откроет поисковый запрос в браузере.", "Что нужно найти", "Открытие", "⌕"),
    ActionSpec("open_app", "Открыть программу", "Запустит программу по имени или пути к EXE.", "calc, notepad или путь к EXE", "Открытие", "▣"),
    ActionSpec("open_path", "Открыть файл или папку", "Откроет существующий файл или каталог.", r"C:\Users\Имя\Documents", "Открытие", "▤"),
    ActionSpec("create_folder", "Создать папку", "Создаст папку, включая отсутствующие родительские каталоги.", r"C:\Проекты\Новая папка", "Файлы", "+"),
    ActionSpec("copy_text", "Скопировать текст", "Поместит заданный текст в буфер обмена.", "Текст для копирования", "Текст", "▧"),
    ActionSpec("type_text", "Вставить текст", "Скопирует текст и вставит его в активное поле.", "Текст для вставки", "Текст", "T"),
    ActionSpec("hotkey", "Нажать сочетание", "Нажмёт указанное сочетание клавиш.", "ctrl+shift+s", "Клавиатура", "⌘"),
    ActionSpec("key", "Нажать клавишу", "Нажмёт одну клавишу или мультимедийную кнопку.", "volumeup, enter, playpause", "Клавиатура", "⌁"),
    ActionSpec("wait", "Подождать", "Приостановит сценарий на заданное число секунд.", "2", "Сценарий", "◷", requires_value=True),
    ActionSpec("mouse_click", "Клик мышью", "Выполнит клик в записанных координатах.", "x,y,left,1", "Мышь", "●"),
    ActionSpec("mouse_scroll", "Прокрутить", "Прокрутит активное окно на заданное число шагов.", "-5", "Мышь", "↕"),
    ActionSpec("activate_window", "Активировать окно", "Найдёт окно по части заголовка и выведет его вперёд.", "Часть заголовка окна", "Окна", "□"),
    ActionSpec("wait_window", "Дождаться окна", "Будет ждать появления окна до указанного тайм-аута.", "Название окна|10", "Окна", "◫"),
    ActionSpec("minimize_window", "Свернуть окно", "Свернёт найденное окно.", "Часть заголовка окна", "Окна", "_"),
    ActionSpec("maximize_window", "Развернуть окно", "Развернёт найденное окно.", "Часть заголовка окна", "Окна", "▢"),
    ActionSpec("close_window", "Закрыть окно", "Отправит окну стандартную команду закрытия.", "Часть заголовка окна", "Окна", "×"),
    ActionSpec("require_file", "Условие: путь существует", "Остановит сценарий, если файл или папка не найдены.", r"C:\Путь\к\файлу", "Условия", "?"),
    ActionSpec("require_window", "Условие: окно открыто", "Остановит сценарий, если нужное окно не найдено.", "Часть заголовка окна", "Условия", "?"),
    ActionSpec("require_time", "Условие: время", "Продолжит сценарий только в заданном временном диапазоне.", "09:00-18:00", "Условия", "?"),
    ActionSpec("shell", "Системная команда", "Запустит команду CMD или PowerShell. Всегда требует подтверждения.", "Команда CMD", "Расширенные", ">_", dangerous=True),
)

ACTION_CATALOG = [spec.to_dict() for spec in ACTION_SPECS]
ACTION_BY_TYPE = {spec.type: spec for spec in ACTION_SPECS}
ACTION_LABELS = {spec.type: spec.label for spec in ACTION_SPECS}
ACTION_CATEGORIES = tuple(dict.fromkeys(spec.category for spec in ACTION_SPECS))
