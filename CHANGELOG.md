# Changelog

## 0.6.2

- Fixed persistence and visual state of the per-step “Включён” checkbox.
- Removed the QML role-name collision between a step's enabled state and `Item.enabled`.
- Fixed the “Проверить этот шаг” button so it remains clickable for disabled steps.
- Individual step testing now relies on the backend to pause wake-word listening safely.

## 0.5.7

- Fixed the Windows-only double-click recorder unit test.
- Removed the duplicate GitHub Actions workflow from the source package.
- Added release concurrency protection.
- Tests now run before the large PyTorch download and voice generation.

# AURA 0.3.1

- Полностью сохранён прежний внешний вид основного окна.
- В прежний редактор добавлены многошаговые сценарии без изменения общего стиля.
- Добавлены паузы между действиями.
- Выполнение перенесено в отдельный поток, поэтому интерфейс не зависает.
- Старые команды AURA 0.1 и 0.2 автоматически преобразуются в новый формат.
- Системные команды всегда требуют подтверждения.
- Добавлен значок в системный трей.
- Добавлена ротация журнала приложения.
- Повреждённый файл команд сохраняется в резервную копию.
- CMD-файлы используют ASCII и CRLF.
- Добавлены portable-сборка и установщик Inno Setup.
