; Inno Setup 6 script for 开听 (Windows desktop).
; Compiled by tool/release.dart via ISCC with /DMyAppVersion=x.y.z etc.
;
; Install Inno Setup 6: https://jrsoftware.org/isinfo.php
;   winget install --id JRSoftware.InnoSetup -e

#ifndef MyAppName
  #define MyAppName "开听"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "com.kaiting"
#endif
#ifndef MyAppURL
  #define MyAppURL "https://github.com/robeshell/kaiting"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "kaiting.exe"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "kaiting-" + MyAppVersion + "-windows-setup"
#endif

[Setup]
; Stable product id — do not change once users install from this script.
AppId={{A7F3C2E1-8B4D-4F6A-9E2C-1D5B8A0F3E7C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Modern 64-bit only (Flutter Windows release is x64)
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
LicenseFile=
InfoBeforeFile=
; Avoid "close applications" noise for our single-exe app
CloseApplications=force
RestartApplications=no

[Languages]
; Default English UI. Additional language packs can be added when present under
; Inno Setup's Languages\ folder (e.g. ChineseSimplified.isl from the full
; translations pack).
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Entire Flutter Release tree (exe, dlls, data/)
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
