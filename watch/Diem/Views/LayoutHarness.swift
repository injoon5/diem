import SwiftUI

#if DEBUG

/// A session on the clock without a session to run, so the Running screen can
/// be looked at — dimmed, lapped, mid-switch — in a simulator, in a second.
///
/// Debug builds only, and only when asked for by launch argument. Reaching
/// these states by hand means studying for an hour with a stopwatch and then
/// dropping your wrist at the right moment, which is why the Always-On layout
/// went out twice with the picture sitting too low.
///
///     xcrun simctl launch booted com.injoon5.diem.watchkitapp \
///         -DiemHarness -DiemHarnessDimmed -DiemHarnessCentreLine
///
/// `-DiemHarness` puts a session with several subjects on the clock, the last
/// of them switched to a moment ago. `-DiemHarnessDimmed` holds the screen in
/// the state a dropped wrist puts it in. `-DiemHarnessCentreLine` draws a
/// hairline across the true middle of the display, which is the only way to
/// tell centred from nearly centred by looking.
enum LayoutHarness {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isOn: Bool { arguments.contains("-DiemHarness") }

    /// Printed once at launch, because a harness that silently did not turn on
    /// looks exactly like the bug it was meant to show.
    @MainActor
    static func announce() {
        guard isOn else { return }
        print(
            "[harness] on — showcase: \(isShowcase) \(screen), dimmed: \(isDimmed), "
                + "goal: \(hasGoal), centre line: \(showsCentreLine)"
        )
    }
    static var isDimmed: Bool { arguments.contains("-DiemHarnessDimmed") }
    static var showsCentreLine: Bool { arguments.contains("-DiemHarnessCentreLine") }

    /// Puts a goal on the session, so the ring is drawn against the planned
    /// time rather than against the hour. Off by default: a planned session
    /// schedules its completion alert, and scheduling is what asks for
    /// notification permission.
    static var hasGoal: Bool { arguments.contains("-DiemHarnessGoal") }

    /// Leaves nothing running and puts today past the goal, so the harness
    /// comes up on the Start screen with its ring lapped — the state that
    /// otherwise takes a whole day of study to reach, and the only one in which
    /// the goal ring draws a shadow at all.
    static var isStart: Bool { arguments.contains("-DiemHarnessStart") }

    /// Swaps the hero numeral across the field boundary — `59 m` to `1h 00m`
    /// and back — twice a second, over the ring it has to stay clear of. The
    /// crossing lasts a fifth of a second and happens twice a day in real use,
    /// which is not a thing anybody can look at.
    static var showsNumeral: Bool { arguments.contains("-DiemHarnessNumeral") }

    /// A whole plausible history rather than a single contrived state: three
    /// months of study behind a day that is nearly at its goal. For screenshots
    /// and for looking at the app the way somebody who has been using it sees
    /// it, which no amount of tapping through a fresh install ever shows you.
    static var isShowcase: Bool { arguments.contains("-DiemHarnessShowcase") }

    /// Which of the four screens the showcase lands on.
    enum Screen {
        case home, running, ended, stats
    }

    static var screen: Screen {
        if arguments.contains("-DiemHarnessRunning") { return .running }
        if arguments.contains("-DiemHarnessEnded") { return .ended }
        if arguments.contains("-DiemHarnessStats") { return .stats }
        return .home
    }

    static var opensStats: Bool { isOn && isShowcase && screen == .stats }

    /// A running session that has not yet lapped.
    ///
    /// A session with no planned time is an hour to the turn, so anything past
    /// the hour is a spent turn with a short bright arc over it — true, and the
    /// whole point of the lapping, but it is not the picture of a session in
    /// full colour. Under the hour every subject in it is on the ring at full
    /// strength at once.
    static var isShortRun: Bool { arguments.contains("-DiemHarnessShort") }

    /// Forty-seven minutes over four subjects, the last of them two seconds
    /// old: a bar with several joins in it, one of them brand new, and an end
    /// far enough round to be nowhere near the start.
    @MainActor
    static func seed(_ store: SessionStore) {
        guard isOn, store.activeSessionID == nil else { return }
        if isShowcase {
            seedShowcase(store)
            return
        }
        if isStart {
            seedFinishedDay(store)
            return
        }
        let names = ["Maths", "Physics", "Korean", "History"]
        let subjects = names.enumerated().map { index, name in
            store.subjects().first { $0.name == name }
                ?? store.addSubject(name: name, colorIndex: index * 2)
        }
        let now = Date.now
        // Open-ended unless a goal is asked for. A planned session schedules
        // the alert at its deadline, and scheduling is what asks for
        // notification permission — so a harness that only wants to be looked
        // at would otherwise come up behind a permission dialog.
        _ = store.start(
            subjectID: subjects[0].id,
            plannedSec: hasGoal ? 60 * 60 : nil,
            at: now - 47 * 60
        )
        store.switchSubject(to: subjects[1].id, at: now - 26 * 60)
        store.switchSubject(to: subjects[2].id, at: now - 9 * 60)
        store.switchSubject(to: subjects[3].id, at: now - 2)
    }
}

extension LayoutHarness {
    /// What a few months of using this looks like.
    ///
    /// Deterministic — the same history every launch, so two screenshots taken
    /// a day apart are of the same app rather than of two different ones.
    @MainActor
    fileprivate static func seedShowcase(_ store: SessionStore) {
        guard store.todaySeconds() == 0 else { return }
        for (index, name) in cast.enumerated() {
            if store.subjects().first(where: { $0.name == name }) == nil {
                _ = store.addSubject(name: name, colorIndex: colours[index])
            }
        }

        let now = Date.now
        let days = Day.recentStarts(from: now, count: 90)

        // Three months behind today. Oldest first, so nothing is ever started
        // while something older is still open.
        for (offset, day) in days.enumerated().reversed() where offset > 0 {
            guard let minutes = studied(dayOffset: offset) else { continue }
            // Six in the evening, on a day that begins at four in the morning.
            let start = day.addingTimeInterval(14 * 3600)
            _ = store.start(
                subjectID: id(store, cast[offset % cast.count]),
                plannedSec: nil,
                at: start
            )
            // Most days are two subjects, the long ones three. A history where
            // every day is one colour makes a heatmap of a single hue.
            if minutes > 75 {
                store.switchSubject(
                    to: id(store, cast[(offset + 1) % cast.count]),
                    at: start + Double(minutes) * 0.4 * 60
                )
            }
            if minutes > 120 {
                store.switchSubject(
                    to: id(store, cast[(offset + 3) % cast.count]),
                    at: start + Double(minutes) * 0.72 * 60
                )
            }
            _ = store.end(at: start + Double(minutes) * 60, presentingDone: false)
        }

        switch screen {
        case .home, .stats:
            // Nearly there: an hour and three quarters of a two hour goal, over
            // three subjects, so the ring is all but closed and Metrics has
            // more than one bar to draw.
            play(
                store,
                [
                    ("Calculus", 26), ("Physics", 18), ("Korean", 12),
                    ("Social Studies", 15), ("Calculus", 14), ("Physics", 22),
                ],
                upTo: now,
                ending: false
            )
        case .ended:
            play(
                store,
                [
                    ("Calculus", 24), ("Physics", 18), ("Korean", 14),
                    ("Social Studies", 11), ("Calculus", 8), ("Physics", 10),
                ],
                upTo: now,
                ending: true
            )
        case .running:
            // Still going, four subjects deep, the last one five minutes old.
            // Eight stretches over four subjects, because what the ring draws
            // is the *shape* of a session — a subject picked up, put down and
            // come back to — and four long bands is a pie chart of the same
            // hours.
            //
            // Two hours, seven minutes and thirty-eight seconds on the clock,
            // less a lead: it is still running, and it has to be still running
            // or the screen is not the screen being photographed. The seed
            // starts it a little short and the shutter catches it going past.
            playSeconds(
                store,
                isShortRun
                    ? [
                        ("Calculus", 640), ("Physics", 500), ("Korean", 430),
                        ("Social Studies", 398), ("Calculus", 200),
                    ]
                    : [
                        ("Calculus", 1320), ("Physics", 1080), ("Korean", 840),
                        ("Social Studies", 660), ("Calculus", 960), ("Physics", 720),
                        ("Korean", 1080), ("Social Studies", 998),
                    ],
                upTo: now + lead,
                ending: nil
            )
        }
    }

    /// How far short of its mark the running clock is seeded.
    ///
    /// The screenshot is taken some seconds after the app comes up, and a
    /// running clock does not wait for it.
    private static let lead: TimeInterval = 30

    /// One session laid out backwards from the moment it reaches `upTo`.
    ///
    /// `ending` says what happens when it gets there: `nil` leaves it running,
    /// otherwise it is put away, and the flag decides whether the Done screen
    /// is put in front of it.
    @MainActor
    private static func play(
        _ store: SessionStore,
        _ runs: [(subject: String, minutes: Int)],
        upTo end: Date,
        ending presentingDone: Bool?
    ) {
        playSeconds(
            store,
            runs.map { ($0.subject, $0.minutes * 60) },
            upTo: end,
            ending: presentingDone
        )
    }

    @MainActor
    private static func playSeconds(
        _ store: SessionStore,
        _ runs: [(subject: String, seconds: Int)],
        upTo end: Date,
        ending presentingDone: Bool?
    ) {
        let total = Double(runs.reduce(0) { $0 + $1.seconds })
        var cursor = end - total
        _ = store.start(subjectID: id(store, runs[0].subject), plannedSec: nil, at: cursor)
        for index in 1..<runs.count {
            cursor += Double(runs[index - 1].seconds)
            store.switchSubject(to: id(store, runs[index].subject), at: cursor)
        }
        if let presentingDone {
            _ = store.end(at: end, presentingDone: presentingDone)
        }
    }

    /// The four subjects, and the palette entries they are drawn in: blue,
    /// emerald, magenta, cyan. Four hues far enough apart to tell at a glance
    /// on a ring six points wide.
    /// The four subjects, and the palette entries they are drawn in.
    ///
    /// Blue, lime, magenta, green — as close to blue, yellow, red and green as
    /// this palette goes. It has no yellow and no red on purpose: every hue
    /// from orange round to warm red is left out so that a subject swatch can
    /// never be taken for the accent, which is the Action Button's
    /// International Orange and means *the thing you press*.
    fileprivate static let cast = ["Calculus", "Physics", "Korean", "Social Studies"]
    private static let colours = [6, 0, 9, 1]

    /// By name, never by position. `subjects()` answers in its own order — it
    /// is not the order they were added in — so indexing into it put the wrong
    /// colour against every name in the seed, and the screenshots were of a day
    /// nobody had.
    @MainActor
    private static func id(_ store: SessionStore, _ name: String) -> UUID? {
        store.subjects().first { $0.name == name }?.id
    }

    /// How long a given day back was spent, or `nil` for a day off.
    ///
    /// A hash of the day's own number rather than a random draw: the history
    /// has to be the same on the next launch or the harness is showing a
    /// different app every time it opens. Three weeks unbroken behind today —
    /// a streak worth drawing — and the odd rest day before that.
    private static func studied(dayOffset offset: Int) -> Int? {
        let hash = abs(offset &* 2_654_435_761 % 100)
        if offset > 22, hash < 22 { return nil }
        // Longer at the weekend, which is where the heatmap gets its texture.
        let weekend = offset % 7 == 2 || offset % 7 == 3
        return 70 + hash % 80 + (weekend ? 45 : 0)
    }

    /// A third of a turn past the goal, already finished and put away.
    @MainActor
    fileprivate static func seedFinishedDay(_ store: SessionStore) {
        // Once, not once per launch. Seeding on every start stacked another
        // day's worth on top of the last, so the ring crept round further every
        // time the harness was opened and the state under test quietly changed
        // between two screenshots of it.
        guard store.todaySeconds() == 0 else { return }
        let subject = store.subjects().first { $0.name == "Maths" }
            ?? store.addSubject(name: "Maths", colorIndex: 0)
        let length = store.goalSeconds * 1.3
        let now = Date.now
        _ = store.start(subjectID: subject.id, plannedSec: nil, at: now - length - 60)
        // Not presented: the harness wants the Start screen, and a session that
        // has just ended puts the Done screen in front of it.
        _ = store.end(at: now - 60, presentingDone: false)
    }
}

/// The hero numeral, crossing the hour, on a loop.
///
/// Behind the goal ring and inside the same padding the Start screen gives it,
/// because the bug this exists for is the numeral fouling the arc on the way
/// past — which only shows at the width the real screen has.
struct NumeralHarness: View {
    /// Faster than the swap it drives, on purpose. A wrist crossing the hour on
    /// the crown re-crosses it several times a second, so every transition is
    /// interrupted part-way by the next one — which is the state a numeral is
    /// most likely to be caught out of place in, and the one a swap every
    /// second never reaches.
    private static let period: TimeInterval = 0.2

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.period)) { context in
            let seconds = Int(context.date.timeIntervalSince1970 / Self.period) % 2 == 0
                ? 59 * 60.0
                : 60 * 60.0
            ZStack {
                GoalRing(goalTurns: 0.4)
                HeroNumeral(
                    measure: Format.total(seconds),
                    size: Typography.Size.ringNumeral,
                    tracking: Typography.Size.ringNumeralTracking
                )
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, -14)
        }
        .containerBackground(.black, for: .navigation)
    }
}

/// The middle of the display, drawn on it.
///
/// Not the middle of the safe area — that is the number the layout already
/// knows and the one it can be wrong about.
struct CentreLine: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
            Rectangle()
                .fill(.red.opacity(0.7))
                .frame(height: 1)
            Color.clear
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
#endif

extension View {
    /// Stands in for a dropped wrist.
    ///
    /// Applied here, around the screen itself, rather than once at the app
    /// root: `isLuminanceReduced` set above the navigation stack does not
    /// survive into it — watchOS puts its own value back on the way down, and
    /// the harness came up lit however it was launched.
    @ViewBuilder
    func harnessDimmed() -> some View {
        #if DEBUG
        transformEnvironment(\.isLuminanceReduced) { dimmed in
            if LayoutHarness.isDimmed { dimmed = true }
        }
        #else
        self
        #endif
    }
}

extension View {
    /// Opens Metrics on arrival, for the one screenshot that is behind a tap.
    @ViewBuilder
    func harnessOpensMetrics(_ isPresented: Binding<Bool>) -> some View {
        #if DEBUG
        onAppear { if LayoutHarness.opensStats { isPresented.wrappedValue = true } }
        #else
        self
        #endif
    }
}
