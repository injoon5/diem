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
            "[harness] on — dimmed: \(isDimmed), goal: \(hasGoal), "
                + "centre line: \(showsCentreLine)"
        )
    }
    static var isDimmed: Bool { arguments.contains("-DiemHarnessDimmed") }
    static var showsCentreLine: Bool { arguments.contains("-DiemHarnessCentreLine") }

    /// Puts a goal on the session, so the ring is drawn against the planned
    /// time rather than against the hour. Off by default: a planned session
    /// schedules its completion alert, and scheduling is what asks for
    /// notification permission.
    static var hasGoal: Bool { arguments.contains("-DiemHarnessGoal") }

    /// Forty-seven minutes over four subjects, the last of them two seconds
    /// old: a bar with several joins in it, one of them brand new, and an end
    /// far enough round to be nowhere near the start.
    @MainActor
    static func seed(_ store: SessionStore) {
        guard isOn, store.activeSessionID == nil else { return }
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
