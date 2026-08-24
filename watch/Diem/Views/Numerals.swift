import SwiftUI

/// A numeral that never moves.
///
/// `.monospacedDigit()` fixes per-digit width but not total string width, so the
/// field is reserved at the widest value it can hold and shorter strings are
/// centred inside it. Colons are drawn separately at half opacity so the digits
/// dominate, and each digit group rolls on its own.
struct NumeralText: View {
    let value: String
    let widest: String
    var size: CGFloat
    var tracking: CGFloat
    var weight: Font.Weight = .medium
    var motion: NumeralMotion = .countUp

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Reduce Motion swaps the roll for a plain fade.
    private var transition: ContentTransition {
        guard !reduceMotion else { return .opacity }
        switch motion {
        // A total can jump by any amount, so the system gets the number itself
        // and works out the direction and distance of the roll.
        case .value(let number): return .numericText(value: number)
        // A count only ever goes one way, and its magnitude means nothing.
        case .countdown: return .numericText(countsDown: true)
        case .countUp: return .numericText(countsDown: false)
        }
    }

    private var groups: [(value: String, widest: String)] {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let reserved = widest.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == reserved.count else {
            let fallback = value.count > widest.count ? value : widest
            return [(value, fallback)]
        }
        return Array(zip(parts, reserved))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Text(":")
                        .numeralStyle(size: size, tracking: 0, weight: weight)
                        .opacity(0.5)
                }
                digits(group.value, reserving: group.widest)
            }
        }
        .animation(Motion.numeric(reduceMotion: reduceMotion), value: value)
    }

    private func digits(_ text: String, reserving widest: String) -> some View {
        Text(widest)
            .numeralStyle(size: size, tracking: tracking, weight: weight)
            .hidden()
            .overlay {
                Text(text)
                    .numeralStyle(size: size, tracking: tracking, weight: weight)
                    .contentTransition(transition)
                    .fixedSize()
            }
    }
}

/// The hero numeral with its unit.
///
/// The unit is its own `Text` at ~40% of the numeral, `.regular`, `.secondary`,
/// baseline-aligned — and width-reserved, so the numeral group stays centred
/// rather than sliding as `m` becomes `h`.
struct HeroNumeral: View {
    let measure: Format.Measure
    var size: CGFloat = Typography.Size.hero
    var tracking: CGFloat = Typography.Size.heroTracking
    var weight: Font.Weight = .medium
    var dimmed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What this numeral *is*, held steady while its value changes.
    private var fieldID: String { "\(measure.unit ?? "")-\(measure.motion.kind)" }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            NumeralText(
                value: measure.value,
                widest: measure.widest,
                size: size,
                tracking: tracking,
                weight: weight,
                motion: measure.motion
            )
            // `59 m` becoming `1.2 h`, or `0:00` becoming `+0:00`, is not a
            // digit rolling over — it is a different quantity in a different
            // field. Rolling one into the other reads as a glitch, so the whole
            // numeral is replaced instead.
            .id(fieldID)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            if let unit = measure.unit {
                Text("m")
                    .font(Typography.unit(size * 0.4))
                    .hidden()
                    .overlay {
                        Text(unit)
                            .font(Typography.unit(size * 0.4))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
            }
        }
        .animation(Motion.standard, value: fieldID)
        .foregroundStyle(dimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(measure.spoken)
    }
}
