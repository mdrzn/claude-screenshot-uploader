// Screenshot Uploader: icona nella barra dei menu, menu, trascina-e-rilascia, scorciatoie.
import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox
import UserNotifications

// Pulsante della barra che accetta file trascinati
final class DropButtonView: NSView {
    var onDrop: (([URL]) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }        // i clic vanno al pulsante
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        onDrop?(urls)
        return !urls.isEmpty
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    static weak var shared: AppDelegate?
    var item: NSStatusItem!
    let store = Store.shared
    let uploader = Uploader.shared
    var bag = Set<AnyCancellable>()
    var settingsWindow: NSWindow?
    var hotKeys: [EventHotKeyRef] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        AppDelegate.shared = self
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = item.button {
            let drop = DropButtonView(frame: b.bounds)
            drop.autoresizingMask = [.width, .height]
            drop.onDrop = { [weak self] urls in self?.uploader.uploadFiles(urls) }
            b.addSubview(drop)
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        updateIcon()
        uploader.$busy.merge(with: uploader.$lastError.map { _ in nil }).receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateIcon() } }.store(in: &bag)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        uploader.startWatching()
        uploader.setClipboardWatching(store.autoClipboard)
        installHotKeyHandler()
        registerHotKeys()

        // primo avvio senza server, o con la vecchia versione ancora attiva: apri le impostazioni
        if store.servers.isEmpty || Legacy.present { openSettings() }
    }

    func updateIcon() {
        let symbol = uploader.busy != nil ? "arrow.up.circle.fill" : (uploader.lastError != nil ? "exclamationmark.triangle" : "photo.badge.arrow.down")
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Screenshot Uploader")
        img?.isTemplate = true
        item.button?.image = img
        item.button?.toolTip = uploader.busy.map { L("Uploading %@…", $0) } ?? store.activeServer.map { L("Uploads to %@", $0.name) }
    }

    // ------------------------------------------------------------ menu (ricostruito a ogni apertura)
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: store.activeServer.map { "\($0.name) — \($0.user)@\($0.host):\($0.path)" } ?? L("No server configured"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if let e = uploader.lastError {
            let it = NSMenuItem(title: "⚠️ " + e, action: nil, keyEquivalent: "")
            it.isEnabled = false
            menu.addItem(it)
        }
        menu.addItem(.separator())
        add(menu, L("Upload clipboard image"), #selector(uploadClipboard), key: store.hotkey ? "⌥⌘U" : nil)
        add(menu, L("Upload latest screenshot"), #selector(uploadLatest))
        add(menu, L("Upload files…"), #selector(uploadFilesPanel))
        menu.addItem(.separator())

        if !uploader.history.isEmpty {
            let title = NSMenuItem(title: L("Recent uploads — click to copy the path"), action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
            for (i, u) in uploader.history.prefix(8).enumerated() {
                let it = NSMenuItem(title: (u.remote as NSString).lastPathComponent, action: #selector(copyRecent(_:)), keyEquivalent: "")
                it.target = self; it.tag = i
                it.toolTip = "\(u.remote) · \(u.server)"
                if let img = NSImage(contentsOfFile: u.local) {
                    img.size = NSSize(width: 28, height: 28 * img.size.height / max(img.size.width, 1))
                    it.image = img
                }
                let f = RelativeDateTimeFormatter(); f.unitsStyle = .short; f.locale = Locale(identifier: italian ? "it_IT" : "en_US")
                it.attributedTitle = NSAttributedString(string: "\((u.remote as NSString).lastPathComponent)  ",
                    attributes: [.font: NSFont.menuFont(ofSize: 0)])
                    + NSAttributedString(string: f.localizedString(for: u.date, relativeTo: Date()),
                    attributes: [.font: NSFont.menuFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
                menu.addItem(it)
            }
            menu.addItem(.separator())
        }

        if store.servers.count > 1 {
            let sub = NSMenu()
            for s in store.servers {
                let it = NSMenuItem(title: "\(s.name)  (\(s.host))", action: #selector(switchServer(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = s.id
                it.state = s.id == store.activeServer?.id ? .on : .off
                sub.addItem(it)
            }
            let srv = NSMenuItem(title: L("Server"), action: nil, keyEquivalent: "")
            srv.submenu = sub
            menu.addItem(srv)
        }
        let auto = add(menu, L("Upload new screenshots automatically"), #selector(toggleAuto))
        auto.state = store.autoUpload ? .on : .off
        let clip = add(menu, L("Upload copied images automatically"), #selector(toggleClipboard))
        clip.state = store.autoClipboard ? .on : .off
        menu.addItem(.separator())
        add(menu, L("Open screenshots folder"), #selector(openFolder))
        add(menu, L("Settings…"), #selector(openSettings), key: ",")
        menu.addItem(.separator())
        add(menu, L("Quit"), #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    @discardableResult
    func add(_ menu: NSMenu, _ title: String, _ sel: Selector, key: String? = nil, target: AnyObject? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: key == "," || key == "q" ? key! : "")
        it.target = target ?? self
        if key == "⌥⌘U" { it.keyEquivalent = "u"; it.keyEquivalentModifierMask = [.option, .command] }
        menu.addItem(it)
        return it
    }

    @objc func uploadClipboard() { uploader.uploadClipboard() }
    @objc func uploadLatest() { uploader.uploadLatest() }
    @objc func copyRecent(_ sender: NSMenuItem) {
        guard sender.tag < uploader.history.count else { return }
        uploader.copy(uploader.history[sender.tag])
    }
    @objc func switchServer(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        store.active = id; store.save(); updateIcon()
    }
    @objc func toggleAuto() { store.autoUpload.toggle() }
    @objc func toggleClipboard() { store.autoClipboard.toggle(); uploader.setClipboardWatching(store.autoClipboard) }
    @objc func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: store.screenshotsDir)) }
    @objc func uploadFilesPanel() {
        NSApp.activate()
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        if p.runModal() == .OK { uploader.uploadFiles(p.urls) }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Screenshot Uploader"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            settingsWindow = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ n: Notification) {
        if (n.object as? NSWindow) == settingsWindow { NSApp.setActivationPolicy(.accessory) }
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) { done([.banner]) }

    // ------------------------------------------------------------ scorciatoia ⌥⌘U (Carbon: nessun permesso richiesto)
    func installHotKeyHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { Uploader.shared.uploadClipboard() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    func registerHotKeys() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys.removeAll()
        guard store.hotkey else { return }
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_U), UInt32(cmdKey | optionKey), EventHotKeyID(signature: OSType(0x53555031), id: 1),
                            GetApplicationEventTarget(), 0, &ref)
        if let ref { hotKeys.append(ref) }
    }
}

func + (a: NSAttributedString, b: NSAttributedString) -> NSAttributedString {
    let m = NSMutableAttributedString(attributedString: a); m.append(b); return m
}

// Avvio al login tramite LaunchAgent utente
enum LoginItem {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/com.mdrzn.screenshot-uploader.plist")
    static var isOn: Bool { FileManager.default.fileExists(atPath: url.path) }
    static func set(_ on: Bool) {
        if on, let exe = Bundle.main.executablePath {
            let plist: [String: Any] = ["Label": "com.mdrzn.screenshot-uploader", "ProgramArguments": [exe], "RunAtLoad": true, "LimitLoadToSessionType": "Aqua"]
            (plist as NSDictionary).write(to: url, atomically: true)
        } else { try? FileManager.default.removeItem(at: url) }
    }
}

let app = NSApplication.shared
// ScreenshotUploader --upload <file>: carica un file con la configurazione attuale ed esce (uso da terminale/script)
if let i = CommandLine.arguments.firstIndex(of: "--upload"), i + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    let u = Uploader.shared
    var done = false
    let c = u.$history.dropFirst().sink { h in if let last = h.first { print("ok \(last.remote) -> \(last.server)"); done = true } }
    let e = u.$lastError.dropFirst().sink { err in if let err { print("errore: \(err)"); done = true } }
    u.uploadFiles([url])
    while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    _ = (c, e)
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--screenshots"), i + 1 < CommandLine.arguments.count {
    NSApp.setActivationPolicy(.accessory)
    DemoShots.run(URL(fileURLWithPath: CommandLine.arguments[i + 1])); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--icon"), i + 1 < CommandLine.arguments.count {
    IconRenderer.run(URL(fileURLWithPath: CommandLine.arguments[i + 1])); exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
