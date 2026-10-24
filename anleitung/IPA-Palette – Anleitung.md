# IPA-Palette für Word – Anleitung

Die IPA-Palette ist eine Seitenleiste in Word: Ein Klick auf ein Symbol fügt es an der Cursorposition ein. Mit Suche (z. B. „sch“ oder „ʃ“), X-SAMPA-Schnelleingabe und Klammern `[ ]`, `/ /`, `⟨ ⟩`. Kostenlos, ohne Konto, die Uni-Lizenz von Microsoft 365 reicht.

> **Merksatz:** Für das Word-Add-in braucht ihr zuerst die Datei **manifest.xml**. Startseite öffnen: **jeremiaswilcke.github.io/ipa-palette** → Knopf **„manifest.xml herunterladen“**. Nicht den direkten Link auf die Datei nehmen, den zeigt der Browser nur an.

| System | Weg | Aufwand |
|---|---|---|
| Mac oder Windows, jedes Programm | App herunterladen und starten | 1 Minute |
| Mac, nur Word | Datei in einen Word-Ordner legen | 2 Minuten |
| Windows, nur Word | Ordner freigeben und in Word eintragen | 5 Minuten |
| Linux (und alle ohne Word) | Word im Browser oder Palette im Browser | 1 Minute |

## Am einfachsten: die App (für jedes Programm)

Die App schwebt über allen Fenstern und tippt das Zeichen dort, wo euer Cursor steht: in Word, WordCraft, Pages, LibreOffice, im Browser. Markiert ihr ein Wort und klickt **[ ]**, wird es eingeklammert. Download: **github.com/jeremiaswilcke/ipa-palette/releases/latest**

**Mac:** **IPA-Palette-….dmg** öffnen, die App auf „Programme“ ziehen und aus „Programme“ starten. Beim ersten Start fragt macOS nach **Bedienungshilfen** → Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → **IPA-Palette** einschalten. Ein- und ausblenden mit **⌃⌥I** oder über **ə** in der Menüleiste.

**Windows:** **IPA-Palette-Setup-….exe** herunterladen und ausführen, Administratorrechte braucht es nicht. Warnt Windows („Der Computer wurde durch Windows geschützt“): **Weitere Informationen → Trotzdem ausführen**. Danach im Startmenü **IPA-Palette** öffnen. Ein- und ausblenden mit **Strg+Alt+I** oder über das Symbol unten rechts im Infobereich. Im **S-Modus** lässt Windows nur Store-Apps zu – bis die Palette im Store ist, die Browser-Palette nehmen (siehe Linux).

> **Merksatz:** Diakritika (z. B. ◌̥ für stimmlos) immer **nach** dem Buchstaben klicken, sie setzen sich auf das Zeichen davor: erst **b**, dann **◌̥** ergibt **b̥**.

Wer lieber direkt in Word arbeitet, nimmt das Word-Add-in:

## Word-Add-in am Mac

1. Im Finder **⇧⌘G** drücken (Gehe zum Ordner) und diesen Pfad einfügen:
   `~/Library/Containers/com.microsoft.Word/Data/Documents/wef`
2. Gibt es den Ordner **wef** nicht: bis **Documents** gehen und dort einen neuen Ordner **wef** anlegen.
3. Die **manifest.xml** in den Ordner **wef** ziehen.
4. Word **ganz beenden** mit **⌘Q** (Fenster schließen reicht nicht) und neu öffnen.
5. **Start-Tab → ganz rechts „Add-ins“** → **Meine Add-ins** → unter **Entwickler-Add-ins** auf **IPA-Palette** klicken.

Danach gibt es im Start-Tab den Knopf **„IPA-Palette“**. Ist das Fenster schmal, steckt „Add-ins“ hinter dem **„…“** am rechten Rand des Menübands.

## Word-Add-in unter Windows

Word lädt eigene Add-ins unter Windows nur aus einem freigegebenen Ordner. Das richtet ihr einmal ein, danach bleibt die Palette dauerhaft in Word.

1. Einen Ordner anlegen, z. B. `C:\IPA`, und die **manifest.xml** direkt hineinlegen (nicht in einen Unterordner).
2. Rechtsklick auf den Ordner → **Eigenschaften → Freigabe → Freigeben…** → sich selbst auswählen → **Freigeben**.
3. Im Reiter **Freigabe** den **Netzwerkpfad** kopieren, z. B. `\\DESKTOP-ABC123\IPA`.
4. In Word: **Datei → Optionen → Trust Center → Einstellungen für das Trust Center… → Kataloge vertrauenswürdiger Add-Ins**.
5. Den Netzwerkpfad bei **Katalog-URL** einfügen → **Katalog hinzufügen** → Haken bei **Im Menü anzeigen** → zweimal **OK**.
6. Word **ganz schließen** (alle Fenster) und neu öffnen.
7. **Start → Add-ins → Weitere Add-ins** → Reiter **Freigegebener Ordner** → **IPA-Palette** → **Hinzufügen**.

Bleibt „Freigegebener Ordner“ leer: Word noch einmal schließen und öffnen, dann den Reiter erneut anklicken.

## Linux und alle ohne Word-Programm

Für Linux gibt es kein Word-Programm. Zwei Wege:

**Word im Browser** (office.com, mit Uni- oder Privatkonto):

1. Ein Dokument öffnen.
2. **Einfügen → Add-ins → Mein Add-In hochladen** → die **manifest.xml** auswählen.

Die Palette gilt dann nur in diesem Browser. Je nach Browser muss man sie nach einer Weile neu hochladen.

**Palette ohne Word** (z. B. für LibreOffice):

1. **jeremiaswilcke.github.io/ipa-palette/taskpane.html** öffnen und als Lesezeichen speichern.
2. Ein Klick auf ein Symbol **kopiert** es, im Dokument mit **Strg+V** einfügen.

Das funktioniert auf jedem Gerät ohne Installation.

## Wenn es hakt

| Problem | Lösung |
|---|---|
| Datei öffnet sich im Browser statt herunterzuladen | Startseite nehmen und den Knopf „manifest.xml herunterladen“ klicken. Oder **⌘S / Strg+S**, als `manifest.xml` speichern, Dateityp „Alle Dateien“. |
| Datei heißt `manifest.xml.txt` | In `manifest.xml` umbenennen (Windows: Dateinamenerweiterungen einblenden). |
| „Add-ins“ ist ausgegraut | Die KPH hat eigene Add-ins für Uni-Konten gesperrt. Word im Browser mit einem privaten Microsoft-Konto nutzen. |
| IPA-Palette taucht nicht auf | Word **ganz** beenden (Mac: ⌘Q) und neu starten. Word liest den Ordner nur beim Start. |
| Zeichen sehen komisch aus | Kostenlose Schrift **Charis SIL** installieren (software.sil.org) und in der Palette unter **Schriftart** wählen. |

Neue Versionen der Palette kommen automatisch, ihr müsst nichts neu installieren. Am Mac speichert Word die Seite eine Weile zwischen, notfalls Word neu starten.

<small>IPA-Palette · github.com/jeremiaswilcke/ipa-palette · Schrift: Charis (SIL Open Font License) · IPA-Tabelle: International Phonetic Association (2020), CC BY-SA 3.0</small>
