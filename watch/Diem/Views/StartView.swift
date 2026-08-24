import SwiftUI

struct StartView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var crownStep: Double = 0
    @FocusState private var crownFocused: Bool
    @State private var subjectID: UUID?
    /// The picker has been opened at least once, so "Free" stays chosen instead
    /// of being overwritten by the last subject on the next appearance.
    @State private var subjectChosen = false
    /// Set while the crown is reset in code, so the reset doesn't click.
    @State private var resettingCrown = false
    @State private var showingSubjects = false
    @State private var showingSettings = false
    @State private var showingMetrics = false
    /// A fixed anchor, so the minute tick doesn't re-phase on every redraw —
    /// and the crown, which redraws this view far faster than once a minute,
    /// doesn't hand the timeline a new schedule on every event.
    @State private var anchor = Date.now

    /// The whole step the crown has settled nearest — what the numeral reads
    /// and what a tap on Start commits.
    private var crownDetent: Int { Int(crownStep.rounded()) }
    private var scrubSeconds: TimeInterval { DurationScrub.seconds(forStep: crownDetent) }
    /// The same duration without the rounding, so the arc stays welded to the
    /// crown rather than snapping a step behind it.
    private var scrubTurns: Double {
        DurationScrub.turns(forSeconds: DurationScrub.seconds(forFractionalStep: crownStep))
    }
    private var isScrubbing: Bool { crownDetent > 0 }

    var body: some View {
        TimelineView(.periodic(from: anchor, by: 60)) { context in
            content(now: context.date)
        }
        .containerBackground(.black, for: .navigation)
        // The crown drives the duration; the ring binds straight to it.
        //
        // No `by:` stride — a detented binding only ever hands back whole
        // steps, which is what made the arc move in 6° jumps. The value comes
        // back continuous and the *reading* is rounded instead, so the arc is
        // as smooth as the wrist while the number and the haptic still land on
        // exact minutes.
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownStep,
            from: Double(DurationScrub.minStep),
            through: Double(DurationScrub.maxStep),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownDetent) { old, new in
            guard old != new, !resettingCrown else {
                resettingCrown = false
                return
            }
            Haptics.crownDetent()
        }
        .toolbar {
            // Keep the two utility actions in the top corners.
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
            if !isLuminanceReduced {
                // The subject picker is a bottom-leading control, while the
                // start action stays pinned to the bottom edge instead of
                // drifting with the ring's flexible space.
                ToolbarItem(placement: .bottomBar) {
                    // Looked up once. The crown redraws this bar on every
                    // event, and the name and the colour are one subject.
                    let subject = store.subject(subjectID)
                    HStack(spacing: 6) {
                        SubjectButton(
                            name: subject?.name,
                            colorIndex: subject?.colorIndex
                        ) {
                            showingSubjects = true
                        }

                        Spacer(minLength: 0)

                        CircleControl(
                            systemImage: "play.fill",
                            label: isScrubbing ? "Start \(Format.duration(scrubSeconds))" : "Start",
                            tint: Palette.accent
                        ) {
                            start()
                        }
                    }
                }
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
            crownFocused = true
            guard !subjectChosen else { return }
            subjectID = Settings.shared.lastSubjectID
        }
    }

    private func content(now: Date) -> some View {
        ZStack {
            StartRing(
                goalTurns: store.todayProgress(asOf: now),
                scrubTurns: scrubTurns,
                isScrubbing: isScrubbing
            )
            HeroNumeral(
                measure: isScrubbing
                    ? Format.total(scrubSeconds)
                    : Format.total(store.todaySeconds(asOf: now)),
                size: Typography.Size.ringNumeral,
                tracking: Typography.Size.ringNumeralTracking
            )
            .padding(.horizontal, 10)
            // Today's total and the duration being scrubbed are different
            // quantities. Rolling one into the other would read as the number
            // counting itself down, so the swap replaces instead — in the same
            // beat as the ring's change of mode.
            .id(isScrubbing)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        }
        // Geometric centring puts the ring too low: the bottom bar carries a
        // filled accent circle and the top bar two small outlined glyphs, so
        // the heavier edge pulls the eye down. The ring is lifted to sit at the
        // optical centre of what is actually on screen.
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The ring is bounded by the height between the two bars, which is far
        // less than the width it has available. Letting it reach a little past
        // them — the way an Activity ring does — buys back the diameter.
        .padding(.vertical, -14)
        .animation(Motion.fill(reduceMotion: reduceMotion), value: isScrubbing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isScrubbing ? "Session length" : "Today")
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
