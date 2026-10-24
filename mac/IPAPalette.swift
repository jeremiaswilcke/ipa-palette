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
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
