import Foundation

actor ShowDetailCache {
    private var storage: [Int: Show]
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.fileURL = cacheDirectory.appendingPathComponent("show_detail_cache.json")

        if
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode([Int: Show].self, from: data)
        {
            self.storage = decoded
        } else {
            self.storage = [:]
        }
    }

    func value(for showID: Int) -> Show? {
        storage[showID]
    }

    func set(_ show: Show) {
        storage[show.id] = show
        persist()
    }

    func clear() {
        storage.removeAll()
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(storage)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to persist show detail cache: \(error.localizedDescription)")
        }
    }
}
