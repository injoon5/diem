import Foundation

/// The shape of an interval, without SwiftData attached.
///
/// Session assembly is pure arithmetic over the log, so it lives behind a
/// protocol: the persisted `Interval` conforms, and so can a plain value in a
/// test.
protocol IntervalRecord {
    var sessionID: UUID { get }
    var subjectID: UUID? { get }
    var startedAt: Date { get }
    var endedAt: Date? { get }
    var plannedSec: Int? { get }
}

extension IntervalRecord {
    var isOpen: Bool { endedAt == nil }

    /// Seconds counted so far. An open interval is measured against `now`.
    func duration(asOf now: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }
}

/// Studied seconds under one subject. `nil` is free time — a real row, so it
/// carries a non-optional `id`: an optional identity is not something SwiftUI's
/// `ForEach` diffing survives.
struct SubjectTotal: Identifiable, Hashable {
    let subjectID: UUID?
    let seconds: TimeInterval

    var id: String { subjectID?.uuidString ?? "free" }
}

/// The live session's timing, without assembling the session around it.
///
/// The running clock reads this once a second and the crown asks far faster
/// than that, so it has to be arithmetic over a value the store already holds
/// rather than a walk of the log per read. It agrees with `sessions()` by
/// construction: `studied(asOf:)` is that session's `studiedSec`.
struct LiveSummary: Equatable {
    let startedAt: Date
    /// Studied seconds in the intervals that have already closed.
    let bankedSec: TimeInterval
    /// Start of the open interval — `nil` while paused.
    let openedAt: Date?
    let plannedSec: Int?
    /// Subject of the open interval, or of the last one while paused.
    let subjectID: UUID?

    /// A session with no interval running is one that is paused: there is
    /// nothing else for an open interval's absence to mean.
    var isPaused: Bool { openedAt == nil }

    /// Studied seconds. Paused gaps don't count.
    func studied(asOf now: Date) -> TimeInterval {
        guard let openedAt else { return bankedSec }
        return bankedSec + max(0, now.timeIntervalSince(openedAt))
    }
}

/// A session assembled from its intervals. Derived, never stored.
struct Session: Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let plannedSec: Int?
    /// Studied seconds — the sum of the intervals, excluding paused gaps.
    let studiedSec: TimeInterval
    /// Per-subject studied seconds, most-studied first. A `nil` key is free time.
    let bySubject: [SubjectTotal]
    /// What was being studied when the session ended — what "Again" repeats.
    let lastSubjectID: UUID?
    let intervalCount: Int

    /// Completion is derived, not flagged.
    var isComplete: Bool {
        guard let plannedSec, let endedAt else { return false }
        return endedAt.timeIntervalSince(startedAt) >= Double(plannedSec)
    }

    static func == (a: Session, b: Session) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Collection where Element: IntervalRecord {
    /// The timing of one session's intervals, or `nil` if there are none.
    ///
    /// Only the closed intervals are summed. The open one is left as the
    /// instant it began so the count can be read at any `now` without touching
    /// the log again.
    func liveSummary() -> LiveSummary? {
        let ordered = sorted { $0.startedAt < $1.startedAt }
        guard let first = ordered.first, let last = ordered.last else { return nil }
        let open = ordered.first { $0.isOpen }
        var banked: TimeInterval = 0
        for record in ordered where !record.isOpen { banked += record.duration() }
        return LiveSummary(
            startedAt: first.startedAt,
            bankedSec: banked,
            openedAt: open?.startedAt,
            // Set on the first interval of a timed session only.
            plannedSec: first.plannedSec,
            subjectID: (open ?? last).subjectID
        )
    }

    /// Group a flat interval log into sessions, most recent first.
    func sessions(asOf now: Date = .now) -> [Session] {
        Dictionary(grouping: self, by: \.sessionID)
            .values
            .compactMap { group -> Session? in
                let ordered = group.sorted { $0.startedAt < $1.startedAt }
                guard let first = ordered.first, let last = ordered.last else { return nil }
                // A session is over only once every one of its intervals is.
                let ended = ordered.contains(where: \.isOpen)
                    ? nil
                    : ordered.compactMap(\.endedAt).max()
                var totals: [UUID?: TimeInterval] = [:]
                for record in ordered {
                    totals[record.subjectID, default: 0] += record.duration(asOf: now)
                }
                return Session(
                    id: first.sessionID,
                    startedAt: first.startedAt,
                    endedAt: ended,
                    plannedSec: first.plannedSec,
                    studiedSec: ordered.reduce(0) { $0 + $1.duration(asOf: now) },
                    bySubject: totals
                        .map { SubjectTotal(subjectID: $0.key, seconds: $0.value) }
                        .sorted { $0.seconds > $1.seconds },
                    lastSubjectID: last.subjectID,
                    intervalCount: ordered.count
                )
            }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
