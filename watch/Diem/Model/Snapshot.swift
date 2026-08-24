import Foundation

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
}

enum SnapshotStore {
    static let appGroup = "group.app.diem"
    static let widgetKind = "DiemToday"
    static let sessionWidgetKind = "DiemSession"

    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("snapshot.json")
    }

    static func read() -> DiemSnapshot {
        guard let url, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder.diem.decode(DiemSnapshot.self, from: data)
        else { return DiemSnapshot() }
        return snapshot
    }

    @discardableResult
    static func write(_ snapshot: DiemSnapshot) -> Bool {
        guard let url, let data = try? JSONEncoder.diem.encode(snapshot) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
