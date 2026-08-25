import SwiftUI

/// Timed sessions show remaining, free sessions count up. Hitting zero rolls
/// into overtime; the session ends only when you end it.
struct RunningView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingSubjects = false
    @State private var announcedZero = false
    /// The stop button has been tapped once and is waiting to be confirmed.
    @State private var endConfirm = Confirmation()
    /// A fixed anchor, so the tick doesn't re-phase on every redraw.
    @State private var anchor = Date.now

    /// Dimmed, the display refreshes about once a minute, so a per-second
    /// schedule there only burns budget. Paused, the numeral is frozen — the
    /// same waste with the screen lit.
    private var cadence: TimeInterval {
        isLuminanceReduced || store.isPaused ? 60 : 1
    }

    var body: some View {
        TimelineView(.periodic(from: anchor, by: cadence)) { context in
            // One reading per redraw, taken here and passed down. Everything
            // below used to ask the store for it again — the measure alone was
            // built twice, once to size the numeral and once to fill it.
            let tick = reading(at: context.date)
            // The watch dimming swaps one layout for the other, which would
            // reseed an `onChange` attached to the layout itself and lose the
            // crossing. The container it hangs off has to outlive that swap.
            ZStack {
                layout(tick)
            }
            .onChange(of: tick.hasHitZero) { _, hitZero in
                guard hitZero, !announcedZero else { return }
                announcedZero = true
                Haptics.sessionComplete()
            }
        }
        .containerBackground(.black, for: .navigation)
        .navigationBarBackButtonHidden()
        .toolbar {
            if !isLuminanceReduced {
                // Both controls live in the bottom bar, pushed to opposite
                // edges: the thumb reaches either without crossing the numeral,
                // and the two targets can each keep their full 44pt.
                //
                // Confirming happens in the same two positions rather than in a
                // dialog — the left control becomes the way out and the right
                // one becomes the commitment, so nothing on screen moves and
                // the thumb is already where it needs to be. The question goes
                // in the gap between them, which is empty until it is asked.
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 0) {
                        CircleControl(
                            systemImage: endConfirm.isArmed
                                ? "xmark"
                                : (store.isPaused ? "play.fill" : "pause.fill"),
                            label: endConfirm.isArmed
                                ? "Keep going"
                                : (store.isPaused ? "Resume" : "Pause")
                        ) {
                            if endConfirm.isArmed {
                                withdrawConfirmation()
                            } else {
                                togglePause()
                            }
                        }

                        Spacer(minLength: 8)

                        // Asked between the two answers rather than from the
                        // top of the screen — as far from the controls as the
                        // display allows, and a glance away from the thumb
                        // about to commit. Short because the gap between two
                        // 44pt targets is barely 56pt on the smallest watch;
                        // flanked by an ✕ and a ✓ there is nothing else it
                        // could be asking. Untinted, like every other label
                        // here: the accent belongs to the control that commits,
                        // never to the words next to it.
                        if endConfirm.isArmed {
                            Text("End?")
                                .sectionLabelStyle()
                                .lineLimit(1)
                                .fixedSize()
                                .labelSwap(reduceMotion: reduceMotion)

                            Spacer(minLength: 8)
                        }

                        CircleControl(
                            systemImage: endConfirm.isArmed ? "checkmark" : "stop.fill",
                            label: endConfirm.isArmed ? "End session" : "End session\u{2026}",
                            tint: Palette.accent
                        ) {
                            if endConfirm.isArmed { endSession() } else { askToEnd() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(Motion.fill(reduceMotion: reduceMotion), value: endConfirm.isArmed)
                }
            }
        }
        .onChange(of: store.activeSessionID) { _, _ in
            announcedZero = false
            endConfirm.withdraw()
        }
        // A confirmation nobody answered is not a decision to hold onto.
        .onDisappear { endConfirm.withdraw() }
        .sheet(isPresented: $showingSubjects) {
            SubjectPicker(selection: store.activeSubjectID) { subjectID in
                store.switchSubject(to: subjectID)
                showingSubjects = false
            }
        }
    }

    // MARK: - The clock

    /// One reading of the live session, taken once per redraw so nothing below
    /// has to go back to the store for it.
    private struct Tick {
        /// Seconds left on a timed session — `nil` when it is open-ended.
        let remaining: TimeInterval?
        let elapsed: TimeInterval
        let plannedSec: Int?
        /// Today against the goal, live: what the ring behind the clock draws.
        let todayTurns: Double

        var isOvertime: Bool { (remaining ?? 1) < 0 }
        var hasHitZero: Bool { (remaining ?? 1) <= 0 }

        /// Long enough to be caught by the next glance down, short enough that
        /// it doesn't become the screen's resting state.
        static let completeWindow: TimeInterval = 2 * 60

        /// Just finished. Measured off the reading rather than latched when the
        /// crossing happened, so it survives the app being put away and opened
        /// again a minute later — and a pause holds it, the way a pause holds
        /// everything else here.
        var isJustComplete: Bool {
            guard let remaining, remaining <= 0 else { return false }
            return -remaining < Self.completeWindow
        }

        var measure: Format.Measure {
            Format.count(remaining: remaining, elapsed: elapsed, plannedSec: plannedSec)
        }
    }

    private func reading(at now: Date) -> Tick {
        Tick(
            remaining: store.remaining(asOf: now),
            elapsed: store.elapsed(asOf: now),
            plannedSec: store.activePlannedSec,
            todayTurns: store.todayProgress(asOf: now)
        )
    }

    // MARK: - Layout

    /// One layout, lit or dimmed. Always-On is this clock with its seconds
    /// taken off — the reading a wrist glance can use, in the same place, at
    /// the same size — rather than a screen of its own that swaps in whole.
    private func layout(_ tick: Tick) -> some View {
        let subject = store.subject(store.activeSubjectID)
        let measure = tick.measure
        return VStack(spacing: 2) {
            Spacer(minLength: 0)
            HeroNumeral(
                measure: measure,
                // Sized by the field it can grow into, seconds included, so
                // dropping them doesn't resize what's left.
                size: heroSize(for: measure),
                prominence: prominence(tick),
                drawsAsOneField: true,
                secondsHidden: isLuminanceReduced
            )
            .padding(.horizontal, 6)
            SubjectButton(
                name: subject?.name,
                colorIndex: subject?.colorIndex,
                showsDot: true,
                // Mid-session there is no subject to go and pick — running
                // without one is what a free session *is*.
                placeholder: "Free"
            ) {
                showingSubjects = true
            }
            .opacity(store.isPaused ? 0.5 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        // Behind the clock, not around it: the same ring the session was
        // started inside, going on filling while it runs. It is the reason the
        // number above is a study total and not a stopwatch. Thinner than the
        // Start screen's, where it is the subject rather than the ground, and
        // it doesn't settle — a live count moves every second by a sliver.
        .background {
            GoalRing(goalTurns: tick.todayTurns, lineWidth: 6, animatesProgress: false)
                .padding(.vertical, -18)
        }
        .overlay(alignment: .top) {
            if let status = status(tick) {
                Text(status)
                    .sectionLabelStyle()
                    .id(status)
                    .labelSwap(reduceMotion: reduceMotion)
            }
        }
        .animation(Motion.fill(reduceMotion: reduceMotion), value: status(tick))
    }

    /// A held clock and a running one are otherwise the same picture — a
    /// frozen count reads as a count — so the number itself steps back rather
    /// than leaving one small word to carry the state. Held outranks overtime:
    /// a session past its deadline and paused is not measuring either.
    private func prominence(_ tick: Tick) -> HeroNumeral.Prominence {
        if store.isPaused { return .held }
        return tick.isOvertime ? .overtime : .counting
    }

    /// The top line reports state, and nothing else. The question that used to
    /// outrank it now asks from between the controls that answer it, so a
    /// paused session stays legible while it is being asked.
    ///
    /// Reaching the planned time is the point of a timed session and went by
    /// unmarked but for a tap on the wrist — the clock rolled into overtime and
    /// nothing on screen said what had just happened. Paused still outranks it:
    /// a held clock is the more useful thing to be told.
    private func status(_ tick: Tick) -> String? {
        if store.isPaused { return "Paused" }
        return tick.isJustComplete ? "Complete" : nil
    }

    // MARK: - Actions

    private func togglePause() {
        if store.isPaused { store.resume() } else { store.pause() }
        Haptics.crownDetent()
    }

    private func askToEnd() {
        endConfirm.ask()
        Haptics.crownDetent()
    }

    private func withdrawConfirmation() {
        endConfirm.withdraw()
        Haptics.crownDetent()
    }

    private func endSession() {
        endConfirm.withdraw()
        // Under a minute there is no summary to show, so this is the only
        // acknowledgement the session gets.
        if store.end() == nil { Haptics.sessionAbandoned() }
    }

    // MARK: - Derived

    /// The clock is sized by the field it has to fill, not by the value in it,
    /// so it never resizes mid-session as digits roll.
    private func heroSize(for measure: Format.Measure) -> CGFloat {
        measure.widest.count > 6 ? Typography.Size.heroCompact : Typography.Size.hero
    }
}
