# AURA 0.9.1

AURA is a Windows voice assistant and visual automation tool. It can launch programs, open sites, manage windows, reproduce keyboard and mouse actions, run multi-step modes, and update itself through GitHub Releases.

## What changed in 0.9.1

This release focuses on making AURA easy to use for people who do not want to learn automation concepts.

- New commands now open in a guided three-step builder.
- The builder asks what AURA should do, asks for one value, then suggests a name and voice phrase.
- Programs, files and folders can be selected through standard Windows dialogs.
- The six most common actions are presented as large, clear choices.
- Action recording is available directly from the easy builder.
- The complete editor remains available for multi-step scenarios.
- Scheduling, modes, retries and error behavior stay hidden until requested.
- The scenario test button is now called Trial run.

## Quality foundation from 0.9.0

This release keeps the product-quality improvements introduced in 0.9.0.

- Added a searchable command palette opened with `Ctrl + K`.
- Added a searchable action library grouped by purpose.
- Added live validation in the command editor.
- Invalid commands can no longer be saved silently.
- Added command context menus with run, duplicate, export, enable and delete actions.
- Added import and export for one command or the complete command collection.
- Added persistent activity history in `%APPDATA%\AURA\history.json`.
- Added non-destructive toast notifications for common operations.
- Added retry count and continue-on-error settings for every step.
- Added new safe actions: web search, create folder, and copy text.
- Added single-instance protection. Reopening AURA activates the existing window.
- Added window size and position restoration.
- Imported shell commands are forced to require confirmation.
- Refined editor spacing, disabled states, validation feedback and action selection.

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
- Settings: `Ctrl + ,`.

## Command editor

Commands and computer modes are built from visible steps. Each step can be enabled or disabled, tested separately, retried, delayed, and configured to continue after an error.

The editor validates names, voice phrases, schedules, URLs, time ranges, pauses and action values before saving. Dangerous shell steps always require explicit confirmation.

## Automation

A scenario can start:

- from a voice phrase;
- when AURA starts;
- every day at a specified time.

Supported variables include `${user}`, `${desktop}`, `${downloads}`, `${last_download}`, `${active_window}`, `${date}`, `${time}` and `${clipboard}`.

## User data

Commands, settings, history, backups and logs are stored outside the installation directory:

```text
%APPDATA%\AURA
```

This keeps user data intact when AURA is updated or reinstalled.

## Updates

AURA checks GitHub Releases shortly after startup and every 15 minutes. It downloads the installer and checksum, verifies SHA-256, and then asks for confirmation before installing.

Configure a source checkout with:

```text
CONFIGURE_UPDATES.cmd
```

For release setup, see `AUTO_UPDATE_SETUP.md`.

## Build

- `BUILD_PORTABLE.cmd` builds AURA and AURAUpdater.
- `BUILD_INSTALLER.cmd` builds the Inno Setup installer.
- Publishing a tag such as `v0.9.0` starts `.github/workflows/release.yml`.

## Voice assets

Voice feedback is generated locally with Silero and stored as WAV files in `assets\voice`. See `VOICE_LICENSE.md` before commercial distribution.
