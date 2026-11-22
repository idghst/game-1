; Hollow Vigil Windows 설치 파일 (Inno Setup 6)
; 빌드: ISCC /DAppVersion=<project.godot의 config/version> installer\HollowVigil.iss
; 입력: build\windows (forge build windows 결과), 출력: build\installer\HollowVigil-Setup-<버전>.exe
; 사용자 단위 설치(관리자 권한 불필요). 저장 파일(%APPDATA%\Godot\app_userdata\Hollow Vigil)은 설치 폴더 밖이라 제거해도 남는다.

#ifndef AppVersion
  #error AppVersion을 /DAppVersion=x.y.z 로 넘겨야 합니다
#endif

[Setup]
; AppId는 바꾸지 않는다(바꾸면 업그레이드·제거가 다른 앱으로 인식된다)
AppId={{0604C6E0-66C6-4C2E-B88A-0E3FF58A7B74}
AppName=Hollow Vigil
AppVersion={#AppVersion}
AppVerName=Hollow Vigil {#AppVersion}
AppPublisher=idghst
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\Hollow Vigil
DefaultGroupName=Hollow Vigil
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=HollowVigil-Setup-{#AppVersion}
SetupIconFile=..\assets\logo\icon.ico
UninstallDisplayIcon={app}\HollowVigil.exe
UninstallDisplayName=Hollow Vigil
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=auto

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Hollow Vigil"; Filename: "{app}\HollowVigil.exe"
Name: "{group}\{cm:UninstallProgram,Hollow Vigil}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Hollow Vigil"; Filename: "{app}\HollowVigil.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\HollowVigil.exe"; Description: "{cm:LaunchProgram,Hollow Vigil}"; Flags: nowait postinstall skipifsilent
