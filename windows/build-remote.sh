#!/bin/zsh
# Baut IPA-Palette.exe auf dem Schnittraum-PC (Windows, .NET 8 SDK) und holt sie nach windows/build.
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
ssh -o BatchMode=yes $PC 'Remove-Item -Recurse -Force C:\build\ipa-palette -ErrorAction SilentlyContinue; New-Item -ItemType Directory C:\build\ipa-palette | Out-Null; cd C:\build\ipa-palette; tar xzf ..\win.tgz; & "C:\Program Files\dotnet\dotnet.exe" publish IPAPalette.csproj -c Release -o out -nologo -v q 2>&1 | Select-String -Pattern " error " | Select -Unique; if (-not (Test-Path out\IPA-Palette.exe)) { exit 1 }'
scp -q $PC:C:/build/ipa-palette/out/IPA-Palette.exe windows/build/IPA-Palette.exe
echo "fertig: windows/build/IPA-Palette.exe"
