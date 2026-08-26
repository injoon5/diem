import SwiftUI

/// Borderless — no background, no border. Name plus a chevron at a smaller size
/// and lower opacity; unset it reads a dimmed "Subject". The 44pt target comes
/// from padding, not from a visible shape.
struct SubjectButton: View {
    var name: String?
    var colorIndex: Int?
    var showsDot = false
    /// What no subject reads as. A prompt on the Start screen; on the Running
    /// screen "Free" is the state the session is actually in.
    var placeholder: String = "Subject"
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if showsDot, name != nil {
                    Circle()
                        .fill(Palette.subject(colorIndex))
                        .frame(width: 6, height: 6)
                }
                Text(name ?? placeholder)
                    .font(Typography.text(.body))
                    .foregroundStyle(
                        name == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
                    )
                    .lineLimit(1)
                    // A long name shrinks a little before it is cut. `Social
                    // Studies` came out as `Social…` on the Running screen,
                    // where the chip has to fit inside a chord of the ring
                    // rather than the screen's full width — and a subject
                    // truncated mid-word is the one piece of text on that
                    // screen the user chose the wording of themselves.
                    //
                    // Seven tenths buys a few more characters before the
                    // ellipsis; it does not buy a long name. On the Running
                    // screen the chip sits inside a chord of the ring and gets
                    // about fifty points of text width, so `Social Studies`
                    // would need to come down by well over half to fit whole —
                    // past the point where it is still the same control. Names
                    // that long are cut, and cut a word later than they were.
                    .minimumScaleFactor(0.7)
                    .id(name ?? placeholder)
                    .labelSwap(reduceMotion: reduceMotion)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            // The capsule grows into its new width instead of snapping.
            .animation(Motion.standard, value: name)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Subject")
        .accessibilityValue(name ?? placeholder)
    }
}

/// The one thing the Start screen cannot say in words: that the crown does
/// something here.
///
/// Drawn beside the Digital Crown by the system rather than placed on the
/// screen. `digitalCrownAccessory` is an overlay at the crown's own position,
/// so this costs the ring no diameter and moves nothing in either bar — which
/// is the whole reason it is a crown accessory and not a caption.
///
/// The system's own indicator used to sit there and was taken away for saying
/// what the ring already says, smaller and over the top of it. This says the
/// one thing the ring cannot: that there is something to turn. It says it only
/// until the crown is turned, because an invitation that has been accepted is
/// clutter.
struct CrownHint: View {
    /// Shown while the crown is at rest and the screen is lit.
    var isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobbed = false

    var body: some View {
        Image(systemName: "digitalcrown.arrow.clockwise")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.tertiary)
            // Along the crown's own axis: a hint that moves the way the thing
            // it is pointing at moves. Two points is well under a millimetre —
            // enough to catch an eye already at that edge of the screen, not
            // enough to become the most interesting thing on it.
            .offset(y: reduceMotion ? 0 : (bobbed ? -2 : 2))
            .animation(bob, value: bobbed)
            .opacity(isVisible ? 1 : 0)
            .animation(Motion.standard, value: isVisible)
            // Nothing to say: the ring beside it already carries the label and
            // the value, and a glyph meaning "turn this" is a picture of a
            // gesture that is not how VoiceOver sets the length anyway.
            .accessibilityHidden(true)
            .onAppear { bobbed = isVisible }
            .onChange(of: isVisible) { _, visible in bobbed = visible }
    }

    /// The repeat runs only while the hint is on screen. A `repeatForever`
    /// left attached to a view faded to nothing is a timer nobody can see.
    private var bob: Animation? {
        guard isVisible, !reduceMotion else { return nil }
        return Motion.crownNudge
    }
}

/// A round toolbar button for the bottom bar.
struct CircleControl: View {
    var systemImage: String
    var label: String
    var tint: Color = .primary
    /// Whether the watch's double-tap gesture runs this control.
    ///
    /// A screen has one primary action, so this is the screen's answer to
    /// "what would you be reaching for", and it is set from where the screen
    /// knows: the Start button on the Start screen, pause on the Running one.
    /// Passed as a flag rather than applied by the caller because the shortcut
    /// belongs to a *control*, and the control is the `Button` in here.
    ///
    /// False while a sheet is up. The gesture is answered by whatever is in
    /// front of you, and a picker over this screen is not this screen.
    var isPrimaryGesture = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                // Pause becomes play, stop becomes a checkmark: the same
                // control changing what it does.
                //
                // Not `.symbolEffect(.replace)`. That draws one glyph's path
                // into the other's, and a path morph is a thing you watch — on
                // a control answering a thumb it is the slowest possible way to
                // say something instant happened. The same blur replace every
                // other label in the app swaps on, which is over before the
                // finger is off the glass.
                .id(systemImage)
                .labelSwap(reduceMotion: reduceMotion)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(GlassControlStyle(tint: tint))
        // Declared either way rather than applied conditionally: a modifier
        // that comes and goes takes the button's identity with it, and this
        // one has a flag for exactly this.
        .handGestureShortcut(.primaryAction, isEnabled: isPrimaryGesture)
        .accessibilityLabel(label)
    }
}

private struct GlassControlStyle: ButtonStyle {
    var tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(.regular.tint(tint.opacity(0.20)).interactive(), in: .circle)
            .brightness(configuration.isPressed ? 0.08 : 0)
            // Reduce Motion keeps the brightness and drops the scale: the press
            // still answers, without the thing under the finger changing size.
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(Motion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
