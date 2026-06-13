# Changelog

## 0.8.3

- Removed the Favorite switch from the command editor.
- Removed the favorite modes panel from the main screen.
- Removed favorite persistence from new commands and templates.
- Kept backward compatibility with old command files containing the legacy `favorite` field.
- Expanded the recent activity panel into the freed space.

## 0.7.5

- Removed the redundant “Начать говорить” button from the main assistant screen.
- Updated the helper text to focus on wake-phrase activation.
- Manual recognition remains available through Ctrl + Shift + Space.

## 0.7.4

- Removed the redundant AURA branding block from the top of the sidebar.
- Removed the duplicate assistant-mode card from the sidebar.
- Removed the persistent status strip from the bottom of the sidebar.
- Rebalanced sidebar spacing so commands receive more usable vertical space.

## 0.7.2

- Перенесена кнопка закрытия настроек в настоящий верхний правый угол окна.
- Аналогично исправлена кнопка закрытия редактора команд.
- Кнопки больше не зависят от ширины заголовка и масштабирования Windows.

## 0.7.0

- Added a five-step first-run setup wizard.
- Added a settings center without changing the main AURA visual style.
- Added microphone selection and a live microphone level test.
- Added editable wake phrase and voice-feedback settings.
- Added per-user Windows autostart controls.
- Added stable and beta update channels.
- Added local backups and restore for commands and settings.
- Added one-click diagnostics for the microphone, wake model, voice pack, hotkeys, updates, connectivity and command storage.
- Added minimized startup support for Windows autostart.
- Fixed manual listening so silence or unclear audio no longer plays the unknown-command response.
- Preserved the 15-minute update check interval and all 0.6.x editor fixes.

## 0.6.3

- Fixed the manual “Начать говорить” mode treating silence as an unknown command.
- Added a short microphone handoff delay when switching from wake listening.

## 0.6.2

- Fixed persistence and visual state of the per-step “Включён” checkbox.
- Fixed individual step testing for enabled and disabled steps.

## 0.6.1

- Fixed individual step testing and reduced the update interval to 15 minutes.

## 0.6.0

- Added scenario testing, action-card controls, search, recording overlay and improved history.
