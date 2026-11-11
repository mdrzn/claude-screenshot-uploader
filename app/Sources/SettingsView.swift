// Impostazioni: server (aggiungi/modifica/prova), cartella, opzioni, migrazione dalla versione 3.
import SwiftUI
import AppKit

// Stato locale delle viste (@State richiede un plugin che i soli Command Line Tools non hanno)
final class LocalBox<T>: ObservableObject { @Published var value: T; init(_ v: T) { value = v } }
@propertyWrapper struct Local<T>: DynamicProperty {
    @StateObject private var box: LocalBox<T>
    init(wrappedValue: T) { _box = StateObject(wrappedValue: LocalBox(wrappedValue)) }
    var wrappedValue: T { get { box.value } nonmutating set { box.value = newValue } }
    var projectedValue: Binding<T> { Binding(get: { box.value }, set: { box.value = $0 }) }
}

struct SettingsView: View {
    @ObservedObject var store = Store.shared
    @Local private var editing: Server?
    @Local private var testResult: [String: String] = [:]
    @Local private var legacyPresent = Legacy.present
    @Local private var loginOn = LoginItem.isOn

    var body: some View {
        Form {
            if legacyPresent {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("The previous version (shell + xbar) is still active")).font(.headline)
                        Text(L("Turn it off so screenshots aren't uploaded twice. Its LaunchAgent and xbar plugin are moved to ~/.claude-screenshot-uploader/legacy-backup, so you can restore them."))
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button(L("Turn off the previous version")) { Legacy.disable(); legacyPresent = Legacy.present }
                    }
                }
            }
            Section(L("Servers")) {
                ForEach(store.servers) { s in
                    HStack {
                        Image(systemName: s.id == store.activeServer?.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(s.id == store.activeServer?.id ? Color.accentColor : .secondary)
                            .onTapGesture { store.active = s.id; store.save() }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).fontWeight(.medium)
                            Text("\(s.user)@\(s.host):\(s.path)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            if let r = testResult[s.id] { Text(r).font(.caption).foregroundStyle(r.hasPrefix("✓") ? .green : .orange) }
                        }
                        Spacer()
                        Button(L("Test")) {
                            testResult[s.id] = L("Connecting…")
                            testConnection(s) { ok, msg in testResult[s.id] = ok ? "✓ " + L("SSH connection works") : "✗ " + (msg.isEmpty ? L("Connection failed") : msg) }
                        }
                        Button(L("Edit")) { editing = s }
                        Button(role: .destructive) { store.servers.removeAll { $0.id == s.id }; store.save() } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
                Button { editing = Server(id: "server\(store.servers.count + 1)", name: "", host: "", user: NSUserName(), path: "/tmp/screenshots", autoDelete: false) } label: {
                    Label(L("Add server"), systemImage: "plus")
                }
                Text(L("Uploads use your SSH keys (as with ssh in Terminal). No passwords are asked for or stored."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Screenshots")) {
                HStack {
                    Text(store.screenshotsDir.replacingOccurrences(of: NSHomeDirectory(), with: "~")).textSelection(.enabled)
                    Spacer()
                    Button(L("Change…")) {
                        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false
                        if p.runModal() == .OK, let u = p.url { store.screenshotsDir = u.path; store.save(); Uploader.shared.startWatching() }
                    }
                }
                Toggle(L("Upload new screenshots automatically"), isOn: $store.autoUpload)
                Toggle(L("Upload copied images automatically"), isOn: Binding(get: { store.autoClipboard }, set: { store.autoClipboard = $0; Uploader.shared.setClipboardWatching($0) }))
                Toggle(L("⌥⌘U uploads the clipboard image"), isOn: $store.hotkey)
                Toggle(L("Open at login"), isOn: Binding(get: { loginOn }, set: { LoginItem.set($0); loginOn = $0 }))
            }
            Section {
                Text(L("Tip: drop any file on the menu bar icon to upload it. Click a recent upload in the menu to copy its path again."))
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text("made by mdrzn").font(.caption).foregroundStyle(.tertiary)
                    Spacer()
                    Link("GitHub", destination: URL(string: "https://github.com/mdrzn/claude-screenshot-uploader")!).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 600)
        .sheet(item: Binding(get: { editing }, set: { editing = $0 })) { s in
            ServerEditor(server: s) { saved in
                if let i = store.servers.firstIndex(where: { $0.id == saved.id }) { store.servers[i] = saved } else { store.servers.append(saved) }
                if store.servers.count == 1 { store.active = saved.id }
                store.save()
                editing = nil
            } cancel: { editing = nil }
        }
    }
}

struct ServerEditor: View {
    @Local var server: Server
    let save: (Server) -> Void
    let cancel: () -> Void
    init(server: Server, save: @escaping (Server) -> Void, cancel: @escaping () -> Void) {
        _server = Local(wrappedValue: server); self.save = save; self.cancel = cancel
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(server.name.isEmpty ? L("New server") : server.name).font(.title3).bold()
            Form {
                TextField(L("Name"), text: $server.name, prompt: Text("Hetzner"))
                TextField(L("Host"), text: $server.host, prompt: Text("example.com"))
                TextField(L("User"), text: $server.user, prompt: Text("root"))
                TextField(L("Remote folder"), text: $server.path, prompt: Text("/tmp/screenshots"))
                Toggle(L("Move the local copy to the Trash after uploading"), isOn: $server.autoDelete)
            }
            HStack {
                Spacer()
                Button(L("Cancel"), action: cancel).keyboardShortcut(.cancelAction)
                Button(L("Save")) { save(server) }.keyboardShortcut(.defaultAction)
                    .disabled(server.host.isEmpty || server.user.isEmpty || server.path.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
