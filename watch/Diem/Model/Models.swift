import Foundation
import SwiftData

/// A contiguous stretch of study with one subject.
///
/// Intervals are the only durable record. A session is nothing more than the
/// intervals that share a `sessionID`: switching subject or pausing closes the
/// current interval and opens the next one, so the log stays append-only and an
/// interval is immutable once `endedAt` is set.
@Model
final class Interval {
    #Index<Interval>([\.startedAt], [\.sessionID])

    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    /// `nil` marks a free session — nothing else does.
    var subjectID: UUID?
    var startedAt: Date
    var endedAt: Date?
    /// Set on the first interval of a timed session only.
    var plannedSec: Int?
    /// Set once the interval has been accepted by the server.
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        subjectID: UUID? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        plannedSec: Int? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.subjectID = subjectID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSec = plannedSec
    }

    var isOpen: Bool { endedAt == nil }

    /// Seconds counted so far. An open interval is measured against `now`.
    func duration(asOf now: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }
}

/// The one mutable entity: last-write-wins on `updatedAt`, soft delete via
/// `deletedAt`. Archiving hides a subject from the picker and keeps its history.
@Model
final class Subject {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorIndex: Int
    var archived: Bool
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        colorIndex: Int,
        archived: Bool = false,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.archived = archived
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var isVisible: Bool { !archived && deletedAt == nil }
}

/// A session assembled from its intervals. Derived, never stored.
struct Session: Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let plannedSec: Int?
    /// Studied seconds — the sum of the intervals, excluding paused gaps.
    let studiedSec: TimeInterval
    /// Per-subject studied seconds, most-studied first. `nil` key is free time.
    let bySubject: [(subjectID: UUID?, seconds: TimeInterval)]
    let intervalCount: Int

    /// Completion is derived, not flagged.
    var isComplete: Bool {
        guard let plannedSec, let endedAt else { return false }
        return endedAt.timeIntervalSince(startedAt) >= Double(plannedSec)
    }

    static func == (a: Session, b: Session) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == Interval {
    /// Group a flat interval log into sessions, most recent first.
    func sessions(asOf now: Date = .now) -> [Session] {
        Dictionary(grouping: self, by: \.sessionID)
            .values
            .compactMap { group -> Session? in
                let ordered = group.sorted { $0.startedAt < $1.startedAt }
                guard let first = ordered.first else { return nil }
                let ended = ordered.contains(where: \.isOpen)
                    ? nil
                    : ordered.compactMap(\.endedAt).max()
                var totals: [UUID?: TimeInterval] = [:]
                for interval in ordered {
                    totals[interval.subjectID, default: 0] += interval.duration(asOf: now)
                }
                return Session(
                    id: first.sessionID,
                    startedAt: first.startedAt,
                    endedAt: ended,
                    plannedSec: first.plannedSec,
                    studiedSec: ordered.reduce(0) { $0 + $1.duration(asOf: now) },
                    bySubject: totals
                        .map { (subjectID: $0.key, seconds: $0.value) }
                        .sorted { $0.seconds > $1.seconds },
                    intervalCount: ordered.count
                )
            }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
