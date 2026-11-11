// Configurazione (lo stesso ~/.claude-screenshot-uploader/config.json della versione shell),
// sorveglianza della cartella degli screenshot, coda di upload via rsync/SSH, cronologia.
import AppKit
import UserNotifications

// ================================================================ configurazione
struct Server: Codable, Identifiable, Equatable {
    var id: String              // chiave nel config ("main", "dev"…)
    var name: String
    var host: String
    var user: String
    var path: String
    var autoDelete: Bool
}

final class Store: ObservableObject {
    static let shared = Store()
    static var demo = false               // screenshot del README: non legge ne' scrive il config vero
    static let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude-screenshot-uploader")
    static let configURL = dir.appendingPathComponent("config.json")

    @Published var servers: [Server] = []
    @Published var active: String = ""
    @Published var screenshotsDir: String = ""
    // Preferenze dell'app (non nel config condiviso con la versione shell)
    @Published var autoUpload = UserDefaults.standard.object(forKey: "autoUpload") as? Bool ?? true { didSet { save() } }
    @Published var autoClipboard = UserDefaults.standard.bool(forKey: "autoClipboard") { didSet { save() } }
    @Published var hotkey = UserDefaults.standard.object(forKey: "hotkey") as? Bool ?? true { didSet { save(); AppDelegate.shared?.registerHotKeys() } }

    var activeServer: Server? { servers.first { $0.id == active } ?? servers.first }

    init() { if !Store.demo { load() } }

    func load() {
        let defaultDir = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        guard let data = try? Data(contentsOf: Self.configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            screenshotsDir = (defaultDir as NSString).expandingTildeInPath
            return
        }
        let raw = json["servers"] as? [String: [String: Any]] ?? [:]
        servers = raw.map { key, s in
            Server(id: key, name: s["name"] as? String ?? key, host: s["host"] as? String ?? "", user: s["user"] as? String ?? "",
                   path: s["path"] as? String ?? "/tmp/screenshots", autoDelete: s["auto_delete"] as? Bool ?? false)
        }.sorted { $0.id == (json["active"] as? String) ? true : ($1.id == (json["active"] as? String) ? false : $0.name < $1.name) }
        active = json["active"] as? String ?? servers.first?.id ?? ""
        screenshotsDir = ((json["local_screenshots"] as? String) ?? defaultDir as String).replacingOccurrences(of: "~", with: NSHomeDirectory())
    }

    // Scrive il config nello stesso formato della versione shell (cosi' restano compatibili)
    func save() {
        guard !Store.demo else { return }
        let d = UserDefaults.standard
        d.set(autoUpload, forKey: "autoUpload"); d.set(autoClipboard, forKey: "autoClipboard"); d.set(hotkey, forKey: "hotkey")
        var existing = (try? JSONSerialization.jsonObject(with: Data(contentsOf: Self.configURL))) as? [String: Any] ?? [:]
        existing["active"] = active
        existing["local_screenshots"] = screenshotsDir
        existing["servers"] = Dictionary(uniqueKeysWithValues: servers.map {
            ($0.id, ["name": $0.name, "host": $0.host, "user": $0.user, "path": $0.path, "auto_delete": $0.autoDelete] as [String: Any])
        })
        try? FileManager.default.createDirectory(at: Self.dir, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: Self.configURL, options: .atomic)
        }
    }
}

// ================================================================ cronologia
struct Upload: Codable, Identifiable {
    var id: String { remote + "\(date.timeIntervalSince1970)" }
    let local: String
    let remote: String
    let server: String
    let date: Date
}

// ================================================================ motore
final class Uploader: ObservableObject {
    static let shared = Uploader()
    @Published var history: [Upload] = []
    @Published var busy: String?                 // nome del file in caricamento
    @Published var lastError: String?

    private let queue = DispatchQueue(label: "uploader.queue")
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1
    private var seen = Set<String>()              // file gia' gestiti (per nome)
    private let startedAt = Date()
    private var clipboardTimer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var ownPasteboardChange = -1
    private let historyURL = Store.dir.appendingPathComponent("history.json")
    let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "pdf", "mov", "mp4"]

    init() {
        if !Store.demo, let d = try? Data(contentsOf: historyURL), let h = try? JSONDecoder().decode([Upload].self, from: d) { history = h }
    }

    // ------------------------------------------------------------ sorveglianza della cartella
    // Evento del file system sulla cartella: nessun polling, upload appena lo screenshot e' salvato
    func startWatching() {
        stopWatching()
        let path = Store.shared.screenshotsDir
        // segna come gia' visti i file esistenti: all'avvio non si ricarica niente
        for f in (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? [] { seen.insert(f) }
        watchedFD = open(path, O_EVTONLY)
        guard watchedFD >= 0 else { lastError = L("Can't watch %@", path); return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: watchedFD, eventMask: [.write, .rename], queue: queue)
        src.setEventHandler { [weak self] in self?.scan() }
        src.setCancelHandler { [fd = watchedFD] in close(fd) }
        src.resume()
        watcher = src
    }

    func stopWatching() { watcher?.cancel(); watcher = nil; watchedFD = -1 }

    private func scan() {
        guard Store.shared.autoUpload else { return }
        let dir = URL(fileURLWithPath: Store.shared.screenshotsDir)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        for url in files where !seen.contains(url.lastPathComponent) && imageExtensions.contains(url.pathExtension.lowercased()) {
            seen.insert(url.lastPathComponent)
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            // solo file nuovi: niente upload di vecchi file spostati nella cartella
            guard created > startedAt, Date().timeIntervalSince(created) < 60 else { continue }
            waitUntilStable(url)
            upload(url)
        }
    }

    // macOS scrive lo screenshot in piu' passaggi: aspetta che la dimensione smetta di cambiare
    private func waitUntilStable(_ url: URL) {
        var last: Int64 = -1
        for _ in 0..<20 {
            let size = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
            if size > 0 && size == last { return }
            last = size
            usleep(150_000)
        }
    }

    // ------------------------------------------------------------ appunti
    // Immagine (o file) negli appunti -> file temporaneo -> upload
    func uploadClipboard() {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            urls.forEach { u in queue.async { self.upload(u) } }
            return
        }
        guard let image = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
              let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            notify(L("Nothing to upload"), L("The clipboard doesn't contain an image or a file."))
            return
        }
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ScreenshotUploader")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        let url = dir.appendingPathComponent("clipboard-\(f.string(from: Date())).png")
        guard (try? png.write(to: url)) != nil else { return }
        queue.async { self.upload(url, temporary: true) }
    }

    // Ultimo screenshot della cartella, a mano
    func uploadLatest() {
        let dir = URL(fileURLWithPath: Store.shared.screenshotsDir)
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        guard let latest = files.max(by: {
            ((try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast) <
            ((try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast) }) else {
            notify(L("No screenshots"), L("The folder %@ is empty.", dir.path)); return
        }
        queue.async { self.upload(latest) }
    }

    func uploadFiles(_ urls: [URL]) { urls.forEach { u in queue.async { self.upload(u) } } }

    // Upload automatico delle immagini copiate (opzionale): controlla gli appunti due volte al secondo
    func setClipboardWatching(_ on: Bool) {
        clipboardTimer?.invalidate(); clipboardTimer = nil
        lastChangeCount = NSPasteboard.general.changeCount
        guard on else { return }
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let pb = NSPasteboard.general
            guard pb.changeCount != self.lastChangeCount else { return }
            self.lastChangeCount = pb.changeCount
            guard pb.changeCount != self.ownPasteboardChange,                   // il percorso copiato da noi
                  pb.canReadObject(forClasses: [NSImage.self], options: nil),
                  !pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else { return }
            self.uploadClipboard()
        }
    }

    // ------------------------------------------------------------ upload (sempre sulla coda seriale)
    private func upload(_ url: URL, temporary: Bool = false) {
        guard let s = Store.shared.activeServer, !s.host.isEmpty, !s.user.isEmpty else {
            DispatchQueue.main.async { self.lastError = L("No server configured") }
            notify(L("Upload failed"), L("Add a server in Settings first."))
            return
        }
        let name = url.lastPathComponent
        DispatchQueue.main.async { self.busy = name }
        let remoteDir = s.path.hasSuffix("/") ? String(s.path.dropLast()) : s.path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        // crea la cartella remota se manca; ssh con sole chiavi (BatchMode), host nuovo accettato e poi fissato
        p.arguments = ["-a", "--rsync-path=mkdir -p '\(remoteDir)' && rsync",
                       "-e", "ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new",
                       url.path, "\(s.user)@\(s.host):\(remoteDir)/"]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        var ok = false
        if (try? p.run()) != nil { p.waitUntilExit(); ok = p.terminationStatus == 0 }
        let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let remote = "\(remoteDir)/\(name)"
        DispatchQueue.main.async {
            self.busy = nil
            if ok {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(remote, forType: .string)
                self.ownPasteboardChange = pb.changeCount
                self.lastError = nil
                self.history.insert(Upload(local: url.path, remote: remote, server: s.name, date: Date()), at: 0)
                if self.history.count > 15 { self.history.removeLast(self.history.count - 15) }
                self.saveHistory()
                self.notify(L("Path copied"), "\(remote) → \(s.name)")
                if s.autoDelete && !temporary { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
            } else {
                let short = message.split(separator: "\n").last.map(String.init) ?? L("unknown error")
                self.lastError = short
                self.notify(L("Upload failed"), L("Could not upload to %@: %@", s.name, short))
            }
        }
    }

    func copy(_ u: Upload) {
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(u.remote, forType: .string)
        ownPasteboardChange = pb.changeCount
    }

    private func saveHistory() {
        guard !Store.demo else { return }
        if let d = try? JSONEncoder().encode(history) { try? d.write(to: historyURL, options: .atomic) }
    }

    // ------------------------------------------------------------ notifiche
    func notify(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}

// Prova la connessione SSH a un server (per il pulsante "Test" nelle impostazioni)
func testConnection(_ s: Server, done: @escaping (Bool, String) -> Void) {
    DispatchQueue.global().async {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        p.arguments = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=6", "-o", "StrictHostKeyChecking=accept-new", "\(s.user)@\(s.host)", "true"]
        let err = Pipe(); p.standardError = err; p.standardOutput = FileHandle.nullDevice
        var ok = false
        if (try? p.run()) != nil { p.waitUntilExit(); ok = p.terminationStatus == 0 }
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        DispatchQueue.main.async { done(ok, msg) }
    }
}

// ================================================================ vecchia versione (shell + xbar)
// Rileva i LaunchAgent della versione 3 e li disattiva, per non caricare due volte
enum Legacy {
    static let agents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
    static var plists: [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: agents, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("com.claudecode.screenshot-uploader") && $0.pathExtension == "plist" }
    }
    static var xbarPlugin: URL? {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/xbar/plugins")
        return ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .first { $0.lastPathComponent.hasPrefix("screenshot-uploader") }
    }
    static var present: Bool { !plists.isEmpty || xbarPlugin != nil }

    // Ferma i job e sposta i file in una cartella di backup (reversibile)
    static func disable() {
        let backup = Store.dir.appendingPathComponent("legacy-backup")
        try? FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        for p in plists {
            let label = p.deletingPathExtension().lastPathComponent
            let t = Process(); t.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            t.arguments = ["bootout", "gui/\(getuid())/\(label)"]
            try? t.run(); t.waitUntilExit()
            try? FileManager.default.moveItem(at: p, to: backup.appendingPathComponent(p.lastPathComponent))
        }
        if let x = xbarPlugin { try? FileManager.default.moveItem(at: x, to: backup.appendingPathComponent(x.lastPathComponent)) }
    }
}
