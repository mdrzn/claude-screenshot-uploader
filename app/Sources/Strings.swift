// Testi: inglese nel codice, italiano se la lingua di sistema e' l'italiano.
import Foundation

// --lang en|it forza la lingua (es. per gli screenshot del README)
let italian: Bool = {
    let a = CommandLine.arguments
    if let i = a.firstIndex(of: "--lang"), i + 1 < a.count { return a[i + 1] == "it" }
    return (Locale.preferredLanguages.first ?? "en").hasPrefix("it")
}()

func L(_ s: String) -> String { italian ? (it[s] ?? s) : s }
func L(_ s: String, _ args: CVarArg...) -> String { String(format: L(s), arguments: args) }

private let it: [String: String] = [
    "Can't watch %@": "Impossibile sorvegliare %@",
    "Nothing to upload": "Niente da caricare",
    "The clipboard doesn't contain an image or a file.": "Negli appunti non c'è un'immagine né un file.",
    "No screenshots": "Nessuno screenshot",
    "The folder %@ is empty.": "La cartella %@ è vuota.",
    "No server configured": "Nessun server configurato",
    "Upload failed": "Upload non riuscito",
    "Add a server in Settings first.": "Aggiungi prima un server nelle impostazioni.",
    "Path copied": "Percorso copiato",
    "unknown error": "errore sconosciuto",
    "Could not upload to %@: %@": "Impossibile caricare su %@: %@",
    "Uploading %@…": "Caricamento di %@…",
    "Uploads to %@": "Carica su %@",
    "Upload clipboard image": "Carica l'immagine negli appunti",
    "Upload latest screenshot": "Carica l'ultimo screenshot",
    "Upload files…": "Carica file…",
    "Recent uploads — click to copy the path": "Ultimi upload — clic per copiare il percorso",
    "Server": "Server",
    "Upload new screenshots automatically": "Carica automaticamente i nuovi screenshot",
    "Upload copied images automatically": "Carica automaticamente le immagini copiate",
    "Open screenshots folder": "Apri la cartella degli screenshot",
    "Settings…": "Impostazioni…",
    "Quit": "Esci",
    "The previous version (shell + xbar) is still active": "La versione precedente (shell + xbar) è ancora attiva",
    "Turn it off so screenshots aren't uploaded twice. Its LaunchAgent and xbar plugin are moved to ~/.claude-screenshot-uploader/legacy-backup, so you can restore them.":
        "Disattivala per non caricare gli screenshot due volte. Il suo LaunchAgent e il plugin di xbar vengono spostati in ~/.claude-screenshot-uploader/legacy-backup, così puoi ripristinarli.",
    "Turn off the previous version": "Disattiva la versione precedente",
    "Servers": "Server",
    "Test": "Prova",
    "Connecting…": "Connessione…",
    "SSH connection works": "Connessione SSH funzionante",
    "Connection failed": "Connessione non riuscita",
    "Edit": "Modifica",
    "Add server": "Aggiungi server",
    "Uploads use your SSH keys (as with ssh in Terminal). No passwords are asked for or stored.":
        "Gli upload usano le tue chiavi SSH (come ssh nel Terminale). Nessuna password viene chiesta o salvata.",
    "Screenshots": "Screenshot",
    "Change…": "Cambia…",
    "⌥⌘U uploads the clipboard image": "⌥⌘U carica l'immagine negli appunti",
    "Open at login": "Apri al login",
    "Tip: drop any file on the menu bar icon to upload it. Click a recent upload in the menu to copy its path again.":
        "Suggerimento: trascina un file qualsiasi sull'icona nella barra dei menu per caricarlo. Clic su un upload recente nel menu per ricopiarne il percorso.",
    "New server": "Nuovo server",
    "Name": "Nome", "Host": "Host", "User": "Utente", "Remote folder": "Cartella remota",
    "Move the local copy to the Trash after uploading": "Sposta la copia locale nel Cestino dopo l'upload",
    "Cancel": "Annulla", "Save": "Salva",
]
