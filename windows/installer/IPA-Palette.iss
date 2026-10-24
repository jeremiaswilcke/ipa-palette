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
; Eigenes Aussehen (Inno Setup 6.7+): Bilder aus art/ (render.sh), folgt hellem/dunklem Windows-Modus
WizardStyle=modern dynamic windows11 hidebevels
WizardImageFile=art\side-100.png,art\side-125.png,art\side-150.png,art\side-175.png,art\side-200.png,art\side-250.png
WizardSmallImageFile=art\small-100.png,art\small-125.png,art\small-150.png,art\small-200.png,art\small-250.png
WizardImageFileDynamicDark=art\side-100.png,art\side-125.png,art\side-150.png,art\side-175.png,art\side-200.png,art\side-250.png
WizardSmallImageFileDynamicDark=art\small-100.png,art\small-125.png,art\small-150.png,art\small-200.png,art\small-250.png
WizardBackImageFile=art\back-100.png,art\back-150.png,art\back-200.png
WizardBackImageFileDynamicDark=art\back-dark-100.png,art\back-dark-150.png,art\back-dark-200.png
WizardBackColor=#f4f8f9
WizardBackColorDynamicDark=#1c2022
DisableWelcomePage=no
DisableReadyPage=yes
Compression=lzma2/max
SolidCompression=yes
AppMutex=Askalon.IPAPalette
CloseApplications=yes

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Messages]
de.WelcomeLabel1=IPA-Palette installieren
de.WelcomeLabel2=Alle Zeichen des Internationalen Phonetischen Alphabets in einem schwebenden Fenster. Ein Klick tippt das Symbol dort ein, wo der Cursor steht – in Word, LibreOffice, im Browser und in jedem anderen Programm.%n%nDie Installation braucht keine Administratorrechte und dauert nur einen Moment.
de.SelectTasksDesc=Zwei kleine Einstellungen, beide später änderbar.
de.SelectTasksLabel2=Wie soll die IPA-Palette starten?
de.FinishedHeadingLabel=Fertig – viel Freude beim Transkribieren!
de.FinishedLabelNoIcons=Die IPA-Palette ist installiert.%n%nIn das gewünschte Programm klicken, dann ein Symbol in der Palette wählen. Strg+Alt+I blendet die Palette ein und aus. Neue Versionen meldet die App von selbst.
de.FinishedLabel=Die IPA-Palette ist installiert.%n%nIn das gewünschte Programm klicken, dann ein Symbol in der Palette wählen. Strg+Alt+I blendet die Palette ein und aus. Neue Versionen meldet die App von selbst.
de.ClickFinish=
de.ClickNext=

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
; Update aus der App heraus (/SILENT /neustart=1): neue Version gleich wieder starten
Filename: "{app}\IPA-Palette.exe"; Flags: nowait; Check: IsUpdateRestart

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM IPA-Palette.exe /F"; Flags: runhidden; RunOnceId: "StopApp"

[Code]
function IsUpdateRestart(): Boolean;
begin
  Result := ExpandConstant('{param:neustart|0}') = '1';
end;

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
