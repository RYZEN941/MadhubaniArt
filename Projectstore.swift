import SwiftUI
import UIKit
import PencilKit

// MARK: - Saved Project

struct SavedProject: Identifiable, Codable {
    var id         = UUID()
    var title      : String
    var createdAt  : Date   = Date()
    var thumbFile  : String = ""    // PNG thumbnail in Documents
    var drawFile   : String = ""    // PKDrawing binary in Documents
    var motifsFile : String = ""    // JSON [MotifInstance] in Documents
    var isAutosave : Bool   = false // true = crash-recovery slot
}

// MARK: - ProjectStore

@MainActor
class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published var projects: [SavedProject] = []

    private let metaKey = "mithila_projects_v3"
    private let docs: URL = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]

    init() { load() }

    // ── Save (create or overwrite) ────────────────────────────────────────
    func save(title:String, thumbnail:UIImage, drawing:PKDrawing,
              motifs:[MotifInstance], existingID:UUID? = nil, isAutosave:Bool = false) {

        // Remove previous entry with same id
        if let eid = existingID, let idx = projects.firstIndex(where:{$0.id==eid}) {
            cleanFiles(projects[idx]); projects.remove(at:idx)
        }

        var p = SavedProject(title:title, isAutosave:isAutosave)
        if let eid = existingID { p.id = eid }

        let base   = p.id.uuidString
        p.thumbFile  = "thumb_\(base).png"
        p.drawFile   = "draw_\(base).pkd"
        p.motifsFile = "motifs_\(base).json"

        if let data = thumbnail.jpegData(compressionQuality:0.5) {    // JPEG saves space
            try? data.write(to:docs.appendingPathComponent(p.thumbFile))
        }
        if let data = try? drawing.dataRepresentation() {
            try? data.write(to:docs.appendingPathComponent(p.drawFile))
        }
        if let data = try? JSONEncoder().encode(motifs) {
            try? data.write(to:docs.appendingPathComponent(p.motifsFile))
        }

        projects.insert(p, at:0)
        persist()
    }

    // ── Load drawing + motifs ─────────────────────────────────────────────
    func loadDrawing(for p:SavedProject) -> PKDrawing? {
        guard !p.drawFile.isEmpty,
              let data = try? Data(contentsOf:docs.appendingPathComponent(p.drawFile))
        else { return nil }
        return try? PKDrawing(data:data)
    }

    func loadMotifs(for p:SavedProject) -> [MotifInstance] {
        guard !p.motifsFile.isEmpty,
              let data = try? Data(contentsOf:docs.appendingPathComponent(p.motifsFile))
        else { return [] }
        return (try? JSONDecoder().decode([MotifInstance].self, from:data)) ?? []
    }

    // ── Thumbnail ─────────────────────────────────────────────────────────
    func thumbnail(for p:SavedProject) -> UIImage? {
        guard !p.thumbFile.isEmpty,
              let data = try? Data(contentsOf:docs.appendingPathComponent(p.thumbFile))
        else { return nil }
        return UIImage(data:data)
    }

    // ── Title uniqueness ──────────────────────────────────────────────────
    func isNameTaken(_ name:String, excludingID:UUID? = nil) -> Bool {
        projects.contains { p in
            p.title.lowercased() == name.lowercased() &&
            p.id != excludingID && !p.isAutosave
        }
    }

    // ── Delete ────────────────────────────────────────────────────────────
    func delete(_ p:SavedProject) { cleanFiles(p); projects.removeAll{$0.id==p.id}; persist() }

    var autosave: SavedProject? { projects.first(where:{$0.isAutosave}) }

    // ── Persistence ───────────────────────────────────────────────────────
    private func persist() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey:metaKey)
        }
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey:metaKey),
              let decoded = try? JSONDecoder().decode([SavedProject].self, from:data)
        else { return }
        projects = decoded
    }
    private func cleanFiles(_ p:SavedProject) {
        for f in [p.thumbFile,p.drawFile,p.motifsFile] where !f.isEmpty {
            try? FileManager.default.removeItem(at:docs.appendingPathComponent(f))
        }
    }
}
