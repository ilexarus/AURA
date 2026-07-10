# AURA UI architecture

AURA 0.10.0 separates daily use from configuration.

## Main.qml

`Main.qml` owns:

- application-wide colors and state;
- navigation between pages;
- keyboard shortcuts;
- modal dialogs and the command editor;
- command palette and action picker;
- update, confirmation and first-run dialogs;
- the execution HUD and compact minimized HUD.

## Pages

Each page is a reusable QML component with explicit properties and signals.

- `HomePage.qml` shows assistant state, the animated orb, recent activity and quick actions.
- `CommandsPage.qml` handles search, run, edit and command context actions.
- `AutomationsPage.qml` shows modes, startup triggers and daily schedules.
- `HistoryPage.qml` shows persistent execution history.
- `SettingsPage.qml` exposes only the most common settings and links to the full settings center.

Pages do not directly open dialogs. They emit signals such as `createCommandRequested` or `openCommandRequested`, and `Main.qml` decides what to open.

## Components

- `NavigationButton.qml` implements one consistent navigation item.
- `SectionCard.qml` implements the shared panel surface.

New shared UI elements should be added to `ui/components` instead of copied between pages.

## Design rules

- Keep daily controls visible and advanced controls behind a deliberate action.
- Use one primary action per section.
- Do not display internal action identifiers or JSON values to users.
- Keep destructive actions in context menus or confirmation dialogs.
- Support Windows display scaling and the minimum window size.
- Preserve keyboard access for command creation and quick launch.
