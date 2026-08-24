import Foundation
import Observation
import SwiftData
import WidgetKit

/// Owns the interval log and the one live session.
///
/// Everything the UI shows is derived from intervals, so there is no session
/// state to keep in sync with the database: the live session is whichever
/// `sessionID` currently has intervals and hasn't been ended.
@MainActor
@Observable
final class SessionStore {
    private let context: ModelContext
    private let settings: Settings

    /// Set while a session is running or paused; cleared on end or discard.
    private(set) var activeSessionID: UUID?
    /// Bumped whenever the log changes, so views recompute derived values.
    private(set) var revision = 0

    /// The session just finished, waiting on the Done screen.
    var finished: Session?

    init(context: ModelContext, settings: Settings = .shared) {
        self.context = context
        self.settings = settings
        self.activeSessionID = Self.recoverActiveSession(in: context)
        publishSnapshot()
    }

    // MARK: - Live session

    var isRunning: Bool { openInterval() != nil }
    var isPaused: Bool { activeSessionID != nil && openInterval() == nil }

    var activeSession: Session? {
        guard let activeSessionID else { return nil }
        return intervals(inSession: activeSessionID).sessions().first
    }

    /// Studied seconds in the live session. Paused gaps don't count.
    func elapsed(asOf now: Date = .now) -> TimeInterval {
        guard let activeSessionID else { return 0 }
        return intervals(inSession: activeSessionID).reduce(0) { $0 + $1.duration(asOf: now) }
    }

    /// Seconds left on a timed session. Negative once it rolls into overtime.
    ///
    /// The countdown measures studied time, so a pause holds it. Server-side
    /// completion (`ended_at - started_at >= planned_sec`) still agrees:
    /// wall-clock span is never shorter than studied time.
    func remaining(asOf now: Date = .now) -> TimeInterval? {
        guard let planned = activeSession?.plannedSec else { return nil }
        return Double(planned) - elapsed(asOf: now)
    }

    var activeSubjectID: UUID? { openInterval()?.subjectID ?? lastInterval()?.subjectID }

    @discardableResult
    func start(subjectID: UUID?, plannedSec: Int?, at now: Date = .now) -> UUID {
        if activeSessionID != nil { end(at: now) }
        let sessionID = UUID()
        let interval = Interval(
            sessionID: sessionID,
            subjectID: subjectID,
            startedAt: now,
            plannedSec: plannedSec
        )
        context.insert(interval)
        activeSessionID = sessionID
        settings.lastSubjectID = subjectID
        commit()
        return sessionID
    }

    func pause(at now: Date = .now) {
        guard let open = openInterval() else { return }
        open.endedAt = now
        commit()
    }

    func resume(at now: Date = .now) {
        guard let activeSessionID, openInterval() == nil else { return }
        // A new interval inherits nothing but the session and the subject.
        context.insert(
            Interval(
                sessionID: activeSessionID,
                subjectID: lastInterval()?.subjectID,
                startedAt: now
            )
        )
        commit()
    }

    /// Closes the current interval and opens the next one under a new subject.
    /// Picking the subject already running is a no-op.
    func switchSubject(to subjectID: UUID?, at now: Date = .now) {
        guard let activeSessionID else { return }
        guard let open = openInterval() else {
            // Paused: remember the choice, the next interval picks it up.
            lastInterval()?.subjectID = subjectID
            settings.lastSubjectID = subjectID
            commit()
            return
        }
        guard open.subjectID != subjectID else { return }
        open.endedAt = now
        context.insert(Interval(sessionID: activeSessionID, subjectID: subjectID, startedAt: now))
        settings.lastSubjectID = subjectID
        commit()
    }

    /// Ends the live session. Sessions under a minute are discarded silently and
    /// return `nil`.
    @discardableResult
    func end(at now: Date = .now) -> Session? {
        guard let activeSessionID else { return nil }
        let intervals = intervals(inSession: activeSessionID)
        for interval in intervals where interval.isOpen { interval.endedAt = now }
        let session = intervals.sessions(asOf: now).first
        self.activeSessionID = nil

        guard let session, session.studiedSec >= 60 else {
            for interval in intervals { context.delete(interval) }
            commit()
            return nil
        }
        commit()
        finished = session
        return session
    }

    /// Throws the live or just-finished session away — the Discard action.
    func discard(sessionID: UUID? = nil, at now: Date = .now) {
        guard let target = sessionID ?? activeSessionID ?? finished?.id else { return }
        for interval in intervals(inSession: target) { context.delete(interval) }
        if activeSessionID == target { activeSessionID = nil }
        if finished?.id == target { finished = nil }
        commit()
    }

    // MARK: - Metrics

    func seconds(from start: Date, to end: Date, asOf now: Date = .now) -> TimeInterval {
        intervals(startingIn: start..<end).reduce(0) { $0 + $1.duration(asOf: now) }
    }

    func todaySeconds(asOf now: Date = .now) -> TimeInterval {
        seconds(from: Day.start(of: now), to: now.addingTimeInterval(1), asOf: now)
    }

    var goalSeconds: TimeInterval { settings.dailyGoalSeconds }

    func todayProgress(asOf now: Date = .now) -> Double {
        goalSeconds > 0 ? todaySeconds(asOf: now) / goalSeconds : 0
    }

    /// Studied seconds per subject today, most-studied first. `nil` is free time.
    func todayBySubject(asOf now: Date = .now) -> [(subjectID: UUID?, seconds: TimeInterval)] {
        var totals: [UUID?: TimeInterval] = [:]
        for interval in intervals(startingIn: Day.start(of: now)..<now.addingTimeInterval(1)) {
            totals[interval.subjectID, default: 0] += interval.duration(asOf: now)
        }
        return totals.map { (subjectID: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }

    /// Studied seconds per study-day, oldest first.
    func dailySeconds(days: Int, asOf now: Date = .now) -> [(day: Date, seconds: TimeInterval)] {
        let starts = Day.recentStarts(from: now, count: days).reversed()
        guard let earliest = starts.first else { return [] }
        var totals: [Date: TimeInterval] = [:]
        for interval in intervals(startingIn: earliest..<now.addingTimeInterval(1)) {
            totals[Day.start(of: interval.startedAt), default: 0] += interval.duration(asOf: now)
        }
        return starts.map { (day: $0, seconds: totals[$0] ?? 0) }
    }

    /// Consecutive days with any study at all. Breaks only on a zero day; today
    /// not having started yet doesn't break it.
    func streak(asOf now: Date = .now) -> Int {
        let days = dailySeconds(days: 400, asOf: now).reversed()
        var streak = 0
        for (index, entry) in days.enumerated() {
            if entry.seconds > 0 {
                streak += 1
            } else if index == 0 {
                continue  // today is still open
            } else {
                break
            }
        }
        return streak
    }

    /// Share of the last `days` study-days that met the goal.
    func goalHitRate(days: Int = 30, asOf now: Date = .now) -> Double {
        let entries = dailySeconds(days: days, asOf: now)
        guard !entries.isEmpty, goalSeconds > 0 else { return 0 }
        let hits = entries.filter { $0.seconds >= goalSeconds }.count
        return Double(hits) / Double(entries.count)
    }

    // MARK: - Subjects

    func subjects(includeArchived: Bool = false) -> [Subject] {
        let descriptor = FetchDescriptor<Subject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.deletedAt == nil && (includeArchived || !$0.archived) }
    }

    func subject(_ id: UUID?) -> Subject? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Subject>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func addSubject(name: String, colorIndex: Int? = nil) -> Subject {
        let used = Set(subjects(includeArchived: true).map(\.colorIndex))
        let index = colorIndex ?? (0..<Palette.subjectCount).first { !used.contains($0) }
            ?? (used.count % Palette.subjectCount)
        let subject = Subject(name: name, colorIndex: index)
        context.insert(subject)
        commit()
        return subject
    }

    func update(_ subject: Subject, name: String? = nil, colorIndex: Int? = nil, archived: Bool? = nil) {
        if let name { subject.name = name }
        if let colorIndex { subject.colorIndex = colorIndex }
        if let archived { subject.archived = archived }
        subject.updatedAt = .now
        commit()
    }

    func delete(_ subject: Subject) {
        subject.deletedAt = .now
        subject.updatedAt = .now
        commit()
    }

    // MARK: - Sync

    /// Completed intervals that the server hasn't accepted yet.
    func unsyncedIntervals(limit: Int = 200) -> [Interval] {
        var descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.endedAt != nil && $0.syncedAt == nil },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func markSynced(_ ids: [UUID], at now: Date = .now) {
        let wanted = Set(ids)
        for interval in unsyncedIntervals(limit: 1000) where wanted.contains(interval.id) {
            interval.syncedAt = now
        }
        try? context.save()
    }

    /// Applies subjects pulled from the server. Last-write-wins on `updatedAt`.
    func merge(subjects incoming: [SubjectDTO]) {
        let existing = Dictionary(
            (try? context.fetch(FetchDescriptor<Subject>()))?.map { ($0.id, $0) } ?? [],
            uniquingKeysWith: { first, _ in first }
        )
        for dto in incoming {
            if let local = existing[dto.id] {
                guard dto.updatedAt > local.updatedAt else { continue }
                local.name = dto.name
                local.colorIndex = dto.colorIndex
                local.archived = dto.archived
                local.deletedAt = dto.deletedAt
                local.updatedAt = dto.updatedAt
            } else {
                context.insert(
                    Subject(
                        id: dto.id,
                        name: dto.name,
                        colorIndex: dto.colorIndex,
                        archived: dto.archived,
                        updatedAt: dto.updatedAt,
                        deletedAt: dto.deletedAt
                    )
                )
            }
        }
        commit()
    }

    // MARK: - Plumbing

    private func openInterval() -> Interval? {
        guard let activeSessionID else { return nil }
        return intervals(inSession: activeSessionID).first { $0.isOpen }
    }

    private func lastInterval() -> Interval? {
        guard let activeSessionID else { return nil }
        return intervals(inSession: activeSessionID).max { $0.startedAt < $1.startedAt }
    }

    private func intervals(inSession id: UUID) -> [Interval] {
        let descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.sessionID == id },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func intervals(startingIn range: Range<Date>) -> [Interval] {
        let (low, high) = (range.lowerBound, range.upperBound)
        let descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.startedAt >= low && $0.startedAt < high },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func commit() {
        try? context.save()
        revision &+= 1
        publishSnapshot()
    }

    private func publishSnapshot() {
        let now = Date.now
        var snapshot = DiemSnapshot(todaySec: todaySeconds(asOf: now), goalSec: goalSeconds)
        if let session = activeSession {
            let studied = session.studiedSec
            let subject = subject(activeSubjectID)
            snapshot.session = DiemSnapshot.Live(
                startedAt: session.startedAt,
                // The instant a clock started at zero would have to have begun
                // to read `studied` right now — earlier than the session start
                // by however long it spent paused.
                countingFrom: now.addingTimeInterval(-studied),
                plannedSec: session.plannedSec,
                isPaused: isPaused,
                pausedElapsedSec: studied,
                subjectName: subject?.name,
                subjectColorIndex: subject?.colorIndex
            )
        }
        SnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Reopens the session that was live when the app was last killed.
    private static func recoverActiveSession(in context: ModelContext) -> UUID? {
        var descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.sessionID
    }
}
