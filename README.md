# IPA-Palette

Word-Add-in (Office.js, Seitenleiste) zum Einfügen von Symbolen des Internationalen Phonetischen Alphabets. Ein Klick fügt das Zeichen an der Cursorposition ein. Gedacht für Word für Mac (Microsoft 365), läuft auch in Word im Web und unter Windows.

Funktionen: Symbolgruppen (Häufig, Konsonanten- und Vokaltabelle, Affrikaten, Diakritika, Suprasegmentalia, Töne), Suche (Name, Symbol, X-SAMPA, U+-Nummer), Zuletzt verwendet, X-SAMPA-Schnelleingabe mit Vorschau, Klammern `[ ]`, `/ /`, `⟨ ⟩`, wählbare Schriftart, heller und dunkler Modus. Im normalen Browser kopiert ein Klick das Symbol in die Zwischenablage.

Es sind nur statische Dateien, kein Build-Schritt, keine Abhängigkeiten.

## Apps für Mac und Windows (jedes Programm)

Neben dem Word-Add-in gibt es die Palette als eigene App. Sie schwebt über allen Fenstern und tippt das Zeichen ins zuletzt aktive Programm, also auch in WordCraft, Pages, LibreOffice, Mail oder den Browser. Klammern umschließen markierten Text.

- **Mac:** `IPA-Palette-x.y.z.dmg` aus den [Releases](https://github.com/jeremiaswilcke/ipa-palette/releases/latest) öffnen, App in „Programme“ ziehen, starten. Beim ersten Start **Bedienungshilfen** erlauben (Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen). Ein-/ausblenden mit **⌃⌥I** oder über „ə“ in der Menüleiste. Signiert und notarisiert.
- **Windows:** `IPA-Palette.exe` aus den Releases laden und starten, keine Installation nötig. Ein-/ausblenden mit **Strg+Alt+I** oder über das Symbol im Infobereich. Die Datei ist nicht signiert: SmartScreen fragt beim ersten Start, dann **Weitere Informationen → Trotzdem ausführen**.

Bauen: `mac/build.sh` (signiert + notarisiert, `--ohne-notarisierung` zum Testen), `windows/build-remote.sh` (baut per SSH auf einem Windows-PC mit .NET 8 SDK). Version in `VERSION`.

## Hosting (GitHub Pages)

1. Neues **öffentliches** Repository `ipa-palette` anlegen.
2. **Add file → Upload files**: alle Dateien dieses Ordners hochladen (mit `assets/` und `fonts/`), **Commit changes**.
3. **Settings → Pages → Deploy from a branch**, Branch `main`, Ordner `/ (root)`, **Save**.
4. Nach etwa einer Minute `https://BENUTZERNAME.github.io/ipa-palette/` öffnen. Die Seite `index.html` erzeugt dort die passende `manifest.xml` zum Herunterladen.

## Sideloading

**Word für Mac:** `manifest.xml` in den Ordner `~/Library/Containers/com.microsoft.Word/Data/Documents/wef/` legen (Ordner `wef` ggf. anlegen), Word neu starten, dann **Einfügen → Add-ins → Meine Add-ins** (Entwickler-Add-ins) → IPA-Palette. Danach erscheint der Button „IPA-Palette“ im Start-Tab.

**Word im Web:** **Einfügen → Add-ins → Mein Add-In hochladen** → `manifest.xml`.

**Updates:** Word speichert Add-in-Seiten zwischen. Nach Änderungen den Inhalt von `~/Library/Containers/com.Microsoft.OsfWebHost/Data/` löschen und Word neu starten.

## Dateien

| Datei | Inhalt |
| --- | --- |
| `index.html` | Einrichtungsseite, erzeugt `manifest.xml` im Browser |
| `taskpane.html`, `taskpane.css`, `taskpane.js` | Oberfläche der Seitenleiste |
| `ipa-data.js` | Symboldaten, deutsche Namen, X-SAMPA-Tabelle, Konverter, Suche |
| `commands.html` | leere FunctionFile-Seite (vom Manifest verlangt) |
| `manifest.template.xml` | Referenzkopie des Manifests mit Platzhaltern `{{BASE_URL}}` und `{{APP_DOMAIN}}` |
| `assets/` | Icons (16, 32, 64, 80, 128 px) |
| `fonts/` | Teilmenge der Schrift Charis (SIL), umbenannt in „IPA Palette Serif“, mit `OFL.txt` |

Die Vorlage `manifest.template.xml` ist zusätzlich unverändert in `index.html` eingebettet (`<script id="manifest-template">`). Wird eine der beiden Stellen geändert, muss die andere angepasst werden.

## Hinweise

- Für die beste Darstellung in Word Charis SIL oder Doulos SIL installieren (software.sil.org) und in der Palette unter **Schriftart** wählen.
- Der helle/dunkle Modus folgt dem System (`prefers-color-scheme`), nicht dem Office-Design.
- Voraussetzung: Word mit WebView (Microsoft 365). Der alte Internet-Explorer-Modus älterer Windows-Versionen wird nicht unterstützt.

## Lizenz und Quellen

Die Anzeigeschrift ist eine Teilmenge von Charis, © SIL Global, SIL Open Font License 1.1 (`fonts/OFL.txt`). Wegen der reservierten Schriftnamen „Charis“ und „SIL“ trägt die Teilmenge den Namen „IPA Palette Serif“. IPA-Tabelle: International Phonetic Association (2020), CC BY-SA 3.0. X-SAMPA: Wells (1995), UCL.
