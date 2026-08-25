import AppIntents
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
        let now = Date.now
        let entry = SnapshotEntry(date: now, snapshot: SnapshotStore.read())
        // Live counts are rendered by the system via `Text(timerInterval:)`, so
        // the only reason to come back is a change the app didn't publish.
        let cadence = now.addingTimeInterval(entry.snapshot.session == nil ? 30 * 60 : 15 * 60)
        // …and one change the app cannot publish, because it may be asleep when
        // it happens: 4am. The day's total resets there, and on the ordinary
        // cadence a complication could go on drawing yesterday's closed ring
        // for half an hour into a day that had barely started. The snapshot now
        // carries the day it was written in, so a stale one reads as zero —
        // but reading zero still needs a redraw, and this is when to ask for it.
        let nextDay = Day.nextStart(after: now)
        completion(Timeline(entries: [entry], policy: .after(min(cadence, nextDay))))
    }

    /// What gets the session card shown in the Smart Stack at all without
    /// being added by hand, and floats it to the top once it is.
    ///
    /// The window itself is `DiemSnapshot.Live.relevanceWindow` — arithmetic,
    /// and so kept where it can be tested. What is decided here is how the
    /// system should read it. `.scheduled` rather than a plain date range:
    /// the kinds are a hint about what the card *is*, and the documented
    /// reading of this one is content that matters or wants acting on, which
    /// the system weights up accordingly. A running session with an End button
    /// on it is exactly that, and the hint is the difference between a card
    /// available in the stack and a card already in front of you.
    ///
    /// `RelevantContext` comes from RelevanceKit, which App Intents pulls in —
    /// hence the import above, which is otherwise unused in this file.
    func relevance() async -> WidgetRelevance<Void> {
        guard claimsRelevance, let session = SnapshotStore.read().session else {
            return WidgetRelevance([])
        }
        // No `configuration:` argument: the initializers that take one are
        // constrained to a `WidgetConfigurationIntent` or an `INIntent`, and
        // this widget is a `StaticConfiguration` with nothing to configure.
        // The `Configuration == ()` overload takes the context alone.
        let attribute = WidgetRelevanceAttribute<Void>(
            context: .date(range: session.relevanceWindow(), kind: .scheduled)
        )
        return WidgetRelevance([attribute])
    }
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
