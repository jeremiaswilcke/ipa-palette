// IPA-Palette für macOS: schwebende Palette, die IPA-Zeichen ins zuletzt aktive Programm tippt.
// Oberfläche = dieselben Web-Dateien wie das Word-Add-in (taskpane.html), hier im WKWebView.
import AppKit
import Carbon.HIToolbox
import ServiceManagement
import WebKit

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }      // Suchfeld und X-SAMPA-Eingabe brauchen Tastatur
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, NSWindowDelegate {
    var panel: Panel!
    var web: WKWebView!
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    /// Programm, in das getippt wird: das zuletzt aktive außer uns selbst.
    var target: NSRunningApplication?

    func applicationDidFinishLaunching(_ note: Notification) {
        if offerMoveToApplications() { return }
        let me = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != me { target = front }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != me else { return }
            self?.target = app
        }
        buildEditMenu()
        buildPanel()
        buildStatusItem()
        registerHotKey()
        showPanel()
        startUpdateChecks()
        // Bedienungshilfen einmal anfragen; ohne sie wird nur kopiert.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if CommandLine.arguments.contains("--wrap") {   // Testpfad Klammern
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.wrap("[", "]") }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--type"), i + 1 < CommandLine.arguments.count {
            let text = CommandLine.arguments[i + 1]   // Testpfad: nach 1,5 s ins aktive Programm tippen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.insert(text, back: 0) }
        }
    }

    /// Aus der DMG oder dem Download-Ordner gestartet (macOS verlegt die App dann in einen
    /// Zufallsordner, Bedienungshilfen und Autostart halten nicht): anbieten, nach /Applications zu kopieren.
    func offerMoveToApplications() -> Bool {
        let path = Bundle.main.bundlePath
        guard path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/") || path.contains("/Downloads/") else { return false }
        let alert = NSAlert()
        alert.messageText = "IPA-Palette in „Programme“ verschieben?"
        alert.informativeText = "Die App läuft gerade aus der DMG bzw. dem Download-Ordner. Damit Tastenkürzel, Bedienungshilfen und „Bei Anmeldung starten“ zuverlässig funktionieren, sollte sie in „Programme“ liegen."
        alert.addButton(withTitle: "Verschieben und starten")
        alert.addButton(withTitle: "Nicht jetzt")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let dest = URL(fileURLWithPath: "/Applications/IPA-Palette.app")
        let fm = FileManager.default
        do {
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
                where other != NSRunningApplication.current { other.terminate() }
            if fm.fileExists(atPath: dest.path) { try fm.trashItem(at: dest, resultingItemURL: nil) }
            try fm.copyItem(at: Bundle.main.bundleURL, to: dest)
        } catch {
            let err = NSAlert(error: error); err.runModal(); return false
        }
        NSWorkspace.shared.openApplication(at: dest, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(); return true
    }

    // MARK: Fenster

    func buildPanel() {
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 620),
                      styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                      backing: .buffered, defer: false)
        panel.title = "IPA-Palette"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 280, height: 320)
        panel.delegate = self
        panel.center()
        panel.setFrameAutosaveName("IPAPalette")

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "ipa")
        web = WKWebView(frame: panel.contentView!.bounds, configuration: config)
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground")
        panel.contentView!.addSubview(web)
        let dir = Bundle.main.resourceURL!.appendingPathComponent("web")
        web.loadFileURL(dir.appendingPathComponent("taskpane.html"), allowingReadAccessTo: dir)
    }

    @objc func showPanel() {
        panel.orderFrontRegardless()
    }

    @objc func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { showPanel() }
    }

    /// Ohne Hauptmenü funktionieren ⌘C/⌘V/⌘A im Suchfeld nicht.
    func buildEditMenu() {
        let main = NSMenu()
        let appItem = main.addItem(withTitle: "", action: nil, keyEquivalent: "")
        appItem.submenu = NSMenu()
        appItem.submenu!.addItem(withTitle: "IPA-Palette beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = main.addItem(withTitle: "Bearbeiten", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Bearbeiten")
        edit.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    // MARK: Menüleiste

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "ə"
        statusItem.button?.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        statusItem.button?.toolTip = "IPA-Palette (⌃⌥I)"
        let menu = NSMenu()
        menu.addItem(withTitle: "Palette ein-/ausblenden  ⌃⌥I", action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Bei Anmeldung starten", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(withTitle: "Bedienungshilfen öffnen …", action: #selector(openAccessibility), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Nach Updates suchen …", action: #selector(checkForUpdatesManually), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Version \(currentVersion)", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "IPA-Palette beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc func toggleLogin(_ item: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { NSSound.beep() }
        item.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: Tastenkürzel ⌃⌥I (Carbon, braucht keine Freigabe)

    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            let me = Unmanaged<AppDelegate>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { me.togglePanel() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        let id = EventHotKeyID(signature: OSType(0x49504150), id: 1)   // 'IPAP'
        RegisterEventHotKey(UInt32(kVK_ANSI_I), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    // MARK: Einfügen

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        if let open = body["open"] as? String, let close = body["close"] as? String {
            wrap(open, close)
        } else if let text = body["text"] as? String {
            insert(text, back: body["back"] as? Int ?? 0)
        }
    }

    /// Klammern um die Markierung im Zielprogramm; ohne Markierung leere Klammern mit Cursor dazwischen.
    /// Die Markierung wird per ⌘C geholt, die Zwischenablage danach wiederhergestellt.
    func wrap(_ open: String, _ close: String) {
        guard AXIsProcessTrusted(), let app = target, !app.isTerminated else {
            insert(open + close, back: close.count); return
        }
        if panel.isKeyWindow { panel.resignKey() }
        app.activate()
        let pb = NSPasteboard.general
        let saved = (pb.pasteboardItems ?? []).map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for t in item.types { if let d = item.data(forType: t) { copy.setData(d, forType: t) } }
            return copy
        }
        let before = pb.changeCount
        let pid = app.processIdentifier
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            Self.key(CGKeyCode(kVK_ANSI_C), pid: pid, flags: .maskCommand)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                let selected = pb.changeCount != before ? (pb.string(forType: .string) ?? "") : ""
                if pb.changeCount != before {
                    pb.clearContents()
                    if !saved.isEmpty { pb.writeObjects(saved) }
                }
                if selected.isEmpty || selected.contains("\n") && selected.count > 2000 {
                    Self.type(open + close, pid: pid)
                    for _ in 0..<close.count { Self.key(CGKeyCode(kVK_LeftArrow), pid: pid) }
                } else {
                    Self.type(open + selected + close, pid: pid)
                }
            }
        }
    }

    func insert(_ text: String, back: Int) {
        guard AXIsProcessTrusted() else {
            copy(text)
            toast("Bedienungshilfen fehlen, kopiert: ", text)
            return
        }
        guard let app = target, !app.isTerminated else {
            copy(text)
            toast("Kein Zielprogramm, kopiert: ", text)
            return
        }
        // Tastatur zurück ans Zielprogramm geben, dann tippen.
        if panel.isKeyWindow { panel.resignKey() }
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            Self.type(text, pid: app.processIdentifier)
            for _ in 0..<back { Self.key(CGKeyCode(kVK_LeftArrow), pid: app.processIdentifier) }
        }
    }

    /// Tippt Unicode-Text als Tastaturereignisse direkt an den Prozess (in Stücken zu 16 UTF-16-Einheiten).
    static func type(_ text: String, pid: pid_t) {
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            var chunk = Array(units[i..<min(i + 16, units.count)])
            // Ersatzpaare nicht trennen
            if let last = chunk.last, UTF16.isLeadSurrogate(last), i + chunk.count < units.count {
                chunk.append(units[i + chunk.count])
            }
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { continue }
                e.flags = []
                e.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                e.postToPid(pid)
            }
            i += chunk.count
        }
    }

    static func key(_ code: CGKeyCode, pid: pid_t, flags: CGEventFlags = []) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
            e.flags = flags
            e.postToPid(pid)
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func toast(_ prefix: String, _ text: String) {
        let json = try! JSONSerialization.data(withJSONObject: [prefix, text])
        web.evaluateJavaScript("window.ipaNativeToast && window.ipaNativeToast(...\(String(data: json, encoding: .utf8)!))")
    }

    // MARK: Updates (neueste Version auf GitHub)

    static let releasesAPI = URL(string: "https://api.github.com/repos/jeremiaswilcke/ipa-palette/releases/latest")!
    /// Nur Updates mit unserer Developer-ID und Bundle-ID werden installiert.
    static let updateRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"7MN88MYAVL\" and identifier \"at.askalon.ipa-palette\""
    var offeredUpdate: String?   // von selbst nur einmal pro Lauf fragen
    var updating = false

    /// Testpfad: `--als-version 1.0.0` tut so, als wäre eine ältere Version installiert.
    var currentVersion: String {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--als-version"), i + 1 < a.count { return a[i + 1] }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func startUpdateChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.checkForUpdates(manual: false) }
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.checkForUpdates(manual: false) }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    @objc func checkForUpdatesManually() { checkForUpdates(manual: true) }

    func checkForUpdates(manual: Bool) {
        guard !updating else { return }
        var req = URLRequest(url: Self.releasesAPI, timeoutInterval: 20)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("IPA-Palette-macOS", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let release = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { self.handleRelease(release, manual: manual) }
        }.resume()
    }

    func handleRelease(_ release: [String: Any]?, manual: Bool) {
        guard let release, let tag = release["tag_name"] as? String, let assets = release["assets"] as? [[String: Any]] else {
            if manual { info("Update-Prüfung fehlgeschlagen", "GitHub ist gerade nicht erreichbar. Bitte später noch einmal versuchen.") }
            return
        }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.isNewer(version, than: currentVersion),
              let link = assets.first(where: { ($0["name"] as? String ?? "").hasSuffix(".dmg") })?["browser_download_url"] as? String,
              let url = URL(string: link) else {
            if manual { info("IPA-Palette ist aktuell", "Version \(currentVersion) ist die neueste.") }
            return
        }
        let defaults = UserDefaults.standard
        if !manual && (offeredUpdate == version || defaults.string(forKey: "skipVersion") == version) { return }
        offeredUpdate = version
        if !CommandLine.arguments.contains("--update-sofort") {   // Testpfad: ohne Rückfrage installieren
            let alert = NSAlert()
            alert.messageText = "IPA-Palette \(version) ist da"
            var notes = (release["body"] as? String ?? "").replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if notes.count > 600 { notes = String(notes.prefix(600)) + " …" }
            alert.informativeText = "Installiert ist Version \(currentVersion)." + (notes.isEmpty ? "" : "\n\n" + notes)
            alert.addButton(withTitle: "Jetzt aktualisieren")
            alert.addButton(withTitle: "Später")
            alert.addButton(withTitle: "Diese Version überspringen")
            NSApp.activate(ignoringOtherApps: true)
            switch alert.runModal() {
            case .alertFirstButtonReturn: break
            case .alertThirdButtonReturn: defaults.set(version, forKey: "skipVersion"); return
            default: return
            }
        }
        installUpdate(from: url, version: version)
    }

    /// Lädt die DMG, prüft die Signatur und tauscht die App aus, sobald diese beendet ist.
    func installUpdate(from url: URL, version: String) {
        updating = true
        statusItem.button?.title = "ə↓"
        URLSession.shared.downloadTask(with: url) { file, response, error in
            let fail: (String, URL?) -> Void = { msg, dmg in DispatchQueue.main.async { self.updateFailed(msg, dmg: dmg) } }
            guard let file, (response as? HTTPURLResponse)?.statusCode == 200 else {
                return fail(error?.localizedDescription ?? "Der Download ist fehlgeschlagen.", nil)
            }
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appendingPathComponent("ipa-palette-update")
            let dmg = work.appendingPathComponent("IPA-Palette-\(version).dmg")
            let mount = work.appendingPathComponent("dmg"), staged = work.appendingPathComponent("IPA-Palette.app")
            try? fm.removeItem(at: work)
            do {
                try fm.createDirectory(at: work, withIntermediateDirectories: true)
                try fm.moveItem(at: file, to: dmg)
            } catch { return fail(error.localizedDescription, nil) }
            guard Self.run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path]) == 0 else {
                return fail("Die DMG ließ sich nicht öffnen.", nil)
            }
            let copied = Self.run("/usr/bin/ditto", [mount.appendingPathComponent("IPA-Palette.app").path, staged.path]) == 0
            _ = Self.run("/usr/bin/hdiutil", ["detach", mount.path, "-quiet", "-force"])
            guard copied else { return fail("Die App ließ sich nicht aus der DMG kopieren.", dmg) }
            guard Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "-R=" + Self.updateRequirement, staged.path]) == 0 else {
                return fail("Die Signatur des Updates stimmt nicht. Update abgebrochen.", nil)
            }
            DispatchQueue.main.async { self.replaceApp(with: staged, work: work, dmg: dmg) }
        }.resume()
    }

    func replaceApp(with staged: URL, work: URL, dmg: URL) {
        var dest = Bundle.main.bundleURL
        if dest.path.hasPrefix("/Volumes/") || dest.path.contains("/AppTranslocation/") { dest = URL(fileURLWithPath: "/Applications/IPA-Palette.app") }
        let folder = dest.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: folder) else {
            return updateFailed("Keine Schreibrechte für „\(folder)“. Bitte die neue Version aus der DMG nach „Programme“ ziehen.", dmg: dmg)
        }
        // Wartet auf das Ende dieser App, tauscht sie aus (bei Fehler zurück) und startet die neue.
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.alt"; [ -e "$2" ] && mv "$2" "$2.alt"
        if /usr/bin/ditto "$3" "$2"; then rm -rf "$2.alt"; else rm -rf "$2"; [ -e "$2.alt" ] && mv "$2.alt" "$2"; fi
        /usr/bin/open "$2"
        rm -rf "$4"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), dest.path, staged.path, work.path]
        do { try p.run() } catch { return updateFailed(error.localizedDescription, dmg: dmg) }
        NSApp.terminate(nil)
    }

    func updateFailed(_ message: String, dmg: URL?) {
        updating = false
        statusItem.button?.title = "ə"
        info("Update nicht installiert", message)
        if let dmg { NSWorkspace.shared.open(dmg) }
    }

    func info(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @discardableResult
    static func run(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        let err = Pipe()
        p.standardError = err
        do { try p.run() } catch { NSLog("IPA-Palette: %@ startet nicht: %@", tool, error.localizedDescription); return -1 }
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        if p.terminationStatus != 0 { NSLog("IPA-Palette: %@ %@ → %d %@", tool, args.joined(separator: " "), p.terminationStatus, msg) }
        return p.terminationStatus
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
