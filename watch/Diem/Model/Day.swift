import Foundation

/// The 4am day boundary.
///
/// A session counts toward the day it started, and a day runs 04:00 → 03:59
/// local time. Everything is stored in UTC and bucketed by the local day that
/// was in effect when the session started.
enum Day {
    static let boundaryHour = 4

    /// The instant the study-day containing `date` began.
    static func start(of date: Date, calendar: Calendar = .current) -> Date {
        let shifted = date.addingTimeInterval(-Double(boundaryHour) * 3600)
        let midnight = calendar.startOfDay(for: shifted)
        return midnight.addingTimeInterval(Double(boundaryHour) * 3600)
    }

    /// The calendar date a study-day is filed under — the date of its 04:00 start.
    static func key(for date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: start(of: date, calendar: calendar))
    }

    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        start(of: a, calendar: calendar) == start(of: b, calendar: calendar)
    }

    /// Study-day starts walking backwards from `date`, most recent first.
    static func recentStarts(from date: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        let first = start(of: date, calendar: calendar)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: -$0, to: first) }
    }
}
