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
    @State private var confirmingEnd = false
    /// Withdraws the confirmation if it is left standing.
    @State private var confirmTimeout: Task<Void, Never>?
    /// A fixed anchor, so the tick doesn't re-phase on every redraw.
    @State private var anchor = Date.now

    var body: some View {
        // Dimmed, the display refreshes about once a minute — asking for a
        // per-second schedule there only burns budget.
        TimelineView(.periodic(from: anchor, by: isLuminanceReduced ? 60 : 1)) { context in
            // The watch dimming swaps one layout for the other, which would
            // reseed an `onChange` attached to the layout itself and lose the
            // crossing. The container it hangs off has to outlive that swap.
            ZStack {
                layout(now: context.date)
            }
            .onChange(of: hasHitZero(now: context.date)) { _, hitZero in
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
                // the thumb is already where it needs to be.
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 0) {
                        CircleControl(
                            systemImage: confirmingEnd
                                ? "xmark"
                                : (store.isPaused ? "play.fill" : "pause.fill"),
                            label: confirmingEnd
                                ? "Keep going"
                                : (store.isPaused ? "Resume" : "Pause")
                        ) {
                            if confirmingEnd {
                                withdrawConfirmation()
                            } else {
                                togglePause()
                            }
                        }

                        Spacer(minLength: 8)

                        CircleControl(
                            systemImage: confirmingEnd ? "checkmark" : "stop.fill",
                            label: confirmingEnd ? "End session" : "End session\u{2026}",
                            tint: Palette.accent
                        ) {
                            if confirmingEnd { endSession() } else { askToEnd() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(Motion.fill(reduceMotion: reduceMotion), value: confirmingEnd)
                }
            }
        }
        .onChange(of: store.activeSessionID) { _, _ in
            announcedZero = false
            confirmingEnd = false
        }
        // A confirmation nobody answered is not a decision to hold onto.
        .onDisappear { confirmTimeout?.cancel() }
        .sheet(isPresented: $showingSubjects) {
            SubjectPicker(selection: store.activeSubjectID) { subjectID in
                store.switchSubject(to: subjectID)
                showingSubjects = false
            }
        }
    }

    // MARK: - Layouts

    @ViewBuilder
    private func layout(now: Date) -> some View {
        if isLuminanceReduced {
            alwaysOn(now: now)
        } else {
            active(now: now)
        }
    }

    private func active(now: Date) -> some View {
        let subject = store.subject(store.activeSubjectID)
        return VStack(spacing: 2) {
            Spacer(minLength: 0)
            HeroNumeral(
                measure: measure(now: now),
                size: heroSize(for: measure(now: now)),
                dimmed: isOvertime(now: now),
                drawsAsOneField: true
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
        .overlay(alignment: .top) {
            if let status {
                Text(status)
                    .sectionLabelStyle()
                    .foregroundStyle(confirmingEnd ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.secondary))
                    .id(status)
                    .labelSwap(reduceMotion: reduceMotion)
            }
        }
        .animation(Motion.fill(reduceMotion: reduceMotion), value: status)
    }

    /// One line, one state: the question outranks the pause it interrupts.
    private var status: String? {
        if confirmingEnd { return "End session?" }
        return store.isPaused ? "Paused" : nil
    }

    // MARK: - Actions

    private func togglePause() {
        if store.isPaused { store.resume() } else { store.pause() }
        Haptics.crownDetent()
    }

    /// Arms the confirmation. It withdraws itself rather than sitting there:
    /// a stale question on a wrist is an accident waiting for the next tap.
    private func askToEnd() {
        confirmingEnd = true
        Haptics.crownDetent()
        confirmTimeout?.cancel()
        confirmTimeout = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            confirmingEnd = false
        }
    }

    private func withdrawConfirmation() {
        confirmTimeout?.cancel()
        confirmingEnd = false
        Haptics.crownDetent()
    }

    private func endSession() {
        confirmTimeout?.cancel()
        confirmingEnd = false
        // Under a minute there is no summary to show, so this is the only
        // acknowledgement the session gets.
        if store.end() == nil { Haptics.sessionAbandoned() }
    }

    /// A second layout, not a dimmed copy: minutes only, one weight lighter
    /// (dimming optically thickens strokes), tracking loosened, no controls.
    private func alwaysOn(now: Date) -> some View {
        VStack(spacing: 2) {
            HeroNumeral(
                measure: alwaysOnMeasure(now: now),
                tracking: Typography.Size.heroTracking + 0.6,
                weight: .regular,
                drawsAsOneField: true
            )
            .padding(.horizontal, 6)
            if let name = store.subject(store.activeSubjectID)?.name {
                Text(name)
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .stillWhenDimmed(true)
    }

    // MARK: - Derived

    /// The clock is sized by the field it has to fill, not by the value in it,
    /// so it never resizes mid-session as digits roll.
    private func heroSize(for measure: Format.Measure) -> CGFloat {
        measure.widest.count > 6 ? Typography.Size.heroCompact : Typography.Size.hero
    }

    private func displaySeconds(now: Date) -> TimeInterval {
        if let remaining = store.remaining(asOf: now) { return remaining }
        return store.elapsed(asOf: now)
    }

    /// Minutes only, but still unambiguous: `+3 m` dimmed is three minutes over,
    /// not three minutes left.
    private func alwaysOnMeasure(now: Date) -> Format.Measure {
        var measure = Format.minutesOnly(abs(displaySeconds(now: now)))
        guard isOvertime(now: now) else { return measure }
        measure.value = "+" + measure.value
        measure.widest = "+" + measure.widest
        measure.spoken += " over"
        return measure
    }

    private func isOvertime(now: Date) -> Bool {
        (store.remaining(asOf: now) ?? 1) < 0
    }

    private func hasHitZero(now: Date) -> Bool {
        guard let remaining = store.remaining(asOf: now) else { return false }
        return remaining <= 0
    }

    private func measure(now: Date) -> Format.Measure {
        let span = store.activeSession?.plannedSec.map(Double.init)
        guard let remaining = store.remaining(asOf: now) else {
            let elapsed = store.elapsed(asOf: now)
            return Format.clock(elapsed, span: elapsed, countsDown: false)
        }
        if remaining < 0 {
            return Format.overtime(-remaining, span: -remaining)
        }
        return Format.clock(remaining, span: span)
    }
}
