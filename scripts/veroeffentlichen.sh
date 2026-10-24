#!/bin/zsh
# Stellt die aktuelle Version auf die eigene Download-Seite (Contabo, /opt/ipa-palette):
#   https://kph.wilckeworte.at/ipa-palette/  und  https://vs-lehrer.at/ipa-palette/
# Erwartet die fertigen Builds mac/build/IPA-Palette-<Version>.dmg und windows/build/IPA-Palette-Setup-<Version>.exe.
# Feste Dateinamen (IPA-Palette.dmg, IPA-Palette-Setup.exe) = Link bleibt bei neuen Versionen gleich.
# Das GitHub-Release (gh release create) bleibt zusätzlich nötig: die Apps prüfen dort auf Updates.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
DMG=mac/build/IPA-Palette-$VERSION.dmg
EXE=windows/build/IPA-Palette-Setup-$VERSION.exe
[[ -f $DMG && -f $EXE ]] || { echo "Builds für $VERSION fehlen"; exit 1; }
OUT=web/build/ipa-palette
rm -rf web/build && mkdir -p $OUT/palette
mb() { printf "%.0f" $(( $(stat -f %z $1) / 1048576.0 )) }
sed -e "s/{{VERSION}}/$VERSION/g" -e "s/{{MB_MAC}}/$(mb $DMG)/g" -e "s/{{MB_WIN}}/$(mb $EXE)/g" web/download.html > $OUT/index.html
cp $DMG $OUT/IPA-Palette.dmg
cp $EXE $OUT/IPA-Palette-Setup.exe
cp anleitung.pdf datenschutz.html $OUT/
cp assets/icon-64.png $OUT/
magick store/screenshot-1.png -resize 1600x900 -quality 84 $OUT/screenshot.jpg
# Browser-Palette ohne office.js (keine Anfrage an Microsoft, Klick kopiert)
cp -R taskpane.css taskpane.js ipa-data.js assets fonts $OUT/palette/
sed '/appsforoffice.microsoft.com/d' taskpane.html > $OUT/palette/index.html
echo "{\"version\": \"$VERSION\"}" > $OUT/version.json
ssh contabo 'mkdir -p /opt/ipa-palette/www'
rsync -rlt --delete --chmod=Da+rx,Fa+r web/build/ contabo:/opt/ipa-palette/www/
rsync -t server/docker-compose.yml contabo:/opt/ipa-palette/docker-compose.yml
ssh contabo 'cd /opt/ipa-palette && docker compose up -d --quiet-pull 2>&1 | grep -v "Running\|up-to-date" || true'
echo "online: https://kph.wilckeworte.at/ipa-palette/ · https://vs-lehrer.at/ipa-palette/ (Version $VERSION)"
