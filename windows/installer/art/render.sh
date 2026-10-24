#!/bin/zsh
# Rendert die Setup-Bilder aus art.html (Chrome headless) in den DPI-Stufen von Inno Setup.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot() {   # shot <query> <breite> <höhe> <datei>
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size=$2,$3 --screenshot="$PWD/$4" "file://$PWD/art.html?$1" >/dev/null 2>&1
}
# großes Bild links (Willkommen/Fertig): 100 %, 125 %, 150 %, 175 %, 200 %, 250 %
# Chrome rendert unter ~500 px Breite falsch → groß rendern, dann verkleinern
shot side 820 1570 side-gross.png
for s in 100 125 150 175 200 250; do magick side-gross.png -resize $((164*s/100))x$((314*s/100))! side-$s.png; done
rm side-gross.png
# Hintergrund aller Seiten, hell und dunkel
shot back 1240 940 back-gross.png
shot back\&dark 1240 940 back-dark-gross.png
for s in 100 150 200; do
  magick back-gross.png -resize $((620*s/100))x$((470*s/100))! back-$s.png
  magick back-dark-gross.png -resize $((620*s/100))x$((470*s/100))! back-dark-$s.png
done
rm back-gross.png back-dark-gross.png
# kleines Bild oben rechts = App-Symbol
for s in 100 125 150 200 250; do
  n=$((58*s/100)); magick ../../../assets/icon-128.png -resize ${n}x${n} small-$s.png
done
ls
