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

/// One unbroken run of study on a single subject, in the order it happened.
///
/// Not a total. Switching subject and switching back is two runs on the same
/// subject, and a ring that reads as a timeline has to draw them apart — the
/// totals would put the day in the wrong order and lose the shape of it.
struct SubjectRun: Equatable {
    /// `nil` is free time.
    let subjectID: UUID?
    let seconds: TimeInterval
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
    /// The session's closed intervals as runs, in order. The one still running
    /// is added on read, the way its seconds are.
    let closedRuns: [SubjectRun]

    /// A session with no interval running is one that is paused: there is
    /// nothing else for an open interval's absence to mean.
    var isPaused: Bool { openedAt == nil }

    /// Studied seconds. Paused gaps don't count.
    func studied(asOf now: Date) -> TimeInterval {
        guard let openedAt else { return bankedSec }
        return bankedSec + max(0, now.timeIntervalSince(openedAt))
    }

    /// The session so far as runs of study, in order — what the ring behind
    /// the clock draws. Their total is `studied(asOf:)`.
    func runs(asOf now: Date) -> [SubjectRun] {
        guard let openedAt else { return closedRuns }
        let seconds = max(0, now.timeIntervalSince(openedAt))
        guard seconds > 0 else { return closedRuns }
        var runs = closedRuns
        if let last = runs.last, last.subjectID == subjectID {
            runs[runs.count - 1] = SubjectRun(
                subjectID: subjectID,
                seconds: last.seconds + seconds
            )
        } else {
            runs.append(SubjectRun(subjectID: subjectID, seconds: seconds))
        }
        return runs
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

    /// Completion is derived, not flagged — from studied time, which is what
    /// the countdown measured.
    ///
    /// This used to compare the wall-clock span, and a hold widens the gap
    /// between the two by exactly its own length. Six minutes of a planned
    /// twenty-five, held for half an hour, has a span of thirty-six and was
    /// reported Complete with the countdown still reading `19:00`. The span
    /// only ever agrees in one direction: a session that runs to term satisfies
    /// it, and a session that does not can satisfy it anyway.
    var isComplete: Bool {
        guard let plannedSec, endedAt != nil else { return false }
        return studiedSec >= Double(plannedSec)
    }

    static func == (a: Session, b: Session) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Collection where Element: IntervalRecord {
    /// Study runs in start order, with consecutive intervals on the same
    /// subject merged.
    ///
    /// A pause splits an interval but not a run: stopping for a minute and
    /// carrying on with the same book is one stretch of studying it, and
    /// drawing it as two would put a seam in the ring where nothing happened.
    func subjectRuns(asOf now: Date = .now) -> [SubjectRun] {
        var runs: [SubjectRun] = []
        for record in sorted(by: { $0.startedAt < $1.startedAt }) {
            let seconds = record.duration(asOf: now)
            guard seconds > 0 else { continue }
            if let last = runs.last, last.subjectID == record.subjectID {
                runs[runs.count - 1] = SubjectRun(
                    subjectID: last.subjectID,
                    seconds: last.seconds + seconds
                )
            } else {
                runs.append(SubjectRun(subjectID: record.subjectID, seconds: seconds))
            }
        }
        return runs
    }
}

extension Collection where Element == (day: Date, seconds: TimeInterval) {
    /// Consecutive study-days with anything in them, counting back from the
    /// most recent. Oldest first, the way `dailySeconds` hands them over.
    ///
    /// Today not having started yet does not break it. A streak you are in the
    /// middle of is still a streak, and a counter that resets every morning
    /// until you sit down is a counter nobody would trust.
    var studyStreak: Int {
        var streak = 0
        for (index, entry) in reversed().enumerated() {
            if entry.seconds > 0 {
                streak += 1
            } else if index == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }
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
            subjectID: (open ?? last).subjectID,
            closedRuns: ordered.filter { !$0.isOpen }.subjectRuns()
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
