import Foundation

/// Where the snapshot is kept: one JSON file in the shared App Group container.
///
/// Split from the snapshot itself because this is the half that needs a real
/// Apple platform under it — `DiemSnapshot` is arithmetic and belongs with the
/// rest of the core that can be compiled and tested anywhere.
enum SnapshotStore {
    static let appGroup = "group.com.injoon5.diem"
    static let widgetKind = "DiemToday"
    static let sessionWidgetKind = "DiemSession"

    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("snapshot.json")
    }

    static func read() -> DiemSnapshot {
        guard let url, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder.diem.decode(DiemSnapshot.self, from: data)
        else { return DiemSnapshot() }
        return snapshot
    }

    @discardableResult
    static func write(_ snapshot: DiemSnapshot) -> Bool {
        guard let url, let data = try? JSONEncoder.diem.encode(snapshot) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
