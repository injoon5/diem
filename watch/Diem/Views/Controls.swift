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

/// A round toolbar button for the bottom bar.
struct CircleControl: View {
    var systemImage: String
    var label: String
    var tint: Color = .primary
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
