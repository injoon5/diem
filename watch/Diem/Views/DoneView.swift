import SwiftUI

/// Elapsed time, then a per-subject breakdown when the session had more than one
/// interval. Stays until tapped.
struct DoneView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: Session
    /// Closing is the root's decision, not this screen's — this is one of the
    /// three root screens rather than something presented over them.
    let onClose: () -> Void

    /// Discard has been tapped once and is waiting to be confirmed.
    @State private var discardConfirm = Confirmation()

    var body: some View {
        let measure = Format.total(session.studiedSec)
        let face = Typography.Size.summary(digits: measure.widest.filter(\.isNumber).count)
        return ScrollView {
            // Spaced by hand rather than by one stack spacing. The screen is
            // three things — a reading, a pair of actions, and a way out — and
            // an even gap everywhere made them one list of five items with the
            // total sitting in it as just another row.
            VStack(spacing: 0) {
                Text(session.isComplete ? "Complete" : "Ended")
                    .sectionLabelStyle()

                // Tight under its label: the word names this number, and a gap
                // as wide as the one below the number made it float between the
                // two.
                HeroNumeral(measure: measure, size: face.size, tracking: face.tracking)
                    .padding(.top, 2)
                    .minimumScaleFactor(0.7)

                // More than one subject, not more than one interval: a
                // session paused once and resumed on the same subject has two
                // intervals and one row, which restates the total above it.
                if session.bySubject.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(session.bySubject) { entry in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(swatch(entry.subjectID))
                                    .frame(width: 6, height: 6)
                                Text(store.subject(entry.subjectID)?.name ?? "Free")
                                    .font(Typography.text(.footnote))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(Format.total(entry.seconds).text)
                                    .font(Typography.text(.footnote))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            // One row, one reading — the way the same row
                            // reads in Metrics.
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, 10)
                }

                GlassEffectContainer(spacing: 8) {
                    VStack(spacing: 8) {
                        // Again keeps its place at the top and gives up the
                        // accent. Both capsules close the screen, and the one
                        // that finishes what just happened is the one almost
                        // everybody wants; the accent belongs to it, and so
                        // does the gesture. Repeating is the deliberate
                        // choice, which is a thing to reach for rather than
                        // the thing that happens by default.
                        EndActionButton(
                            title: "Again",
                            systemImage: "arrow.clockwise",
                            tint: .white.opacity(0.10)
                        ) { again() }

                        // The screen's primary action: pinching twice banks
                        // the session and goes back to Start. It stays Done
                        // even while the Discard question is armed — the
                        // gesture can leave a question unanswered, and the
                        // screen withdraws it on the way out, but it must
                        // never be what deletes a session.
                        EndActionButton(
                            title: "Done",
                            systemImage: "checkmark",
                            tint: Palette.accent,
                            isPrimaryGesture: true
                        ) { onClose() }
                    }
                }
                // The reading has said its piece; this is the next thing, and
                // it reads as one only if it is separated from it. Twelve, not
                // sixteen: the numeral's own descender space is already a third
                // of the gap, and the screen only fits without scrolling if
                // every gap is the one it needs rather than the one it looks
                // like it needs.
                .padding(.top, 12)

                // Last, quiet, and unadorned: throwing the session away is the
                // one action here that cannot be undone.
                //
                // And asked twice, because of that. Ending a session — which
                // keeps it — takes two taps on the screen before this one; a
                // single tap here deleted it. The second tap is the same
                // bargain the stop button makes: it withdraws itself rather
                // than sitting there, since a stale question on a wrist is an
                // accident waiting for the next tap.
                Button(role: .destructive) {
                    if discardConfirm.isArmed { discard() } else { askToDiscard() }
                } label: {
                    // Swapped through the same blur every other changing label
                    // here uses. As a plain string it snapped, under an
                    // animation modifier that had nothing to drive.
                    Text(discardConfirm.isArmed ? "Discard?" : "Discard")
                        .id(discardConfirm.isArmed)
                        .labelSwap(reduceMotion: reduceMotion)
                }
                .buttonStyle(.plain)
                // The armed state was carried by the label text alone, so
                // VoiceOver read "Discard?" with nothing to say that the button
                // had changed what it does. The hint is where "tap again"
                // belongs, and it is spoken after the label rather than
                // replacing it.
                .accessibilityLabel("Discard")
                .accessibilityHint(
                    discardConfirm.isArmed
                        ? "Discards this session. Double tap to confirm."
                        : "Double tap, then again to confirm."
                )
                .font(Typography.text(.footnote))
                // Brighter while it stands: at the same weight as the label it
                // replaces, arming it would be a question mark nobody saw.
                .foregroundStyle(discardConfirm.isArmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                .animation(Motion.swap(reduceMotion: reduceMotion), value: discardConfirm.isArmed)
                // Clear of the capsule above it, and clear of the bottom of the
                // screen: it used to sit against both, which put the one
                // irreversible action on this screen a thumb's width from the
                // one you press to keep the session.
                .padding(.top, 12)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .onAppear {
            if session.isComplete {
                Haptics.sessionComplete()
            } else {
                Haptics.stop()
            }
        }
        .onDisappear { discardConfirm.withdraw() }
    }

    private func swatch(_ id: UUID?) -> Color {
        Palette.subject(store.subject(id)?.colorIndex)
    }

    /// Same duration, and whatever was being studied when it ended — not
    /// whichever subject happened to take the most of the session.
    private func again() {
        let subjectID = session.lastSubjectID
        store.finished = nil
        store.start(subjectID: subjectID, plannedSec: session.plannedSec)
        Haptics.start()
    }

    private func askToDiscard() {
        discardConfirm.ask()
        Haptics.crownDetent()
    }

    private func discard() {
        discardConfirm.withdraw()
        store.discard(sessionID: session.id)
        Haptics.sessionAbandoned()
        onClose()
    }
}

/// One of the two glass actions that close the screen. They are stacked rather
/// than side by side — on a watch face a full-width capsule is a far easier
/// target than half of one, and neither label has to shrink to fit.
private struct EndActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    /// Whether the watch's double-tap gesture runs this control.
    ///
    /// The same flag `CircleControl` carries, for the same reason: a screen
    /// declares one primary action, and the shortcut belongs to the `Button`
    /// rather than to whatever the caller wraps it in.
    var isPrimaryGesture = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Body, not footnote. These are the two actions the screen is
            // for, set in a full-width capsule each, and at footnote they were
            // a caption floating in the middle of one.
            Label(title, systemImage: systemImage)
                .font(Typography.text(.body).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 46)
                .contentShape(.capsule)
        }
        .buttonStyle(EndActionButtonStyle(tint: tint))
        .handGestureShortcut(.primaryAction, isEnabled: isPrimaryGesture)
        .accessibilityLabel(title)
    }
}

private struct EndActionButtonStyle: ButtonStyle {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(Motion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
