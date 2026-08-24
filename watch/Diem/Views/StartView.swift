import SwiftUI

struct StartView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var crownStep: Double = 0
    @State private var subjectID: UUID?
    /// The picker has been opened at least once, so "Free" stays chosen instead
    /// of being overwritten by the last subject on the next appearance.
    @State private var subjectChosen = false
    /// Set while the crown is reset in code, so the reset doesn't click.
    @State private var resettingCrown = false
    @State private var showingSubjects = false
    @State private var showingSettings = false
    @State private var showingMetrics = false
    @Namespace private var ring

    private var scrubSeconds: TimeInterval { DurationScrub.seconds(forStep: Int(crownStep.rounded())) }
    private var isScrubbing: Bool { scrubSeconds > 0 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
        .containerBackground(.black, for: .navigation)
        // The crown drives the duration; the ring binds straight to it.
        .focusable()
        .digitalCrownRotation(
            $crownStep,
            from: Double(DurationScrub.minStep),
            through: Double(DurationScrub.maxStep),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: Int(crownStep.rounded())) { old, new in
            guard old != new, !resettingCrown else {
                resettingCrown = false
                return
            }
            Haptics.crownDetent()
        }
        .toolbar {
            // One button per side keeps both targets at 44pt.
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingMetrics = true } label: {
                    Image(systemName: "chart.bar")
                }
                .accessibilityLabel("Metrics")
            }
        }
        .sheet(isPresented: $showingSubjects) {
            SubjectPicker(selection: subjectID) { picked in
                subjectID = picked
                subjectChosen = true
                showingSubjects = false
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingMetrics) { MetricsView() }
        .onAppear {
            guard !subjectChosen else { return }
            subjectID = Settings.shared.lastSubjectID
        }
    }

    private func content(now: Date) -> some View {
        VStack(spacing: 0) {
            ZStack {
                StartRing(
                    goalTurns: store.todayProgress(asOf: now),
                    scrubTurns: DurationScrub.turns(forSeconds: scrubSeconds),
                    isScrubbing: isScrubbing,
                    namespace: ring
                )
                HeroNumeral(
                    measure: isScrubbing
                        ? Format.total(scrubSeconds)
                        : Format.total(store.todaySeconds(asOf: now)),
                    size: Typography.Size.title,
                    tracking: Typography.Size.titleTracking
                )
                .padding(.horizontal, 10)
                // Today's total and the duration being scrubbed are different
                // quantities. Rolling one into the other would read as the
                // number counting itself down, so the swap replaces instead —
                // in the same beat as the ring's cross-fade.
                .id(isScrubbing)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
            .frame(maxHeight: .infinity)
            .animation(Motion.fill(reduceMotion: reduceMotion), value: isScrubbing)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(isScrubbing ? "Session length" : "Today")

            if !isLuminanceReduced {
                SubjectButton(
                    name: store.subject(subjectID)?.name,
                    colorIndex: store.subject(subjectID)?.colorIndex
                ) {
                    showingSubjects = true
                }

                GlassPill(
                    title: isScrubbing ? "Start \(Format.duration(scrubSeconds))" : "Start",
                    systemImage: "play.fill"
                ) {
                    start()
                }
                .padding(.bottom, 2)
            }
        }
        .stillWhenDimmed(isLuminanceReduced)
    }

    private func start() {
        let planned = isScrubbing ? Int(scrubSeconds) : nil
        store.start(subjectID: subjectID, plannedSec: planned)
        Haptics.start()
        resettingCrown = crownStep != 0
        crownStep = 0
    }
}
