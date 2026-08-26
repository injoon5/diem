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
    /// The value the crown was just reset to in code, so the reset doesn't
    /// click. Cleared by the first change that is not it.
    @State private var resetTo: Double?
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
    private var isPresentingSheet: Bool { showingSubjects || showingSettings || showingMetrics }

    /// The chosen subject, if it is still one you can choose.
    ///
    /// `subject(_:)` answers for history too, so it returns a subject that has
    /// been archived or deleted — right on the Done screen, wrong here, where
    /// the Start screen went on offering a subject that Settings had just got
    /// rid of, and would have started a session under it.
    private var chosenSubject: Subject? {
        store.subject(subjectID).flatMap { $0.isVisible ? $0 : nil }
    }

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
        // The ring *is* the crown's indicator on this screen — it is welded to
        // the wrist and it is the largest thing here. The system's own green
        // bar down the right edge said the same thing again, smaller, over the
        // top of it.
        //
        // What stands in its place is not an indicator. It is the invitation to
        // turn the crown at all — the one thing the ring cannot say — and it is
        // gone the moment it is accepted, so the scrub still happens against a
        // clean edge. Custom content replaces the system bar rather than
        // joining it; `.visible` is what stops the accessory fading out while
        // the crown is idle, which is exactly when a hint is worth having.
        .digitalCrownAccessory {
            CrownHint(isVisible: !isScrubbing && !isLuminanceReduced)
        }
        .digitalCrownAccessory(.visible)
        .onChange(of: crownDetent) { _, _ in
            // The reset that follows a commit must not click. It used to arm a
            // latch that only this handler could clear — and a crown turned
            // less than half a step never changes the detent, so the reset
            // fired no change, the latch stayed armed, and it swallowed the
            // first real click of the *next* session instead. Comparing the
            // value is the same test without the state.
            guard crownStep != resetTo else { return }
            resetTo = nil
            Haptics.crownDetent()
        }
        .toolbar {
            // Nothing on screen is tappable while the wrist is down, so the
            // controls fade out — inside bars that stay exactly where they are.
            //
            // The items used to be removed instead, which handed the content
            // area both bars' height at once: the ring took most of a diameter
            // in a single frame, on a display that refreshes about once a
            // minute. A ring that changes size on the way into Always-On is the
            // one thing this screen must not do — it is the same ring, showing
            // the same day, and it should be the same size.
            //
            // Keep the two utility actions in the top corners.
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .dimmedAway(isLuminanceReduced, reduceMotion: reduceMotion)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingMetrics = true } label: {
                    Image(systemName: "chart.bar")
                }
                .accessibilityLabel("Metrics")
                .dimmedAway(isLuminanceReduced, reduceMotion: reduceMotion)
            }
            // The subject picker is a bottom-leading control, while the
            // start action stays pinned to the bottom edge instead of
            // drifting with the ring's flexible space.
            ToolbarItem(placement: .bottomBar) {
                // Looked up once. The crown redraws this bar on every
                // event, and the name and the colour are one subject.
                let subject = chosenSubject
                HStack(spacing: 6) {
                    SubjectButton(
                        name: subject?.name,
                        colorIndex: subject?.colorIndex
                    ) {
                        showingSubjects = true
                    }

                    Spacer(minLength: 0)

                    // The screen's primary action, and so what the watch's
                    // double-tap gesture runs: pinching twice starts the
                    // session the screen is already composed for — the subject
                    // chosen and whatever the crown is holding — without
                    // reaching for the glass. Not while a sheet is up: the
                    // gesture answers what is in front of you, and a picker
                    // over this screen is not this screen.
                    CircleControl(
                        systemImage: "play.fill",
                        label: isScrubbing ? "Start \(Format.duration(scrubSeconds))" : "Start",
                        tint: Palette.accent,
                        isPrimaryGesture: !isPresentingSheet
                    ) {
                        start()
                    }
                }
                .dimmedAway(isLuminanceReduced, reduceMotion: reduceMotion)
            }
        }
        // Each of these dismisses itself. Clearing the flag here as well
        // dismissed a sheet that was already going.
        .sheet(isPresented: $showingSubjects) {
            SubjectPicker(selection: chosenSubject?.id) { picked in
                subjectID = picked
                subjectChosen = true
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingMetrics) { MetricsView() }
        .onAppear {
            crownFocused = true
            guard !subjectChosen else { return }
            subjectID = Settings.shared.lastSubjectID
        }
        // A sheet takes the crown and does not give it back, and this screen
        // gave no sign that it had stopped listening — the ring simply stopped
        // answering the wrist. Focus is claimed again whenever the last sheet
        // closes.
        .onChange(of: isPresentingSheet) { _, presenting in
            guard !presenting else { return }
            crownFocused = true
        }
    }

    private func content(now: Date) -> some View {
        ZStack {
            GoalRing(
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
            // The numeral holds still while dimmed. The ring around it doesn't
            // have to, and this used to be applied to the whole screen — which
            // swallowed the one movement worth seeing.
            .stillWhenDimmed(isLuminanceReduced)
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
        // The ring's own timing, not a second one. Entering the scrub is a
        // single event and the ring and the numeral were leaving on different
        // curves — close enough to look like a mistake rather than a choice.
        .animation(Motion.ringMode(reduceMotion: reduceMotion), value: isScrubbing)
        // The bars stay, so the ring keeps its size across the crossing and
        // nothing here moves. What is left to animate is the palette stepping
        // down for the dimmed display, which crosses on the same timing as the
        // controls fading out of the bars above and below it.
        .animation(Motion.dimming(reduceMotion: reduceMotion), value: isLuminanceReduced)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isScrubbing ? "Session length" : "Today")
        // The ring's whole job is progress against the goal, and the container
        // spoke only the total — so the one thing the ring exists to show was
        // never announced.
        .accessibilityValue(ringValue(now: now))
    }

    /// What the ring reads, in words.
    private func ringValue(now: Date) -> String {
        guard !isScrubbing else { return Format.duration(scrubSeconds) }
        let studied = store.todaySeconds(asOf: now)
        let goal = store.goalSeconds
        guard goal > 0 else { return Format.duration(studied) }
        let percent = Int((studied / goal * 100).rounded())
        return "\(Format.duration(studied)) of \(Format.duration(goal)), \(percent) percent"
    }

    private func start() {
        let planned = isScrubbing ? Int(scrubSeconds) : nil
        store.start(subjectID: chosenSubject?.id, plannedSec: planned)
        Haptics.start()
        resetTo = 0
        crownStep = 0
    }
}
