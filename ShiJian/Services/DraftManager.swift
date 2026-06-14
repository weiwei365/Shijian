import Foundation

class DraftManager: ObservableObject {
    @Published var drafts: [Draft] = []

    private let draftsURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShiJian/Drafts")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        loadDraftList()
    }

    func save(_ state: CanvasState, name: String? = nil) -> Bool {
        let draftName = name ?? "草稿 \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        // 覆盖同名草稿
        if let existing = drafts.first(where: { $0.name == draftName }) {
            delete(existing)
        }

        let draft = Draft(name: draftName, savedAt: Date(), canvasState: state)
        let fileURL = draftsURL.appendingPathComponent("\(draft.id.uuidString).json")

        do {
            let data = try JSONEncoder().encode(draft)
            try data.write(to: fileURL)
            loadDraftList()
            return true
        } catch {
            print("Save draft failed: \(error)")
            return false
        }
    }

    func load(_ draft: Draft) -> CanvasState? {
        let fileURL = draftsURL.appendingPathComponent("\(draft.id.uuidString).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(Draft.self, from: data)
            return loaded.canvasState
        } catch {
            print("Load draft failed: \(error)")
            return nil
        }
    }

    func delete(_ draft: Draft) {
        let fileURL = draftsURL.appendingPathComponent("\(draft.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        loadDraftList()
    }

    private func loadDraftList() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: draftsURL, includingPropertiesForKeys: nil) else {
            drafts = []
            return
        }
        drafts = files.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let draft = try? JSONDecoder().decode(Draft.self, from: data) else { return nil }
            return draft
        }.sorted { $0.savedAt > $1.savedAt }
    }
}
