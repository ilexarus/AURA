# AURA 0.6.0

A Windows voice assistant with a minimal interface, local wake phrase activation, visual command builder, action recording, and automatic updates.

## Main improvements in 0.6.0

- Search commands by name, voice phrase, or action.
- Test one action directly from its card.
- Test the complete unsaved scenario before saving.
- Duplicate, disable, and reorder actions.
- See a clear green or red result after testing a step.
- Use the compact recording panel while AURA records mouse and keyboard actions.
- Read a more useful recent activity list with time and status.
- Hear the corrected response: `Я не нашёл такую команду`.

The current colors, dark theme, voice sphere, and overall visual identity are preserved.

## Run from source

1. Extract the project to a normal folder, for example `C:\AURA`.
2. Run `START_AURA.cmd`.
3. Wait for the first dependency installation to finish.
4. To reset a broken environment, run `RESET_AND_START.cmd`.

Python 3.11, 3.12, or 3.13 can be used for development.

## Voice activation

AURA waits locally for the phrase `Аура` using Vosk. The wake phrase is not sent to an online service.

After activation, the command is recognized through the configured speech pipeline. You can say the phrase and command together, for example:

`Аура, открой браузер`

Hotkey: `Ctrl + Shift + Space`.

Emergency stop: `Ctrl + Shift + F12`.

## Voice responses

Generate the local Silero voice pack with:

`GENERATE_SILERO_VOICE.cmd`

For a profile intended for commercial use, use:

`GENERATE_SILERO_VOICE_MIT.cmd`

Review `VOICE_LICENSE.md` before distribution.

## User data

Commands and settings are stored outside the program folder:

`%APPDATA%\AURA`

This allows updates to replace application files without deleting user commands.

## Build

Portable build:

`BUILD_PORTABLE.cmd`

Windows installer:

`BUILD_INSTALLER.cmd`

The release workflow in `.github/workflows/release.yml` builds and attaches the installer to a GitHub Release created from a tag such as `v0.6.0`.

## Automatic updates

Installed builds check the latest stable GitHub Release, download the matching installer and SHA-256 file, verify the checksum, and offer installation. Source mode launched through `START_AURA.cmd` does not silently replace itself.

## Safety

System commands require confirmation. Scenario testing refuses to run system command steps. Review imported commands before running them.
