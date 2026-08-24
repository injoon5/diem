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
