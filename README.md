# AURA 0.10.0

AURA is a Windows voice assistant and visual automation tool. It launches programs, opens sites and files, controls windows, reproduces keyboard and mouse actions, runs multi-step modes, schedules automations and updates itself through GitHub Releases.

## What changed in 0.10.0

This release rebuilds the daily interface around simple, separate pages instead of one overloaded screen.

- Added a clear five-section navigation: Home, Commands, Automations, History and Settings.
- Rebuilt the Home page around one primary action: speak to AURA or create a command.
- Added a dedicated Commands page with human-readable cards, search, run and edit actions.
- Added a dedicated Automations page for modes, startup scenarios and schedules.
- Added a full History page with persistent results and errors.
- Added a simple Settings page with wake phrase, voice feedback, microphone testing, updates and autostart.
- Kept the complete settings center available through the All settings button.
- Added a compact always-on-top assistant panel that appears when the main window is hidden and AURA is listening or executing.
- Split the interface into reusable QML components and page files.
- Preserved the guided command builder, advanced editor, action library, command palette, updater and existing user data.

## Interface structure

```text
ui/
    Main.qml
    components/
        NavigationButton.qml
        SectionCard.qml
    pages/
        HomePage.qml
        CommandsPage.qml
        AutomationsPage.qml
        HistoryPage.qml
        SettingsPage.qml
```

The main window now coordinates navigation and shared dialogs. Individual pages own their layout and emit simple signals back to `Main.qml`. This makes future visual changes much safer than editing one very large screen.

## Run from source

1. Install Python 3.12 or 3.13 on Windows.
2. Extract the project to a writable folder, for example `C:\AURA`.
3. Run `START_AURA.cmd`.
4. If the environment becomes corrupted, run `RESET_AND_START.cmd`.

The first start creates an isolated `.venv` and installs the required components.

## Main controls

- Wake phrase: `Аура`.
- Manual listening: `Ctrl + Shift + Space`.
- Emergency scenario stop: `Ctrl + Shift + F12`.
- Command palette: `Ctrl + K`.
- New command: `Ctrl + N`.
- Settings page: `Ctrl + ,`.

## Creating commands

The default builder uses three simple steps:

1. Choose what AURA should do.
2. Select a program, site, file, folder or action value.
3. Confirm the suggested name and voice phrase.

The full editor remains available for multi-step scenarios, schedules, conditions, retries and error handling.

## User data

Commands, settings, history, backups and logs are stored outside the installation directory:

```text
%APPDATA%\AURA
```

Existing data from earlier versions is preserved.

## Updates

AURA checks GitHub Releases shortly after startup and every 15 minutes. It downloads the installer and checksum, verifies SHA-256, then asks before installing.

Configure a source checkout with:

```text
CONFIGURE_UPDATES.cmd
```

For release setup, see `AUTO_UPDATE_SETUP.md`.

## Build

- `BUILD_PORTABLE.cmd` builds AURA and AURAUpdater.
- `BUILD_INSTALLER.cmd` builds the Inno Setup installer.
- Publishing a tag such as `v0.10.0` starts `.github/workflows/release.yml`.

## Voice assets

Voice feedback is generated locally with Silero and stored as WAV files in `assets\voice`. See `VOICE_LICENSE.md` before commercial distribution.
