; Compile with Inno Setup 6.3+ after scripts\build-norilight.bat release.
; PayloadDir, BuildVersion and OutputDir are supplied by the nightly workflow.
#ifndef PayloadDir
  #error PayloadDir must point to the deployed Norilight folder
#endif
#ifndef BuildVersion
  #error BuildVersion must identify this build
#endif
#ifndef OutputDir
  #error OutputDir must point to the installer output folder
#endif
; Optional overrides to trade installer size for build speed.
#ifndef InstallerCompression
  #define InstallerCompression "lzma2"
#endif
#ifndef InstallerThreads
  #define InstallerThreads "1"
#endif

[Setup]
; Keep this ID stable so subsequent nightly installers upgrade the same app.
AppId={{8B45E372-762F-4BF8-9B49-8363BD838E65}
AppName=Norilight
AppVersion={#BuildVersion}
AppPublisher=Norilight
AppPublisherURL=https://github.com/azijnwater/Norilight
AppSupportURL=https://github.com/azijnwater/Norilight/issues
AppUpdatesURL=https://github.com/azijnwater/Norilight/releases/tag/nightly
DefaultDirName={autopf}\Norilight
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
OutputDir={#OutputDir}
OutputBaseFilename=Norilight-Windows-x64-{#BuildVersion}-Setup
SetupIconFile=..\app\norilight.ico
UninstallDisplayIcon={app}\Norilight.exe
LicenseFile=..\LICENSE
Compression={#InstallerCompression}
LZMANumBlockThreads={#InstallerThreads}
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#GetFileVersion(PayloadDir + "\Norilight.exe")}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The deployed folder includes Qt, FFmpeg, SDL and the Visual C++ runtime.
; Installed builds always keep settings in the user's profile.
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Excludes: "portable.dat,portable.dat.inactive"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Norilight"; Filename: "{app}\Norilight.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Norilight"; Filename: "{app}\Norilight.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Norilight.exe"; Description: "{cm:LaunchProgram,Norilight}"; Flags: nowait postinstall skipifsilent
