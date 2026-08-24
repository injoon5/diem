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
    var countsDown = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .contentTransition(
                        reduceMotion ? .opacity : .numericText(countsDown: countsDown)
                    )
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
    var countsDown = false
    var dimmed = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            NumeralText(
                value: measure.value,
                widest: measure.widest,
                size: size,
                tracking: tracking,
                weight: weight,
                countsDown: countsDown
            )
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
        .foregroundStyle(dimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(measure.spoken)
    }
}
