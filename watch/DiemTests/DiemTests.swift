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

    @Test("An hour and over reads in tenths of an hour")
    func hours() {
        #expect(Format.total(72 * 60).value == "1.2")
        #expect(Format.total(72 * 60).unit == "h")
    }

    @Test("Countdowns reserve the width they can grow into")
    func countdownWidth() {
        #expect(Format.clock(25 * 60, span: 25 * 60).value == "25:00")
        #expect(Format.clock(25 * 60, span: 25 * 60).widest == "00:00")
        #expect(Format.clock(90 * 60, span: 90 * 60).widest == "0:00:00")
        #expect(Format.clock(90 * 60, span: 90 * 60).value == "1:30:00")
    }

    @Test("Overtime carries its sign")
    func overtime() {
        #expect(Format.overtime(200).value == "+3:20")
    }

    @Test("Scrubbed durations read plainly")
    func durations() {
        #expect(Format.duration(25 * 60) == "25m")
        #expect(Format.duration(90 * 60) == "1h 30m")
        #expect(Format.duration(120 * 60) == "2h")
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
