import WidgetKit

/// Complications read the snapshot the app leaves in the shared container, so a
/// refresh never has to open the database.
struct SnapshotEntry: TimelineEntry {
    var date: Date
    var snapshot: DiemSnapshot

    static let placeholder = SnapshotEntry(
        date: .now,
        snapshot: DiemSnapshot(todaySec: 72 * 60, goalSec: 120 * 60)
    )
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: SnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SnapshotStore.read())
        // Live counts are rendered by the system via `Text(timerInterval:)`, so
        // the only reason to come back is a change the app didn't publish.
        let next = Date.now.addingTimeInterval(entry.snapshot.session == nil ? 30 * 60 : 15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension DiemSnapshot {
    /// `accessoryCircular` centre text fits about four characters, so the
    /// decimal goes past ten hours.
    var compactToday: String {
        let hours = todaySec / 3600
        if todaySec < 3600 { return "\(Int(todaySec / 60))m" }
        if hours >= 10 { return "\(Int(hours))h" }
        return String(format: "%.1fh", (todaySec / 360).rounded(.down) / 10)
    }

    var inlineToday: String { "\(compactToday) studied" }
}
