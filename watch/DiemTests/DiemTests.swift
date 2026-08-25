import Foundation
import Testing
@testable import Diem

@Suite("Day boundary")
struct DayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ iso: String) -> Date {
        ISO8601.parse(iso)!
    }

    @Test("3am belongs to the previous day")
    func lateNight() {
        let start = Day.start(of: date("2026-03-04T03:30:00Z"), calendar: calendar)
        #expect(start == date("2026-03-03T04:00:00Z"))
    }

    @Test("4am starts a new day")
    func boundary() {
        let start = Day.start(of: date("2026-03-04T04:00:00Z"), calendar: calendar)
        #expect(start == date("2026-03-04T04:00:00Z"))
    }

    @Test("A 2am session and the 11pm before it are the same day")
    func sameDay() {
        #expect(
            Day.isSameDay(
                date("2026-03-03T23:00:00Z"),
                date("2026-03-04T02:00:00Z"),
                calendar: calendar
            )
        )
    }

    @Test("Recent starts walk back one day at a time")
    func recents() {
        let starts = Day.recentStarts(from: date("2026-03-04T09:00:00Z"), count: 3, calendar: calendar)
        #expect(starts == [
            date("2026-03-04T04:00:00Z"),
            date("2026-03-03T04:00:00Z"),
            date("2026-03-02T04:00:00Z"),
        ])
    }
}

@Suite("Number formats")
struct FormatTests {
    @Test("Under an hour reads in whole minutes")
    func minutes() {
        let measure = Format.total(45 * 60)
        #expect(measure.value == "45")
        #expect(measure.unit == "m")
    }

    @Test("Zero reads as 0 m")
    func zero() {
        #expect(Format.total(0).value == "0")
        #expect(Format.total(0).unit == "m")
    }

    @Test("An hour and over reads as hours and minutes")
    func hours() {
        #expect(Format.total(60 * 60).value == "1h 00m")
        #expect(Format.total(72 * 60).value == "1h 12m")
        #expect(Format.total(72 * 60).unit == nil)
    }

    @Test("A total's minutes hold two digits so the unit labels never shift")
    func totalMinutesPadded() {
        #expect(Format.total(65 * 60).value == "1h 05m")
        #expect(Format.total(65 * 60).widest == "88h 88m")
    }

    @Test("A measure spells itself the same way in prose as in the numeral")
    func measureText() {
        #expect(Format.total(2 * 3600).text == "2h 00m")
        #expect(Format.total(15 * 60).text == "15m")
        #expect(Format.clock(25 * 60, span: 25 * 60).text == "25:00")
    }

    @Test("Countdowns reserve the width they can grow into")
    func countdownWidth() {
        #expect(Format.clock(25 * 60, span: 25 * 60).value == "25:00")
        #expect(Format.clock(25 * 60, span: 25 * 60).widest == "00:00")
        #expect(Format.clock(90 * 60, span: 90 * 60).widest == "0:00:00")
        #expect(Format.clock(90 * 60, span: 90 * 60).value == "1:30:00")
    }

    @Test("Minutes hold two digits so the clock never shifts")
    func clockMinutesPadded() {
        #expect(Format.clock(5 * 60, span: 25 * 60).value == "05:00")
    }

    @Test("The count says the same thing running or held")
    func count() {
        // A timed session reads what is left, whether it is running or paused.
        let timed = Format.count(remaining: 900, elapsed: 600, plannedSec: 1500)
        #expect(timed.value == "15:00")
        #expect(timed.motion == .countdown)

        // An open-ended one reads what it has done.
        let free = Format.count(remaining: nil, elapsed: 600, plannedSec: nil)
        #expect(free.value == "10:00")
        #expect(free.motion == .countUp)

        // Past the deadline it rolls into overtime rather than freezing at zero.
        #expect(Format.count(remaining: -200, elapsed: 1700, plannedSec: 1500).value == "+03:20")
    }

    @Test("Overtime carries its sign")
    func overtime() {
        #expect(Format.overtime(200).value == "+03:20")
    }

    @Test("Scrubbed durations read plainly")
    func durations() {
        #expect(Format.duration(25 * 60) == "25m")
        #expect(Format.duration(90 * 60) == "1h 30m")
        #expect(Format.duration(120 * 60) == "2h 0m")
    }
}

@Suite("Crown stepping")
struct ScrubTests {
    @Test("One minute a step up to an hour")
    func fine() {
        #expect(DurationScrub.minutes(forStep: 1) == 1)
        #expect(DurationScrub.minutes(forStep: 25) == 25)
        #expect(DurationScrub.minutes(forStep: 60) == 60)
    }

    @Test("Five minutes a step up to four hours")
    func medium() {
        #expect(DurationScrub.minutes(forStep: 61) == 65)
        #expect(DurationScrub.minutes(forStep: 96) == 240)
    }

    @Test("Fifteen minutes a step beyond")
    func coarse() {
        #expect(DurationScrub.minutes(forStep: 97) == 255)
        #expect(DurationScrub.minutes(forStep: DurationScrub.maxStep) == 480)
    }

    @Test("Stepping round-trips", arguments: [0, 25, 60, 65, 240, 255, 480])
    func roundTrip(minutes: Int) {
        #expect(DurationScrub.minutes(forStep: DurationScrub.step(forMinutes: minutes)) == minutes)
    }

    @Test("A fractional crown position lands between its two detents")
    func fractional() {
        #expect(DurationScrub.seconds(forFractionalStep: 10) == 600)
        #expect(DurationScrub.seconds(forFractionalStep: 10.5) == 630)
        // The curve coarsens past an hour, and the interpolation follows it.
        #expect(DurationScrub.seconds(forFractionalStep: 60.5) == 3750)
    }

    @Test("A fractional position never leaves the range")
    func fractionalClamped() {
        #expect(DurationScrub.seconds(forFractionalStep: -4) == 0)
        #expect(
            DurationScrub.seconds(forFractionalStep: Double(DurationScrub.maxStep) + 4)
                == DurationScrub.seconds(forStep: DurationScrub.maxStep)
        )
    }

    @Test("One revolution is sixty minutes")
    func revolution() {
        #expect(DurationScrub.turns(forSeconds: 3600) == 1)
        #expect(DurationScrub.turns(forSeconds: 5400) == 1.5)
    }

    @Test("The goal steps in quarter hours")
    func goal() {
        #expect(GoalScrub.minutes(forStep: 0) == 15)
        #expect(GoalScrub.minutes(forStep: 7) == 120)
        #expect(GoalScrub.step(forMinutes: 120) == 7)
    }
}

@Suite("Streaks")
struct StreakTests {
    private let start = ISO8601.parse("2026-03-04T04:00:00Z")!

    /// Oldest first, the way the store hands them over.
    private func days(_ seconds: [TimeInterval]) -> [(day: Date, seconds: TimeInterval)] {
        seconds.enumerated().map { index, value in
            (day: start.addingTimeInterval(Double(index) * 86_400), seconds: value)
        }
    }

    @Test("Consecutive days count back from the most recent")
    func consecutive() {
        #expect(days([0, 0, 60, 60, 60]).studyStreak == 3)
    }

    @Test("Today not having started yet doesn't break it")
    func openToday() {
        #expect(days([60, 60, 0]).studyStreak == 2)
    }

    @Test("A gap before today does break it")
    func gap() {
        #expect(days([60, 60, 0, 60]).studyStreak == 1)
        #expect(days([60, 60, 0, 60, 0]).studyStreak == 1)
    }

    @Test("Nothing studied is no streak")
    func none() {
        #expect(days([0, 0, 0]).studyStreak == 0)
        #expect([(day: Date, seconds: TimeInterval)]().studyStreak == 0)
    }
}

@Suite("Goal laps")
struct LapTests {
    @Test("Under the goal, the fraction is the progress")
    func partial() {
        #expect(Lap(turns: 0.5).fraction == 0.5)
        #expect(Lap(turns: 0.5).isLapped == false)
    }

    @Test("Exactly the goal is a full track, not a lap")
    func exact() {
        #expect(Lap(turns: 1).fraction == 1)
        #expect(Lap(turns: 1).isLapped == false)
    }

    @Test("Past the goal, what's drawn is the overflow over the completed pass")
    func lapped() {
        #expect(Lap(turns: 1.25).isLapped == true)
        #expect(Lap(turns: 1.25).fraction == 0.25)
    }

    @Test("A whole number of laps reads full, never empty")
    func wholeLaps() {
        #expect(Lap(turns: 2).isLapped == true)
        #expect(Lap(turns: 2).fraction == 1)
    }

    @Test("Nothing studied leaves the track empty")
    func empty() {
        #expect(Lap(turns: 0).fraction == 0)
        #expect(Lap(turns: -1).fraction == 0)
        #expect(Lap(turns: -1).isLapped == false)
    }

    @Test("A snapshot laps against its own goal")
    func fromSnapshot() {
        let lap = DiemSnapshot(todaySec: 3 * 3600, goalSec: 2 * 3600).lap()
        #expect(lap.isLapped)
        #expect(lap.fraction == 0.5)
    }

    @Test("No goal is no reading")
    func noGoal() {
        #expect(DiemSnapshot(todaySec: 3600, goalSec: 0).lap().turns == 0)
    }
}

@Suite("Sessions from intervals")
struct SessionTests {
    /// Session assembly is pure arithmetic over the log, so it can be tested
    /// without a store behind it.
    private struct Span: IntervalRecord {
        var sessionID: UUID
        var subjectID: UUID?
        var startedAt: Date
        var endedAt: Date?
        var plannedSec: Int?
    }

    private let start = ISO8601.parse("2026-03-04T09:00:00Z")!

    private func span(
        session: UUID,
        subject: UUID? = nil,
        offset: TimeInterval,
        length: TimeInterval?,
        planned: Int? = nil
    ) -> Span {
        Span(
            sessionID: session,
            subjectID: subject,
            startedAt: start.addingTimeInterval(offset),
            endedAt: length.map { start.addingTimeInterval(offset + $0) },
            plannedSec: planned
        )
    }

    @Test("The live summary reads the same total as the session it stands in for")
    func liveSummaryAgrees() {
        let session = UUID()
        let now = start.addingTimeInterval(2400)
        let log = [
            span(session: session, offset: 0, length: 600, planned: 1500),
            span(session: session, offset: 900, length: nil),
        ]
        let summary = log.liveSummary()
        #expect(summary?.studied(asOf: now) == log.sessions(asOf: now).first?.studiedSec)
        #expect(summary?.studied(asOf: now) == 2100)
        #expect(summary?.startedAt == start)
        #expect(summary?.plannedSec == 1500)
        #expect(summary?.isPaused == false)
    }

    @Test("A paused summary holds the count where it stopped")
    func liveSummaryPaused() {
        let session = UUID()
        let log = [
            span(session: session, offset: 0, length: 600),
            span(session: session, offset: 900, length: 300),
        ]
        let summary = log.liveSummary()
        #expect(summary?.isPaused == true)
        // Long past the last interval, and the count hasn't moved.
        #expect(summary?.studied(asOf: start.addingTimeInterval(9000)) == 900)
    }

    @Test("The live subject is whatever is open, or the last one while paused")
    func liveSummarySubject() {
        let session = UUID()
        let (math, physics) = (UUID(), UUID())
        let running = [
            span(session: session, subject: math, offset: 0, length: 600),
            span(session: session, subject: physics, offset: 600, length: nil),
        ]
        #expect(running.liveSummary()?.subjectID == physics)

        let paused = [
            span(session: session, subject: physics, offset: 0, length: 600),
            span(session: session, subject: math, offset: 600, length: 300),
        ]
        #expect(paused.liveSummary()?.subjectID == math)
    }

    @Test("Nothing to summarise is nil, not zero")
    func liveSummaryEmpty() {
        #expect([Span]().liveSummary() == nil)
    }

    @Test("A pause leaves a real gap and the studied total skips it")
    func pauseGap() {
        let session = UUID()
        let log = [
            span(session: session, offset: 0, length: 600, planned: 1500),
            span(session: session, offset: 900, length: 900),
        ]
        let assembled = log.sessions().first
        #expect(assembled?.studiedSec == 1500)
        #expect(assembled?.endedAt == start.addingTimeInterval(1800))
        #expect(assembled?.intervalCount == 2)
    }

    @Test("A session with an interval still open has not ended")
    func openSession() {
        let session = UUID()
        let log = [
            span(session: session, offset: 0, length: 600),
            span(session: session, offset: 600, length: nil),
        ]
        #expect(log.sessions().first?.endedAt == nil)
    }

    @Test("Completion is derived from the wall-clock span")
    func completion() {
        let session = UUID()
        let done = [span(session: session, offset: 0, length: 1500, planned: 1500)]
        #expect(done.sessions().first?.isComplete == true)

        let short = [span(session: session, offset: 0, length: 900, planned: 1500)]
        #expect(short.sessions().first?.isComplete == false)
    }

    @Test("A free session has no plan and no subject, and nothing else marks it")
    func freeSession() {
        let log = [span(session: UUID(), offset: 0, length: 600)]
        let assembled = log.sessions().first
        #expect(assembled?.plannedSec == nil)
        #expect(assembled?.bySubject.first?.subjectID == nil)
    }

    @Test("Switching subject splits the total")
    func subjectSwitch() {
        let session = UUID()
        let (math, physics) = (UUID(), UUID())
        let log = [
            span(session: session, subject: math, offset: 0, length: 600),
            span(session: session, subject: physics, offset: 600, length: 1200),
        ]
        let assembled = log.sessions().first
        #expect(assembled?.bySubject.count == 2)
        // Most-studied first.
        #expect(assembled?.bySubject.first?.subjectID == physics)
        #expect(assembled?.bySubject.first?.seconds == 1200)
        #expect(assembled?.studiedSec == 1800)
    }

    @Test("Again repeats what was running at the end, not the biggest slice")
    func lastSubjectWins() {
        let session = UUID()
        let (math, physics) = (UUID(), UUID())
        let log = [
            span(session: session, subject: math, offset: 0, length: 1800),
            span(session: session, subject: physics, offset: 1800, length: 600),
        ]
        let assembled = log.sessions().first
        #expect(assembled?.bySubject.first?.subjectID == math)
        #expect(assembled?.lastSubjectID == physics)
    }

    @Test("Sessions come back most recent first")
    func ordering() {
        let (first, second) = (UUID(), UUID())
        let log = [
            span(session: first, offset: 0, length: 600),
            span(session: second, offset: 3600, length: 600),
        ]
        #expect(log.sessions().map(\.id) == [second, first])
    }
}
