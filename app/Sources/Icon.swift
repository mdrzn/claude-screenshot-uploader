// Icona dell'app disegnata in SwiftUI: ScreenshotUploader --icon <cartella.iconset>
import SwiftUI
import AppKit

struct AppIconView: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.36), Color(red: 0.85, green: 0.34, blue: 0.24)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: size * 0.012)
            // "screenshot": cornice con angoli di selezione
            RoundedRectangle(cornerRadius: size * 0.06).stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: size * 0.045, dash: [size * 0.09, size * 0.06]))
                .frame(width: size * 0.56, height: size * 0.42).offset(y: size * 0.06)
            Image(systemName: "arrow.up").font(.system(size: size * 0.3, weight: .heavy)).foregroundStyle(.white)
                .offset(y: -size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

enum IconRenderer {
    static func run(_ out: URL) {
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        NSApp.setActivationPolicy(.prohibited)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let px = CGFloat(base * scale)
                let view = AppIconView(size: px * 0.8).shadow(color: .black.opacity(0.3), radius: px * 0.02, y: px * 0.012).frame(width: px, height: px)
                let host = NSHostingView(rootView: view)
                host.frame = NSRect(x: 0, y: 0, width: px, height: px)
                let w = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: px, height: px), styleMask: .borderless, backing: .buffered, defer: false)
                w.isOpaque = false; w.backgroundColor = .clear; w.contentView = host; w.orderFrontRegardless()
                RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                host.display()
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent(name))
                w.orderOut(nil)
            }
        }
    }
}
