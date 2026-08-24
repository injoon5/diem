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
    }

    /// Everything studied today, including whatever is running right now.
    func today(asOf now: Date = .now) -> TimeInterval {
        todaySec + (session?.elapsed(asOf: now) ?? 0)
    }

    func progress(asOf now: Date = .now) -> Double {
        goalSec > 0 ? min(today(asOf: now) / goalSec, 1) : 0
    }

    /// Laps past the goal, for the overflow arc.
    func overflow(asOf now: Date = .now) -> Double {
        goalSec > 0 ? max(0, today(asOf: now) / goalSec - 1) : 0
    }

    /// The reading a ring or a bar draws, overflow included.
    func lap(asOf now: Date = .now) -> Lap {
        Lap(turns: goalSec > 0 ? today(asOf: now) / goalSec : 0)
    }
}
