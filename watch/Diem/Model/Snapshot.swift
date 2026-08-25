import Foundation

/// One reading against the goal, lapped.
///
/// Past the goal the reading doesn't stop, it laps: the pass already completed
/// dims and the overflow draws over the top of it. The ring on the watch and
/// the bar on the complication are the same reading in two shapes, so what each
/// of them draws is decided here rather than worked out twice.
struct Lap: Equatable {
    /// Total revolutions. 1.0 is the goal met exactly.
    let turns: Double

    init(turns: Double) { self.turns = max(0, turns) }

    /// Exactly one turn is a full reading, not a lap: the dimmed pass beneath
    /// the overflow only appears once there is something to draw over it.
    var isLapped: Bool { turns > 1 }

    /// How far along the track the leading edge sits, 0 to 1.
    var fraction: Double {
        guard turns > 0 else { return 0 }
        guard isLapped else { return min(turns, 1) }
        let remainder = turns - turns.rounded(.down)
        // A whole number of laps is a full track, not an empty one.
        return remainder == 0 ? 1 : remainder
    }
}

/// What the widget and complications read.
///
/// The app owns the SwiftData store; the extensions get a small JSON file in
/// the shared App Group container instead. It is rewritten on every state
/// change, so a complication never has to open the database.
struct DiemSnapshot: Codable, Equatable, Sendable {
    /// Study banked today, not counting the live session.
    var todaySec: Double = 0
    var goalSec: Double = 2 * 3600
    /// Set while a session is running or paused.
    var session: Live?
    /// The study-day `todaySec` was banked in.
    ///
    /// Without it a complication holding a snapshot written at 03:50 has no way
    /// to notice that 04:00 has passed, and goes on drawing yesterday's total —
    /// and yesterday's closed ring — as today's, for as long as half an hour.
    /// Optional so a snapshot written by an older build still decodes; `nil`
    /// means "unknown", which is read as "not stale" rather than as zero.
    var dayStart: Date?

    struct Live: Codable, Equatable, Sendable {
        var startedAt: Date
        /// The instant the count should read now — start of the running
        /// interval minus everything already banked in this session.
        var countingFrom: Date
        var plannedSec: Int?
        var isPaused: Bool
        var pausedElapsedSec: Double
        var subjectName: String?
        var subjectColorIndex: Int?

        /// End instant of a timed session, for `Text(timerInterval:)`.
        var deadline: Date? {
            guard let plannedSec else { return nil }
            return countingFrom.addingTimeInterval(Double(plannedSec))
        }

        func elapsed(asOf now: Date = .now) -> TimeInterval {
            isPaused ? pausedElapsedSec : max(0, now.timeIntervalSince(countingFrom))
        }

        /// The part of this session's count that falls after `floor`.
        ///
        /// A session counts toward the day it started in, so when the reader has
        /// crossed a day boundary the session has not — only the seconds on this
        /// side of it belong to the new day. A held session stopped counting at
        /// `countingFrom + pausedElapsedSec`, so its share is whatever of that
        /// lies past the floor, which for a hold that began before the boundary
        /// is nothing.
        func elapsed(asOf now: Date = .now, notBefore floor: Date) -> TimeInterval {
            let from = max(countingFrom, floor)
            let to = isPaused ? countingFrom.addingTimeInterval(pausedElapsedSec) : now
            return max(0, to.timeIntervalSince(from))
        }

        /// The window the Smart Stack is asked to hold the session card in.
        ///
        /// A relevance is a window, not an event, so the session has to claim
        /// one that outlives the reload that published it: a timed session
        /// claims through to its deadline, and an open-ended one a rolling
        /// window longer than the card's refresh cadence, pushed out again by
        /// every reload while the session keeps running. The app reloads on
        /// every state change, so the window opens on the tap that starts the
        /// session and is gone by the first reload after it ends.
        ///
        /// A deadline already behind us is no window at all — the session has
        /// rolled into overtime rather than ended, and it is still the thing
        /// worth having in front of you — so the floor applies to it too.
        func relevanceWindow(asOf now: Date = .now) -> ClosedRange<Date> {
            let floor = now.addingTimeInterval(Self.relevanceFloor)
            return now...max(deadline ?? floor, floor)
        }

        /// Comfortably longer than the running card's refresh interval, so the
        /// window never lapses in the gap between two reloads.
        static let relevanceFloor: TimeInterval = 20 * 60
    }

    /// Whether the study-day has turned since this snapshot was written.
    ///
    /// The calendar is a parameter for the same reason `Day`'s is: the boundary
    /// is a local-time rule, and a rule about local time cannot be tested in
    /// whatever zone the machine happens to be in.
    func isStale(asOf now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let dayStart else { return false }
        return Day.start(of: now, calendar: calendar) != dayStart
    }

    /// Everything studied today, including whatever is running right now.
    ///
    /// Past the day boundary nothing banked belongs to today any more, and only
    /// the part of a live session on this side of it does. A widget holding a
    /// stale snapshot therefore reads zero rather than yesterday's total, which
    /// is the truthful answer until the app is next able to republish.
    func today(asOf now: Date = .now, calendar: Calendar = .current) -> TimeInterval {
        guard isStale(asOf: now, calendar: calendar) else {
            return todaySec + (session?.elapsed(asOf: now) ?? 0)
        }
        return session?.elapsed(asOf: now, notBefore: Day.start(of: now, calendar: calendar)) ?? 0
    }

    /// The reading a ring or a bar draws, overflow included.
    func lap(asOf now: Date = .now, calendar: Calendar = .current) -> Lap {
        Lap(turns: goalSec > 0 ? today(asOf: now, calendar: calendar) / goalSec : 0)
    }

    /// The same reading, capped — what a system `Gauge` takes, which has no
    /// notion of going past full.
    func progress(asOf now: Date = .now, calendar: Calendar = .current) -> Double {
        min(lap(asOf: now, calendar: calendar).turns, 1)
    }
}
