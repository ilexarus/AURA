# Changelog

## 0.10.0

- Rebuilt the main interface around five dedicated pages.
- Added Home, Commands, Automations, History and Settings navigation.
- Added a simplified Home page focused on voice use and command creation.
- Added a searchable command-management page with human-readable cards.
- Added a dedicated page for modes, startup scenarios and scheduled automations.
- Added a full persistent history page.
- Added a simple settings page for the most common controls.
- Added a compact always-on-top assistant panel for minimized use.
- Split the QML interface into reusable components and pages.
- Preserved the easy builder, advanced editor, command palette and old user data.

## 0.9.1

- Added a guided three-step command builder as the default creation flow.
- Added one-click choices for the six most common command types.
- Added automatic command names and voice phrase suggestions.
- Added native program, file and folder pickers.
- Added a direct action-recording path from the easy builder.
- Kept the complete editor available through an Advanced editor button.
- Hid automation controls until the user explicitly opens them.
- Hid retry and continue-on-error controls behind per-step Advanced options.
- Renamed scenario testing to a clearer Trial run action.
- Simplified labels and helper text throughout command creation.

## 0.9.0

- Added a searchable command palette with keyboard navigation.
- Added a searchable, categorized action library.
- Added live command and step validation with visible error messages.
- Prevented saving invalid command drafts.
- Added command context menus, duplication and per-command export.
- Added full command import and export.
- Added persistent local activity history and history clearing.
- Added toast notifications for common operations.
- Added retry and continue-on-error controls for every action step.
- Added safe actions for web search, folder creation and clipboard copying.
- Added single-instance protection and existing-window activation.
- Added window geometry persistence.
- Hardened imported shell commands by forcing confirmation.
- Refined editor layout, action cards, disabled states and keyboard shortcuts.
- Added validation and persistence regression tests.

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
