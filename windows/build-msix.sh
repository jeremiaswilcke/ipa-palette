#!/bin/zsh
# Baut das MSIX-Paket für den Microsoft Store auf dem Schnittraum-PC.
# Aufruf: windows/build-msix.sh [--testsignieren]   (Testsignatur nur zum lokalen Installieren; der Store signiert selbst)
set -euo pipefail
cd "$(dirname "$0")/.."
PC=${PC:-admin@100.78.138.86}
source windows/msix/store.env
VERSION="$(cat VERSION).0"
windows/build-remote.sh

A=$(mktemp -d)/Assets && mkdir -p $A
sips -z 44 44 assets/icon-128.png --out $A/Square44x44Logo.png >/dev/null
sips -z 50 50 assets/icon-128.png --out $A/StoreLogo.png >/dev/null
sips -p 150 150 assets/icon-128.png --out $A/Square150x150Logo.png >/dev/null
sips -p 150 310 assets/icon-128.png --out $A/Wide310x150Logo.png >/dev/null
sed -e "s#{{IDENTITY_NAME}}#$IDENTITY_NAME#" -e "s#{{PUBLISHER}}#$PUBLISHER#" \
    -e "s#{{PUBLISHER_DISPLAY}}#$PUBLISHER_DISPLAY#" -e "s#{{VERSION}}#$VERSION#" \
    windows/msix/AppxManifest.template.xml > $A/../AppxManifest.xml
TGZ=$(mktemp -t msix).tgz
COPYFILE_DISABLE=1 tar czf $TGZ -C $A/.. AppxManifest.xml Assets
scp -q $TGZ $PC:C:/build/msix.tgz
OUT="IPA-Palette_${VERSION}_x64.msix"
ssh -o BatchMode=yes $PC "
\$ErrorActionPreference = 'Stop'
\$kit = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64'
Remove-Item -Recurse -Force C:\build\msix -ErrorAction SilentlyContinue
New-Item -ItemType Directory C:\build\msix\pkg | Out-Null
cd C:\build\msix\pkg; tar xzf ..\..\msix.tgz
Copy-Item C:\build\ipa-palette\out\IPA-Palette.exe .
& \"\$kit\makeappx.exe\" pack /d C:\build\msix\pkg /p C:\build\msix\\$OUT /o | Select -Last 1
if ('${1:-}' -eq '--testsignieren') {
  \$cert = Get-ChildItem Cert:\CurrentUser\My | ? Subject -eq '$PUBLISHER' | Select -First 1
  if (-not \$cert) { \$cert = New-SelfSignedCertificate -Type Custom -Subject '$PUBLISHER' -KeyUsage DigitalSignature -FriendlyName 'IPA-Palette Test' -CertStoreLocation Cert:\CurrentUser\My -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3','2.5.29.19={text}') }
  Export-Certificate -Cert \$cert -FilePath C:\build\msix\test.cer | Out-Null
  Import-Certificate -FilePath C:\build\msix\test.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
  & \"\$kit\signtool.exe\" sign /fd SHA256 /sha1 \$cert.Thumbprint C:\build\msix\\$OUT | Select -Last 1
}
"
mkdir -p windows/build
scp -q "$PC:C:/build/msix/$OUT" windows/build/
echo "fertig: windows/build/$OUT"
