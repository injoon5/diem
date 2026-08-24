import SwiftUI

/// Borderless — no background, no border. Name plus a chevron at a smaller size
/// and lower opacity; unset it reads a dimmed "Subject". The 44pt target comes
/// from padding, not from a visible shape.
struct SubjectButton: View {
    var name: String?
    var colorIndex: Int?
    var showsDot = false
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
                Text(name ?? "Subject")
                    .font(Typography.text(.body))
                    .foregroundStyle(name == nil ? .tertiary : .primary)
                    .lineLimit(1)
                    .id(name ?? "")
                    .labelSwap(reduceMotion: reduceMotion)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(.rect)
            // The capsule grows into its new width instead of snapping.
            .animation(Motion.standard, value: name)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Subject")
        .accessibilityValue(name ?? "None")
    }
}

/// The primary action: a Liquid Glass pill at the bottom of the screen.
struct GlassPill: View {
    var title: String
    var systemImage: String?
    var tint: Color = Palette.accent
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(Typography.text(.body).weight(.medium))
                    .lineLimit(1)
                    .id(title)
                    .labelSwap(reduceMotion: reduceMotion)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(PillButtonStyle(tint: tint))
        .animation(Motion.standard, value: title)
    }
}

private struct PillButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}

/// A round toolbar button for the bottom bar.
struct CircleControl: View {
    var systemImage: String
    var label: String
    var tint: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
