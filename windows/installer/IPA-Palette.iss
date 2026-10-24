; Setup für die IPA-Palette (Inno Setup 6). Installiert pro Benutzer, ohne Administratorrechte.
; Baut windows/build-setup.sh auf dem Schnittraum-PC; Version kommt per /DAppVersion=…
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{7C2F4A51-8E3B-4C6D-9A1E-IPAPALETTE01}
AppName=IPA-Palette
AppVersion={#AppVersion}
AppVerName=IPA-Palette {#AppVersion}
AppPublisher=Jeremias Wilcke
AppPublisherURL=https://jeremiaswilcke.github.io/ipa-palette/
AppSupportURL=https://github.com/jeremiaswilcke/ipa-palette/issues
DefaultDirName={localappdata}\Programs\IPA-Palette
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=IPA-Palette-Setup-{#AppVersion}
SetupIconFile=..\app.ico
UninstallDisplayIcon={app}\IPA-Palette.exe
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
AppMutex=Askalon.IPAPalette
CloseApplications=yes

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "Verknüpfung auf dem Desktop"; Flags: unchecked
Name: "autostart"; Description: "Mit Windows starten (im Infobereich, Strg+Alt+I zeigt die Palette)"

[Files]
Source: "..\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "MicrosoftEdgeWebview2Setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: NeedsWebView2

[Icons]
Name: "{userprograms}\IPA-Palette"; Filename: "{app}\IPA-Palette.exe"
Name: "{userdesktop}\IPA-Palette"; Filename: "{app}\IPA-Palette.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "IPA-Palette"; ValueData: """{app}\IPA-Palette.exe"" --hidden"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; StatusMsg: "Microsoft Edge WebView2 wird installiert …"; Check: NeedsWebView2
Filename: "{app}\IPA-Palette.exe"; Description: "IPA-Palette jetzt starten"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM IPA-Palette.exe /F"; Flags: runhidden; RunOnceId: "StopApp"

[Code]
// WebView2 ist auf Windows 11 immer da, auf älteren Windows-10-Rechnern nicht zwingend.
function WebView2Version(Root: Integer; Key: String): String;
begin
  if not RegQueryStringValue(Root, Key, 'pv', Result) then Result := '';
end;

function NeedsWebView2(): Boolean;
var v: String;
begin
  v := WebView2Version(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}');
  if (v = '') or (v = '0.0.0.0') then
    v := WebView2Version(HKCU, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}');
  Result := (v = '') or (v = '0.0.0.0');
end;
