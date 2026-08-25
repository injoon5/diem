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
        ScrollView {
            VStack(spacing: 8) {
                Text(session.isComplete ? "Complete" : "Ended")
                    .sectionLabelStyle()

                HeroNumeral(
                    measure: Format.total(session.studiedSec),
                    size: Typography.Size.title,
                    tracking: Typography.Size.titleTracking
                )

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
                    .padding(.top, 2)
                }

                GlassEffectContainer(spacing: 6) {
                    VStack(spacing: 6) {
                        EndActionButton(
                            title: "Again",
                            systemImage: "arrow.clockwise",
                            tint: Palette.accent
                        ) { again() }

                        EndActionButton(
                            title: "Done",
                            systemImage: "checkmark",
                            tint: .white.opacity(0.10)
                        ) { onClose() }
                    }
                }
                .padding(.top, 2)

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
                .font(Typography.text(.footnote))
                // Brighter while it stands: at the same weight as the label it
                // replaces, arming it would be a question mark nobody saw.
                .foregroundStyle(discardConfirm.isArmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                .animation(Motion.fill(reduceMotion: reduceMotion), value: discardConfirm.isArmed)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Typography.text(.footnote).weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(EndActionButtonStyle(tint: tint))
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
