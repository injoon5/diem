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
}

extension Interval: IntervalRecord {}

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
