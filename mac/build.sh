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
# Installations-DMG: Hintergrund mit Pfeil, App links, „Programme“ rechts
STAGE=$OUT/dmg && mkdir -p $STAGE/.background && cp -R $APP $STAGE/ && ln -s /Applications $STAGE/Programme
cp mac/dmg/background.tiff $STAGE/.background/background.tiff
RW=$OUT/rw.dmg
hdiutil create -volname "IPA-Palette" -srcfolder $STAGE -ov -format UDRW -fs HFS+ $RW >/dev/null
MNT=$(hdiutil attach -readwrite -noverify -noautoopen $RW | awk -F'\t' '/\/Volumes\//{print $NF}')
osascript <<OSA
tell application "Finder"
  tell disk "IPA-Palette"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 548}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "IPA-Palette.app" of container window to {170, 190}
    set position of item "Programme" of container window to {470, 190}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
SetFile -a C "$MNT" 2>/dev/null || true
sync; hdiutil detach "$MNT" -quiet
hdiutil convert $RW -format UDZO -imagekey zlib-level=9 -ov -o $DMG >/dev/null
rm -f $RW
codesign --sign "$IDENTITY" --timestamp $DMG
if [[ "${1:-}" != "--ohne-notarisierung" ]]; then
  xcrun notarytool submit $DMG --keychain-profile $PROFILE --wait
  xcrun stapler staple $DMG
fi
echo "fertig: $DMG"
