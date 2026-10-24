#!/bin/zsh
# Baut IPA-Palette-Setup-<Version>.exe (Inno Setup) auf dem Schnittraum-PC und holt es nach windows/build.
# Die App liegt im Setup als Ordner (kein Einzeldatei-Entpacken beim Start → schneller, zuverlässiger).
set -euo pipefail
cd "$(dirname "$0")/.."
PC=${PC:-admin@100.78.138.86}
VERSION=$(cat VERSION)
rm -rf windows/web && mkdir -p windows/web windows/build
cp -R taskpane.css taskpane.js ipa-data.js assets fonts windows/web/
sed '/appsforoffice.microsoft.com/d' taskpane.html > windows/web/taskpane.html
sed -i '' "s#<Version>.*</Version>#<Version>$VERSION</Version>#" windows/IPAPalette.csproj
TGZ=$(mktemp -t ipa).tgz
COPYFILE_DISABLE=1 tar czf $TGZ --exclude build -C windows .
scp -q $TGZ $PC:C:/build/win.tgz
ssh -o BatchMode=yes $PC "
\$ErrorActionPreference = 'Stop'
Get-Process IPA-Palette -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -Recurse -Force C:\build\setup -ErrorAction SilentlyContinue
New-Item -ItemType Directory C:\build\setup | Out-Null
cd C:\build\setup; tar xzf ..\win.tgz
& 'C:\Program Files\dotnet\dotnet.exe' publish IPAPalette.csproj -c Release -o publish -nologo -v q -p:PublishSingleFile=false -p:DebugType=none -p:GenerateDocumentationFile=false 2>&1 | Select-String ' error ' | Select -Unique
Remove-Item publish\*.xml -ErrorAction SilentlyContinue
if (-not (Test-Path C:\build\MicrosoftEdgeWebview2Setup.exe)) { Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile C:\build\MicrosoftEdgeWebview2Setup.exe }
Copy-Item C:\build\MicrosoftEdgeWebview2Setup.exe installer/
& \"\$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe\" /Q /DAppVersion=$VERSION installer\IPA-Palette.iss
if (\$LASTEXITCODE -ne 0) { exit 1 }
"
scp -q "$PC:C:/build/setup/installer/Output/IPA-Palette-Setup-$VERSION.exe" windows/build/
echo "fertig: windows/build/IPA-Palette-Setup-$VERSION.exe"
