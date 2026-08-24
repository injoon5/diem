import Foundation
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
    /// Only the session card asks the Smart Stack for room. The Today
    /// complication is something you go and look at; a running session is the
    /// one thing here worth putting in front of you unasked.
    var claimsRelevance = false

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

    /// What floats the session card to the top of the Smart Stack — and gets it
    /// shown at all without being added by hand.
    ///
    /// A relevance is a window, so the session has to claim one that outlives
    /// the reload that published it: a timed session claims through to its
    /// deadline, and an open-ended one a rolling window longer than the
    /// refresh cadence above, extended by each reload while it keeps running.
    /// The app reloads on every state change, so the window opens on the tap
    /// that starts the session and is gone by the next reload after it ends.
    func relevance() async -> WidgetRelevance<Void> {
        guard claimsRelevance, let session = SnapshotStore.read().session else {
            return WidgetRelevance([])
        }
        let now = Date.now
        let end = max(session.deadline ?? .distantPast, now.addingTimeInterval(Self.relevanceWindow))
        // Spelled with the configuration rather than the `Void` shorthand: this
        // widget is a `StaticConfiguration`, so there is nothing to configure.
        let attribute = WidgetRelevanceAttribute<Void>(
            configuration: (),
            context: .date(from: now, to: end)
        )
        return WidgetRelevance([attribute])
    }

    /// Comfortably longer than the running session's refresh interval, so the
    /// window never lapses in the gap between two reloads.
    private static let relevanceWindow: TimeInterval = 20 * 60
}

extension DiemSnapshot {
    /// `accessoryCircular` centre text fits about four characters, so the
    /// decimal goes past ten hours.
    func compactToday(asOf now: Date = .now) -> String {
        let seconds = today(asOf: now)
        let hours = seconds / 3600
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if hours >= 10 { return "\(Int(hours))h" }
        return String(format: "%.1fh", (seconds / 360).rounded(.down) / 10)
    }

    func inlineToday(asOf now: Date = .now) -> String { "\(compactToday(asOf: now)) studied" }
}
