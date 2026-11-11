// ScreenshotUploader --screenshots <cartella>: immagini del README con dati dimostrativi
// (menu e impostazioni; nessun server o percorso reale).
import AppKit
import SwiftUI

enum DemoShots {
    static func run(_ out: URL) {
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        Store.demo = true
        let store = Store.shared
        store.servers = [
            Server(id: "main", name: "Hetzner", host: "dev.example.com", user: "root", path: "/tmp/screenshots", autoDelete: false),
            Server(id: "staging", name: "Staging", host: "staging.example.com", user: "deploy", path: "/tmp/screenshots", autoDelete: true),
        ]
        store.active = "main"
        store.screenshotsDir = NSHomeDirectory() + "/Screenshots"
        // miniature finte per la cronologia
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("su-demo")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let colors: [NSColor] = [.systemOrange, .systemBlue, .systemPurple, .systemTeal]
        let names = ["SCR-20261111-checkout-bug.png", "SCR-20261111-login-form.png", "clipboard-20261111-142210.png", "SCR-20261111-dashboard.png"]
        Uploader.shared.history = names.enumerated().map { i, n in
            let url = tmp.appendingPathComponent(n)
            let img = NSImage(size: NSSize(width: 64, height: 40), flipped: false) { r in
                colors[i].setFill(); NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6).fill()
                NSColor.white.withAlphaComponent(0.85).setFill()
                NSBezierPath(roundedRect: NSRect(x: 8, y: 22, width: 36, height: 6), xRadius: 3, yRadius: 3).fill()
                NSBezierPath(roundedRect: NSRect(x: 8, y: 12, width: 24, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
                return true
            }
            if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) { try? rep.representation(using: .png, properties: [:])?.write(to: url) }
            return Upload(local: url.path, remote: "/tmp/screenshots/\(n)", server: "Hetzner", date: Date().addingTimeInterval(-Double(i * 900 + 120)))
        }
        settings(out.appendingPathComponent("settings.png"))
        menu(out.appendingPathComponent("menu.png"))
        print("ok \(out.path)")
    }

    // Finestra delle impostazioni fuori schermo
    static func settings(_ url: URL) {
        let size = NSSize(width: 560, height: 600)
        let host = NSHostingView(rootView: SettingsView())
        host.frame = NSRect(origin: .zero, size: size)
        let w = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: size.width, height: size.height), styleMask: .borderless, backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = host
        w.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.display()
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
        w.orderOut(nil)
    }

    // Menu vero: lo apre, cattura la sua finestra (e' del nostro processo: nessun permesso) e lo chiude
    static func menu(_ url: URL) {
        let d = AppDelegate()
        let menu = NSMenu()
        d.menuNeedsUpdate(menu)
        let anchor = NSWindow(contentRect: NSRect(x: 200, y: 900, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)
        anchor.appearance = NSAppearance(named: .darkAqua)
        menu.appearance = NSAppearance(named: .darkAqua)
        anchor.orderFrontRegardless()
        let t = Timer(timeInterval: 0.6, repeats: false) { _ in
            if let win = NSApp.windows.filter({ $0.isVisible && $0 !== anchor && $0.frame.height > 100 }).max(by: { $0.frame.height < $1.frame.height }),
               let view = win.contentView?.superview ?? win.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
            menu.cancelTracking()
        }
        RunLoop.main.add(t, forMode: .eventTracking)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: anchor.contentView)
        anchor.orderOut(nil)
    }
}
