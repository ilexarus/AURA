# Automatic update setup

AURA checks the latest stable GitHub Release and expects two attached files:

- `AURA-Setup-X.Y.Z.exe`
- `AURA-Setup-X.Y.Z.exe.sha256`

## First repository setup

1. Upload the project contents to the repository root.
2. Keep `.github/workflows/release.yml` in place.
3. Keep only one release workflow file.
4. Make the repository public, or adapt the updater for authenticated access.

## Publish a version

Commit and push the source changes to `main`, then create a new release tag:

```text
v0.6.0
```

Target the `main` branch and publish the release as `Latest`.

The GitHub Actions workflow will:

1. Set the application version from the tag.
2. Configure the current GitHub repository for updates.
3. Run tests.
4. Generate the local voice pack.
5. Build AURA and AURAUpdater.
6. Build the Inno Setup installer.
7. Generate SHA-256.
8. Attach both files to the release.

## Publish later updates

Use a new tag every time, for example:

```text
v0.6.1
v0.6.2
v0.7.0
```

Do not reuse an old tag or replace an already distributed installer under the same version.

## User data

User commands and settings are stored in `%APPDATA%\AURA`, outside the installation directory. Installing a new version should not remove them.

## Important updater note

Users must install at least one build that contains the corrected updater. Source mode started with `START_AURA.cmd` can check updates, but automatic replacement is intended for the installed build.
