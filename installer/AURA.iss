#ifndef MyAppVersion
#define MyAppVersion "0.5.8"
#endif
#define MyAppName "AURA"
#define MyAppPublisher "AURA"
#define MyAppExeName "AURA.exe"

[Setup]
AppId={{2C5C49F9-1E84-4F95-8C33-20C06590C20A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\AURA
DefaultGroupName=AURA
DisableProgramGroupPage=yes
OutputDir=..\dist\installer
OutputBaseFilename=AURA-Setup-{#MyAppVersion}
SetupIconFile=..\assets\icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName=AURA
CloseApplications=force
RestartApplications=no
SetupLogging=yes
UsePreviousAppDir=yes

[Files]
Source: "..\dist\AURA\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\AURA"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\AURA"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
Name: "startup"; Description: "Start AURA with Windows"; GroupDescription: "Startup:"; Flags: unchecked

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AURA"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch AURA"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
