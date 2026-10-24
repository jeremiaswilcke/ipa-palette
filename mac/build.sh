#!/bin/zsh
# Baut IPA-Palette.app (Universal), signiert mit Developer ID, notarisiert und packt eine DMG.
# Aufruf: mac/build.sh [--ohne-notarisierung]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
OUT=mac/build
APP=$OUT/IPA-Palette.app
IDENTITY="Developer ID Application: Jeremias Christof Hermann Franz Joseph Wilcke (7MN88MYAVL)"
PROFILE=AUF1

rm -rf $OUT && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources/web
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 mac/IPAPalette.swift -o $OUT/ipa-$arch
done
lipo -create $OUT/ipa-arm64 $OUT/ipa-x86_64 -output $APP/Contents/MacOS/IPA-Palette
sed "s/VERSION/$VERSION/g" mac/Info.plist > $APP/Contents/Info.plist
# Web-Oberfläche ohne office.js (offline, keine Netzanfrage)
cp -R taskpane.css taskpane.js ipa-data.js assets fonts $APP/Contents/Resources/web/
sed '/appsforoffice.microsoft.com/d' taskpane.html > $APP/Contents/Resources/web/taskpane.html
# Icon aus assets/icon-128.png
ICONSET=$OUT/AppIcon.iconset && mkdir -p $ICONSET
for s in 16 32 64 128 256 512; do
  sips -z $s $s assets/icon-128.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) assets/icon-128.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o $APP/Contents/Resources/AppIcon.icns

codesign --force --options runtime --timestamp --sign "$IDENTITY" $APP
codesign --verify --strict $APP

DMG=$OUT/IPA-Palette-$VERSION.dmg
STAGE=$OUT/dmg && mkdir -p $STAGE && cp -R $APP $STAGE/ && ln -s /Applications $STAGE/Programme
hdiutil create -volname "IPA-Palette" -srcfolder $STAGE -ov -format UDZO $DMG >/dev/null
codesign --sign "$IDENTITY" --timestamp $DMG
if [[ "${1:-}" != "--ohne-notarisierung" ]]; then
  xcrun notarytool submit $DMG --keychain-profile $PROFILE --wait
  xcrun stapler staple $DMG
fi
echo "fertig: $DMG"
