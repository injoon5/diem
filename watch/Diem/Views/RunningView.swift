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
    /// What the screen is holding above and below this view, measured rather
    /// than guessed: neither number is the same on a 40mm as on a 49mm, and
    /// larger text sizes move them again.
    @State private var insets = ScreenInsets()

    /// The top band the time is drawn in, and the bottom bar the controls sit
    /// in.
    private struct ScreenInsets: Equatable {
        var top: CGFloat = 0
        var bottom: CGFloat = 0

        /// How far the middle of this view's space is from the middle of the
        /// screen. Positive means the space sits above the screen's middle,
        /// which is what an empty bar under it does.
        var drop: CGFloat { (bottom - top) / 2 }
    }

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
        // What the screen is holding either side of this view, asked rather
        // than assumed.
        //
        // A view that ignores the safe area is laid out against the whole
        // screen, and its proxy reports the insets it stepped over — which is
        // the only way this view can find out how much height the bar below it
        // is holding, and so how far the middle of the screen is from the
        // middle of the space it has been given.
        .background {
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: ScreenInsets.self) { proxy in
                    ScreenInsets(
                        top: proxy.safeAreaInsets.top,
                        bottom: proxy.safeAreaInsets.bottom
                    )
                } action: { measured in
                    insets = measured
                }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            // The bar stays in place when the wrist drops, and its contents
            // fade out inside it.
            //
            // Removing the item instead gave the ring the bar's height back, so
            // the crossing into Always-On was a ring growing *and* sliding down
            // the screen — two things at once on a display that refreshes about
            // once a minute. Faded in place, the ring keeps its diameter and the
            // crossing is the one move it is worth making: the picture sliding
            // down into the middle of the screen the controls have just left.
            //
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
                    // The screen's primary action, and so what the watch's
                    // double-tap gesture runs: pinching twice holds the
                    // session and pinching twice again lets it go, which is
                    // the one thing worth doing here without a free hand.
                    //
                    // It stays on this control while the End question is up,
                    // where the control is the way out rather than the hold.
                    // That is the right end of the bar for a gesture to land
                    // on: a double tap can take a question back, and must
                    // never be the thing that ends a session.
                    CircleControl(
                        systemImage: endConfirm.isArmed
                            ? "xmark"
                            : (store.isPaused ? "play.fill" : "pause.fill"),
                        label: endConfirm.isArmed
                            ? "Keep going"
                            : (store.isPaused ? "Resume" : "Pause"),
                        isPrimaryGesture: !showingSubjects
                    ) {
                        if endConfirm.isArmed {
                            withdrawConfirmation()
                        } else {
                            togglePause()
                        }
                    }

                    Spacer(minLength: 4)

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
                            // Allowed to shrink, and to give up its space
                            // entirely. `fixedSize()` here meant the label
                            // grew with the watch's text size while the two
                            // 44pt targets either side of it could not move
                            // — at the largest sizes that pushed the bar
                            // off the screen. The controls are the part
                            // that must survive; the word is the part that
                            // can bend.
                            .minimumScaleFactor(0.6)
                            .layoutPriority(-1)
                            .labelSwap(reduceMotion: reduceMotion)

                        Spacer(minLength: 4)
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
                .dimmedAway(isLuminanceReduced, reduceMotion: reduceMotion)
                .animation(Motion.swap(reduceMotion: reduceMotion), value: endConfirm.isArmed)
                // Pause becoming play is a symbol replace, and a symbol
                // replace needs an animation in the transaction to run in.
                .animation(Motion.swap(reduceMotion: reduceMotion), value: store.isPaused)
            }
        }
        .onChange(of: store.activeSessionID) { _, _ in
            announcedZero = false
            endConfirm.withdraw()
        }
        // A confirmation nobody answered is not a decision to hold onto.
        .onDisappear { endConfirm.withdraw() }
        // The picker dismisses itself; setting the flag here as well dismissed
        // a sheet that was already going. The same finding `SettingsView`
        // carries about `NameField`, which was fixed there and not here.
        .sheet(isPresented: $showingSubjects) {
            SubjectPicker(selection: store.activeSubjectID) { subjectID in
                store.switchSubject(to: subjectID)
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
        /// The session so far, in the order it happened: what the ring behind
        /// the clock draws. Their total is `elapsed`.
        let runs: [SubjectRun]

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

    /// Each run with its subject's palette index, looked up once per redraw.
    /// The store answers these from a cache, misses included.
    private func coloredRuns(_ runs: [SubjectRun]) -> [SubjectRing.Run] {
        runs.map { run in
            SubjectRing.Run(
                colorIndex: store.subject(run.subjectID)?.colorIndex,
                seconds: run.seconds
            )
        }
    }

    /// What the ring behind the clock says out loud. It used to say nothing, so
    /// the shape of the session was sighted-only.
    private func runsDescription(_ runs: [SubjectRun]) -> String {
        guard !runs.isEmpty else { return "Nothing yet" }
        // Runs, not totals: switching away and back is two stretches, and the
        // ring draws them apart because that is the shape of the session.
        return runs
            .map { "\(store.subject($0.subjectID)?.name ?? "Free"), \(Format.duration($0.seconds))" }
            .joined(separator: ", then ")
    }

    private func reading(at now: Date) -> Tick {
        Tick(
            remaining: store.remaining(asOf: now),
            elapsed: store.elapsed(asOf: now),
            plannedSec: store.activePlannedSec,
            runs: store.activeRuns(asOf: now)
        )
    }

    // MARK: - Layout

    /// One layout, lit or dimmed. Always-On is this clock with its seconds
    /// taken off — the reading a wrist glance can use, in the same place, at
    /// the same size — rather than a screen of its own that swaps in whole.
    private func layout(_ tick: Tick) -> some View {
        let subject = store.subject(store.activeSubjectID)
        let measure = tick.measure
        return ZStack {
            // Around the clock, not behind a text block. This was a
            // `.background` of the stack below, so its diameter came from
            // whatever the numeral and the subject button happened to measure
            // — a circle that floated at four-fifths of the screen's width,
            // clear of the bezel and close enough to the bottom bar to read as
            // fouling it. It is a screen-level ring, sized and placed exactly
            // as the Start screen's is, so tapping Start leaves it where it
            // was instead of shrinking it.
            //
            // The colours are resolved here, where the store is. The ring has
            // no way to look a subject up.
            // One revolution is the planned time, so a closed ring is the
            // session done. A free session has no such time and keeps the hour
            // the crown scrubs against.
            SubjectRing(
                runs: coloredRuns(tick.runs),
                secondsPerTurn: tick.plannedSec.map(TimeInterval.init)
                    ?? SubjectBar.secondsPerTurn,
                lineWidth: 8
            )
                // Held, the whole screen steps back together — and the ring is
                // most of the screen. It was the one thing still at full
                // brightness behind a clock that had gone quiet, which read as
                // a session still running with its number turned down. Same
                // value as the numeral's held state, so they step back as one
                // picture rather than at two depths.
                // Not dimmed when held, unlike the clock and the subject above
                // it. Tried, and it is the wrong reading: what the ring draws
                // is the session so far, and holding a session does not make
                // what you have already done less true. The clock steps back
                // because the clock is the thing that has stopped.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Session so far")
                .accessibilityValue(runsDescription(tick.runs))

            // One block, not two things at the same centre. The gap between
            // the clock and the subject is pulled in by four points, because
            // what separates them optically is not the gap but the numeral's
            // descender space and the chip's own padding — about 25 points of
            // air between two pieces of ink that belong together.
            VStack(spacing: -4) {
                // The state label is a line of the block, and the line is
                // there whether or not there is anything to say in it.
                //
                // It used to be an overlay on the whole screen, pushed down
                // from the top of the content area by a fixed 22 points — a
                // number that clears the clock at 44pt with four digits and
                // lands on top of it at 38pt with six, which is exactly what a
                // paused session over an hour draws. A hidden word of the same
                // style reserves the line, so the gap is the label's own metrics
                // at any text size, the clock cannot be collided with, and it
                // does not jump when the word arrives or goes.
                Text("Paused")
                    .sectionLabelStyle()
                    .hidden()
                    .overlay {
                        if let status = status(tick) {
                            Text(status)
                                .sectionLabelStyle()
                                .id(status)
                                .labelSwap(reduceMotion: reduceMotion)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    // Pulled under the label's own line box. The clock's
                    // frame carries ascender space above the digits, so a
                    // positive gap here is added to one that is already there —
                    // the word ends up floating a line away from the number it
                    // is about. Negative six leaves about six points of air
                    // between the two pieces of ink, which is a caption.
                    .padding(.bottom, -6)

                HeroNumeral(
                    measure: measure,
                    // Sized by the field it can grow into, seconds included, so
                    // dropping them doesn't resize what's left.
                    size: heroSize(for: measure),
                    prominence: prominence(tick),
                    drawsAsOneField: true,
                    secondsHidden: isLuminanceReduced
                )
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
                // Inset well past the clock above it. The ring is a circle and
                // this sits below its widest point, so the chord it has to fit
                // inside is a good deal shorter than the one the numeral has —
                // a long subject name ran out over the arc on both sides and
                // put the chevron behind it.
                .padding(.horizontal, 30)
                // Held, the whole screen steps back together. The numeral above
                // faded and this snapped beside it.
                .opacity(store.isPaused ? 0.5 : 1)
                .animation(Motion.fill(reduceMotion: reduceMotion), value: store.isPaused)
            }
            // Centred on the clock's weight rather than on the block's box.
            //
            // The subject's 44pt target is mostly empty air and the state
            // label's line is empty most of the time, so centring the block as
            // a box puts the clock nowhere near the middle of the ring. Padding
            // the top by `p` leaves the clock `(40 - label line - p) / 2` above
            // the centre; the label's line comes to about ten points once it is
            // pulled in, so 14 is the eight points a number with a caption
            // under it wants to be.
            .padding(.top, 14)
            // Clear of the arc on both sides at the widest the numeral gets.
            .padding(.horizontal, 14)
        }
        // The bottom bar carries two filled 44pt circles and the top of the
        // screen carries nothing, so the heavier edge pulls the eye down. The
        // ring is lifted to the optical centre of what is on screen — the same
        // correction, by the same amount, as the Start screen makes.
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The ring is bounded by the height between the bars, which is less
        // than the width beside them. Letting it reach a little past them — the
        // way an Activity ring does — buys back the diameter.
        .padding(.vertical, -14)
        // Always-On empties the bottom bar but not its height, so the whole
        // picture sat in the top two-thirds of a screen with nothing under it.
        // Dimmed, it slides down to the middle of the display, plus the six
        // points of optical lift above — a correction for weight that is no
        // longer on screen.
        //
        // Half the bar is not that distance. This view's space is short of the
        // screen at *both* ends — the band the time is drawn in above it as
        // well as the bar below — so its middle is already the difference of
        // the two below the screen's, and dropping it by half the bar alone
        // overshot by half the band above. On a 46mm that is ten points, which
        // is a ring visibly hanging low on a screen with nothing else on it.
        //
        // An offset, not a change of layout. The ring keeps its diameter across
        // the crossing, one translation carries the arc and the clock inside it
        // together, and a translation is the cheapest thing there is to animate
        // on a display about to drop to a refresh a minute.
        .offset(y: isLuminanceReduced ? insets.drop + 6 : 0)
        .animation(Motion.dimming(reduceMotion: reduceMotion), value: isLuminanceReduced)
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
    ///
    /// Counted in digits rather than characters. The threshold was six
    /// characters, which put `+00:00` — six — at the full 44pt while `0:00:00`
    /// — seven — dropped a step, even though the overtime field carries a sign
    /// on top of the same four digits and the colon is drawn narrower than a
    /// digit is. Five digits or more is one step down, whatever punctuation
    /// happens to be around them.
    private func heroSize(for measure: Format.Measure) -> CGFloat {
        let digits = measure.widest.filter(\.isNumber).count
        return digits > 4 ? Typography.Size.heroCompact : Typography.Size.hero
    }
}
