import SwiftUI

/// Timed sessions show remaining, free sessions count up. Hitting zero rolls
/// into overtime; the session ends only when you end it.
struct RunningView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingSubjects = false
    @State private var announcedZero = false

    var body: some View {
        // Dimmed, the display refreshes about once a minute — asking for a
        // per-second schedule there only burns budget.
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 60 : 1)) { context in
            layout(now: context.date)
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
                ToolbarItemGroup(placement: .bottomBar) {
                    CircleControl(
                        systemImage: store.isPaused ? "play.fill" : "pause.fill",
                        label: store.isPaused ? "Resume" : "Pause"
                    ) {
                        store.isPaused ? store.resume() : store.pause()
                        Haptics.crownDetent()
                    }
                    CircleControl(systemImage: "stop.fill", label: "End session") {
                        if store.end() == nil { Haptics.sessionAbandoned() }
                    }
                }
            }
        }
        .onChange(of: store.activeSessionID) { _, _ in announcedZero = false }
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
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            HeroNumeral(measure: measure(now: now), countsDown: isCountingDown, dimmed: isOvertime(now: now))
            SubjectButton(
                name: store.subject(store.activeSubjectID)?.name,
                colorIndex: store.subject(store.activeSubjectID)?.colorIndex,
                showsDot: true
            ) {
                showingSubjects = true
            }
            .opacity(store.isPaused ? 0.5 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            if store.isPaused {
                Text("Paused")
                    .sectionLabelStyle()
                    .transition(.opacity)
            }
        }
        .animation(Motion.standard, value: store.isPaused)
    }

    /// A second layout, not a dimmed copy: minutes only, one weight lighter
    /// (dimming optically thickens strokes), tracking loosened, no controls.
    private func alwaysOn(now: Date) -> some View {
        VStack(spacing: 2) {
            HeroNumeral(
                measure: Format.minutesOnly(abs(displaySeconds(now: now))),
                tracking: Typography.Size.heroTracking + 0.6,
                weight: .regular
            )
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

    private var isCountingDown: Bool { store.activeSession?.plannedSec != nil }

    private func displaySeconds(now: Date) -> TimeInterval {
        if let remaining = store.remaining(asOf: now) { return remaining }
        return store.elapsed(asOf: now)
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
            return Format.clock(store.elapsed(asOf: now), span: store.elapsed(asOf: now))
        }
        if remaining < 0 {
            return Format.overtime(-remaining, span: -remaining)
        }
        return Format.clock(remaining, span: span)
    }
}
