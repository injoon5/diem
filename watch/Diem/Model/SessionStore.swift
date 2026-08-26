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
    /// A subject picked while paused. Intervals are immutable once ended, so the
    /// choice waits for the next one rather than rewriting the last.
    private(set) var pendingSubjectID: UUID??
    /// Bumped whenever the log changes.
    ///
    /// Everything a view reads here comes back from a fetch, and a fetch is
    /// invisible to observation — so every read touches this first. A body that
    /// called `subjects()` then re-runs when the next write lands, without
    /// having to know that it depends on anything.
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

    /// The live session's timing, derived once per change instead of once per
    /// frame.
    ///
    /// The clock redraws at 1Hz and the crown fires far faster than that, so
    /// the per-frame path has to be arithmetic. A fetch and a session assembly
    /// behind every read is what put SwiftData on the critical path of the
    /// numeral roll. The log only ever changes through `commit()`, so this is
    /// rebuilt there and nowhere else.
    ///
    /// Doubly optional on purpose: the outer `nil` is "not computed yet", the
    /// inner one is "computed, and nothing is running".
    @ObservationIgnored private var liveCache: LiveSummary??

    private func live() -> LiveSummary? {
        observe()
        if let liveCache { return liveCache }
        let summary = activeSessionID.flatMap { intervals(inSession: $0).liveSummary() }
        liveCache = .some(summary)
        return summary
    }

    var isRunning: Bool { live()?.openedAt != nil }
    var isPaused: Bool { live()?.isPaused ?? false }

    /// The planned length of the live session, without assembling the session
    /// to get at it — what the running clock needs once a second.
    var activePlannedSec: Int? { live()?.plannedSec }

    /// The live session as a whole value. Assembling it walks the intervals, so
    /// the per-frame path uses `elapsed` and `activePlannedSec` instead.
    var activeSession: Session? {
        guard let activeSessionID else { return nil }
        return intervals(inSession: activeSessionID).sessions().first
    }

    /// Studied seconds in the live session. Paused gaps don't count.
    func elapsed(asOf now: Date = .now) -> TimeInterval {
        live()?.studied(asOf: now) ?? 0
    }

    /// The live session as runs of study, in the order they happened. Their
    /// total is `elapsed`.
    func activeRuns(asOf now: Date = .now) -> [SubjectRun] {
        live()?.runs(asOf: now) ?? []
    }

    /// Seconds left on a timed session. Negative once it rolls into overtime.
    ///
    /// The countdown measures studied time, so a pause holds it. Server-side
    /// completion (`ended_at - started_at >= planned_sec`) still agrees:
    /// wall-clock span is never shorter than studied time.
    func remaining(asOf now: Date = .now) -> TimeInterval? {
        guard let live = live(), let planned = live.plannedSec else { return nil }
        return Double(planned) - live.studied(asOf: now)
    }

    var activeSubjectID: UUID? {
        if let pendingSubjectID { return pendingSubjectID }
        return live()?.subjectID
    }

    @discardableResult
    func start(subjectID: UUID?, plannedSec: Int?, at now: Date = .now) -> UUID {
        // Whatever was running is closed and banked, but its summary is not
        // what the user asked for — they asked for a new session. Leaving one
        // queued puts the Done screen in front of a session that is running.
        if activeSessionID != nil { end(at: now, presentingDone: false) }
        let sessionID = UUID()
        let interval = Interval(
            sessionID: sessionID,
            subjectID: subjectID,
            startedAt: now,
            plannedSec: plannedSec
        )
        context.insert(interval)
        activeSessionID = sessionID
        pendingSubjectID = nil
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
        let subjectID = pendingSubjectID ?? lastInterval()?.subjectID
        pendingSubjectID = nil
        context.insert(
            Interval(sessionID: activeSessionID, subjectID: subjectID, startedAt: now)
        )
        commit()
    }

    /// Closes the current interval and opens the next one under a new subject.
    /// Picking the subject already running is a no-op.
    func switchSubject(to subjectID: UUID?, at now: Date = .now) {
        guard let activeSessionID else { return }
        guard let open = openInterval() else {
            // Paused: remember the choice for the next interval. Rewriting the
            // closed one would edit a record the server may already hold.
            pendingSubjectID = .some(subjectID)
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
    func end(at now: Date = .now, presentingDone: Bool = true) -> Session? {
        guard let activeSessionID else { return nil }
        let intervals = intervals(inSession: activeSessionID)
        for interval in intervals where interval.isOpen { interval.endedAt = now }
        let session = intervals.sessions(asOf: now).first
        self.activeSessionID = nil
        self.pendingSubjectID = nil

        guard let session, session.studiedSec >= 60 else {
            forget(intervals)
            commit()
            return nil
        }
        commit()
        if presentingDone { finished = session }
        return session
    }

    /// Throws the live or just-finished session away — the Discard action.
    func discard(sessionID: UUID? = nil, at now: Date = .now) {
        guard let target = sessionID ?? activeSessionID ?? finished?.id else { return }
        forget(intervals(inSession: target))
        if activeSessionID == target {
            activeSessionID = nil
            pendingSubjectID = nil
        }
        if finished?.id == target { finished = nil }
        commit()
    }

    // MARK: - Metrics

    /// Study banked today by the intervals that have already closed.
    ///
    /// The Start ring reads today's total on every crown event, and the only
    /// part of it that moves between commits is the open interval — so the
    /// fetch happens once per change and the live part is added on top.
    @ObservationIgnored private var todayCache: (dayStart: Date, banked: TimeInterval)?

    func todaySeconds(asOf now: Date = .now) -> TimeInterval {
        observe()
        let dayStart = Day.start(of: now)
        let banked: TimeInterval
        if let todayCache, todayCache.dayStart == dayStart {
            banked = todayCache.banked
        } else {
            // Open-ended upper bound rather than `now`: no interval is ever
            // recorded in the future, so this is the same set of rows and the
            // answer no longer depends on the instant it was asked.
            banked = intervals(startingIn: dayStart..<Date.distantFuture)
                .reduce(into: 0) { total, interval in
                    if !interval.isOpen { total += interval.duration() }
                }
            todayCache = (dayStart, banked)
        }
        guard let live = live(), let openedAt = live.openedAt, openedAt >= dayStart else {
            return banked
        }
        return banked + max(0, now.timeIntervalSince(openedAt))
    }

    var goalSeconds: TimeInterval { settings.dailyGoalSeconds }

    func todayProgress(asOf now: Date = .now) -> Double {
        goalSeconds > 0 ? todaySeconds(asOf: now) / goalSeconds : 0
    }

    /// Studied seconds per subject today, most-studied first. `nil` is free time.
    func todayBySubject(asOf now: Date = .now) -> [SubjectTotal] {
        observe()
        var totals: [UUID?: TimeInterval] = [:]
        for interval in intervals(startingIn: Day.start(of: now)..<now.addingTimeInterval(1)) {
            totals[interval.subjectID, default: 0] += interval.duration(asOf: now)
        }
        return totals.map { SubjectTotal(subjectID: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }

    /// Closed-interval totals per study-day, oldest first, held between reads.
    ///
    /// Metrics asks for the same window several times while it lays itself out,
    /// and the aggregation walks a quarter of a year of intervals and as many
    /// calendar additions. Doing that once per change instead of once per body
    /// is the difference between the sheet sliding in and the sheet hitching.
    ///
    /// Held per window rather than one slot for the last one asked: two callers
    /// wanting different spans would otherwise evict each other on every read
    /// and neither would ever hit.
    @ObservationIgnored private var dailyCacheDay: Date?
    @ObservationIgnored private var dailyCache: [Int: [(day: Date, seconds: TimeInterval)]] = [:]

    /// Studied seconds per study-day, oldest first.
    func dailySeconds(days: Int, asOf now: Date = .now) -> [(day: Date, seconds: TimeInterval)] {
        observe()
        let dayStart = Day.start(of: now)
        if dailyCacheDay != dayStart {
            dailyCacheDay = dayStart
            dailyCache.removeAll(keepingCapacity: true)
        }
        var entries: [(day: Date, seconds: TimeInterval)]
        if let cached = dailyCache[days] {
            entries = cached
        } else {
            let starts = Array(Day.recentStarts(from: now, count: days).reversed())
            guard let earliest = starts.first else { return [] }
            var totals: [Date: TimeInterval] = [:]
            for interval in intervals(startingIn: earliest..<Date.distantFuture) where !interval.isOpen {
                totals[Day.start(of: interval.startedAt), default: 0] += interval.duration()
            }
            entries = starts.map { (day: $0, seconds: totals[$0] ?? 0) }
            dailyCache[days] = entries
        }
        // The one interval the cache can't hold: the one still running.
        guard let live = live(), let openedAt = live.openedAt else { return entries }
        let day = Day.start(of: openedAt)
        guard let index = entries.firstIndex(where: { $0.day == day }) else { return entries }
        entries[index].seconds += max(0, now.timeIntervalSince(openedAt))
        return entries
    }

    /// Consecutive days with any study at all.
    ///
    /// A year and a bit of window: long enough that the number is the real one
    /// rather than the one the window can see.
    func streak(asOf now: Date = .now) -> Int {
        dailySeconds(days: 400, asOf: now).studyStreak
    }

    /// Share of the last `days` study-days that met the goal.
    func goalHitRate(days: Int = 30, asOf now: Date = .now) -> Double {
        let entries = dailySeconds(days: days, asOf: now)
        guard !entries.isEmpty, goalSeconds > 0 else { return 0 }
        let hits = entries.filter { $0.seconds >= goalSeconds }.count
        return Double(hits) / Double(entries.count)
    }

    // MARK: - Subjects

    /// The subject list is read several times per body — a picker asks for it
    /// twice, a toolbar button once for the name and once for the colour — and
    /// it only changes when something writes. One fetch per change covers all
    /// of them; `revision` is what invalidates it.
    @ObservationIgnored private var subjectListCache: [Bool: [Subject]] = [:]
    @ObservationIgnored private var subjectCache: [UUID: Subject?] = [:]

    func subjects(includeArchived: Bool = false) -> [Subject] {
        observe()
        if let cached = subjectListCache[includeArchived] { return cached }
        let descriptor = FetchDescriptor<Subject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let visible = all.filter { $0.deletedAt == nil && (includeArchived || !$0.archived) }
        subjectListCache[includeArchived] = visible
        return visible
    }

    func subject(_ id: UUID?) -> Subject? {
        observe()
        guard let id else { return nil }
        // Misses are cached too: the running screen asks once a second, and a
        // subject that isn't there is exactly as stable as one that is.
        if let cached = subjectCache[id] { return cached }
        var descriptor = FetchDescriptor<Subject>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let found = try? context.fetch(descriptor).first
        subjectCache[id] = .some(found)
        return found
    }

    /// Whether a name is already taken, ignoring case and surrounding space.
    ///
    /// Two subjects called "Maths" are two identical rows in the picker, and
    /// the only thing telling them apart is a colour — which this app does not
    /// allow to carry meaning alone, because a complication may be monochrome.
    /// Cheaper to refuse than to disambiguate.
    func isNameTaken(_ name: String, excluding id: UUID? = nil) -> Bool {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !wanted.isEmpty else { return false }
        return subjects(includeArchived: true).contains {
            $0.id != id && $0.name.trimmingCharacters(in: .whitespaces).lowercased() == wanted
        }
    }

    @discardableResult
    func addSubject(name: String, colorIndex: Int? = nil) -> Subject {
        let subject = Subject(name: name, colorIndex: colorIndex ?? nextColorIndex())
        context.insert(subject)
        commit()
        return subject
    }

    /// The first unused palette slot, or — once all ten are spoken for — the
    /// least-used one.
    ///
    /// The fallback used to be `used.count % count`, which with ten subjects is
    /// zero: the eleventh subject was guaranteed to take the first one's colour
    /// rather than whichever was least crowded.
    private func nextColorIndex() -> Int {
        var counts = [Int](repeating: 0, count: Palette.subjectCount)
        for subject in subjects(includeArchived: true) {
            let index = ((subject.colorIndex % Palette.subjectCount) + Palette.subjectCount)
                % Palette.subjectCount
            counts[index] += 1
        }
        // `min(by:)` keeps the earliest index on a tie, so an empty palette
        // still hands them out in order.
        return counts.indices.min { counts[$0] < counts[$1] } ?? 0
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

    /// Every subject the server should know about, tombstones included.
    ///
    /// `subjects(includeArchived:)` filters `deletedAt` before it even looks at
    /// `archived`, which is right for every screen and wrong for the wire: a
    /// deleted subject was excluded from every push, so it lived on the web
    /// forever. `deletedAt` is precisely what the wire format carries.
    func subjectsForSync() -> [Subject] {
        observe()
        return (try? context.fetch(FetchDescriptor<Subject>())) ?? []
    }

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
        // A pull that changes nothing is the normal case, and committing it
        // anyway would bump the revision and re-run every body on screen.
        var changed = false
        for dto in incoming {
            if let local = existing[dto.id] {
                guard dto.updatedAt > local.updatedAt else { continue }
                changed = true
                local.name = dto.name
                local.colorIndex = dto.colorIndex
                local.archived = dto.archived
                local.deletedAt = dto.deletedAt
                local.updatedAt = dto.updatedAt
            } else {
                changed = true
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
        guard changed else { return }
        commit()
    }

    // MARK: - Plumbing

    /// Deletes intervals, remembering the ids of any the server already holds.
    ///
    /// There is no row left to carry a tombstone once it is gone, and the
    /// interval API has no delete for something it was never told about — so
    /// only what was actually pushed is recorded, and the next sync un-tells it.
    private func forget(_ intervals: [Interval]) {
        settings.recordDeleted(intervalIDs: intervals.filter { $0.syncedAt != nil }.map(\.id))
        for interval in intervals { context.delete(interval) }
    }

    private func openInterval() -> Interval? {
        guard let activeSessionID else { return nil }
        return intervals(inSession: activeSessionID).first { $0.isOpen }
    }

    private func lastInterval() -> Interval? {
        guard let activeSessionID else { return nil }
        return intervals(inSession: activeSessionID).max { $0.startedAt < $1.startedAt }
    }

    private func intervals(inSession id: UUID) -> [Interval] {
        observe()
        let descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.sessionID == id },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func intervals(startingIn range: Range<Date>) -> [Interval] {
        observe()
        let (low, high) = (range.lowerBound, range.upperBound)
        let descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.startedAt >= low && $0.startedAt < high },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Registers the caller's dependency on the log. Reading a tracked property
    /// inside a fetch is what makes an `@Observable` store work at all when the
    /// data itself lives in SwiftData.
    private func observe() { _ = revision }

    private func commit() {
        try? context.save()
        revision &+= 1
        invalidateCaches()
        publishSnapshot()
        rescheduleAlert()
    }

    /// Everything derived from the log, dropped in one place.
    ///
    /// `markSynced` is the one write that doesn't come through `commit()`, and
    /// it is exempt because nothing derived reads `syncedAt` — it decides only
    /// what the next push sends. Any other write must come through here.
    private func invalidateCaches() {
        liveCache = nil
        todayCache = nil
        dailyCache.removeAll(keepingCapacity: true)
        subjectListCache.removeAll(keepingCapacity: true)
        subjectCache.removeAll(keepingCapacity: true)
    }

    /// One place decides whether a tap is pending: a timed session that is
    /// actually running, and nothing else.
    ///
    /// Past the deadline still counts. The session is in overtime, not over,
    /// and the nudge that asks whether it was forgotten is still ahead of it.
    private func rescheduleAlert() {
        guard isRunning, let remaining = remaining() else {
            SessionAlerts.cancel()
            return
        }
        SessionAlerts.schedule(
            deadline: Date.now.addingTimeInterval(remaining),
            subject: subject(activeSubjectID)?.name
        )
    }

    /// Re-reads the log after another process may have written to it.
    ///
    /// The app and the widget extension each hold one of these, and each drops
    /// its caches only in its own `commit()`. Nothing arrives from the other
    /// side, so both had to be told when to stop trusting themselves. Ending a
    /// session from the Smart Stack card used to leave the app on a stopped
    /// clock labelled "Paused" — a session with no open interval, as far as the
    /// screen could tell — and resuming spliced a live interval into a session
    /// that had already ended.
    ///
    /// Called when the app becomes active, and at the top of every intent.
    /// Cheap when nothing changed: the fetch is indexed, and an unchanged
    /// snapshot is never written.
    func refresh() {
        // Discards the context's registered objects so the next fetch reads the
        // store rather than answering from memory. There is never anything
        // unsaved to lose — every write here saves immediately.
        context.rollback()
        let recovered = Self.recoverActiveSession(in: context)
        let changed = recovered != activeSessionID
        activeSessionID = recovered
        revision &+= 1
        invalidateCaches()
        if changed {
            pendingSubjectID = nil
            // A summary queued before the log moved under us is about a session
            // this store no longer knows the shape of — and if what changed is
            // that a session *started* elsewhere, showing it would put a summary
            // in front of a session that is running, which is the one thing
            // `start()` goes out of its way to prevent.
            finished = nil
        }
        publishSnapshot()
        rescheduleAlert()
    }

    /// Re-publishes to the widgets after something outside the interval log
    /// changed — the daily goal is the only such input.
    func refreshSnapshot() { publishSnapshot() }

    /// The last snapshot handed to the widgets, so an unchanged one is never
    /// written again.
    private var publishedSnapshot: DiemSnapshot?

    private func publishSnapshot() {
        let now = Date.now
        // What's already banked today, excluding the live session — the widget
        // adds the running count itself, so its gauge doesn't freeze between
        // timeline refreshes.
        let summary = live()
        let banked = todaySeconds(asOf: now) - (summary?.studied(asOf: now) ?? 0)
        var snapshot = DiemSnapshot(todaySec: max(0, banked), goalSec: goalSeconds)
        // Which day that total belongs to. Without it a complication holding a
        // snapshot written before 4am has no way to tell that the day has
        // turned, and draws yesterday's closed ring on a day that just started.
        snapshot.dayStart = Day.start(of: now)
        if let session = summary {
            let studied = session.studied(asOf: now)
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
        guard snapshot != publishedSnapshot else { return }
        // A timeline reload is not a relevance reload: the system re-asks the
        // provider what it is drawing, not whether the Smart Stack should be
        // offering it at all. Without this the card is surfaced whenever the
        // system next gets round to asking, which is no use for something whose
        // whole claim is that it started just now — and a session that has
        // ended goes on claiming the stack until the same late answer.
        //
        // Only two things move the claim: whether a session is live, and where
        // it ends. Everything else that rewrites the snapshot — a subject
        // switch, a minute passing — must not spend the wake.
        let wasLive = publishedSnapshot?.session != nil
        let isLive = snapshot.session != nil
        let relevanceChanged = wasLive != isLive
            || publishedSnapshot?.session?.deadline != snapshot.session?.deadline
        publishedSnapshot = snapshot
        // Writing the file and waking `chronod` are both blocking calls, and
        // `commit()` runs them on the same tap that started the session. Off
        // the main actor they cost the tap nothing.
        Task.detached(priority: .utility) {
            SnapshotStore.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            if relevanceChanged {
                WidgetCenter.shared.invalidateRelevance(ofKind: SnapshotStore.widgetKind)
            }
        }
    }

    /// The longest an interval can plausibly run before the only explanation is
    /// that the app went away while it was open.
    private static let maxPlausibleInterval: TimeInterval = 12 * 3600

    /// Reopens the session that was live when the app last went away.
    ///
    /// An interval left open for longer than anyone studies is not a session
    /// still running — it is one the app never got to close. It is closed at its
    /// own start rather than credited with the hours in between; inventing study
    /// time is worse than losing it.
    ///
    /// Exactly one interval may be open, and only in the session being
    /// recovered. Any other is an orphan of a launch that never got to close
    /// it, and an orphan is not harmless: an open interval is measured against
    /// `now` wherever the log is read whole, so it would go on growing against
    /// today's per-subject totals for as long as the install lasts.
    private static func recoverActiveSession(in context: ModelContext) -> UUID? {
        let descriptor = FetchDescriptor<Interval>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let open = (try? context.fetch(descriptor)) ?? []
        guard let latest = open.first else { return nil }

        let isStale = Date.now.timeIntervalSince(latest.startedAt) > maxPlausibleInterval
        let survivor = isStale ? nil : latest
        for interval in open where interval.id != survivor?.id {
            interval.endedAt = interval.startedAt
        }
        if survivor == nil || open.count > 1 { try? context.save() }

        return survivor?.sessionID
    }
}
