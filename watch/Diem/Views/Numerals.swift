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
    /// Draw the string as one field instead of splitting it on the colon.
    ///
    /// Splitting puts the colon in its own `Text` at half opacity, laid out on
    /// its own metrics between two digit groups whose baseline box it does not
    /// share — which is what left it sitting visibly off-centre. A clock is one
    /// field: same face, same baseline, colon included.
    var drawsAsOneField = false

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

    private struct DigitGroup: Identifiable {
        let id: Int
        let value: String
        let widest: String
    }

    private var groups: [DigitGroup] {
        if drawsAsOneField {
            return [DigitGroup(id: 0, value: value, widest: widest)]
        }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let reserved = widest.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == reserved.count else {
            let fallback = value.count > widest.count ? value : widest
            return [DigitGroup(id: 0, value: value, widest: fallback)]
        }
        return zip(parts, reserved).enumerated().map { index, pair in
            DigitGroup(id: index, value: pair.0, widest: pair.1)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(groups) { group in
                if group.id > 0 {
                    Text(":")
                        .numeralStyle(size: size, tracking: 0, weight: weight)
                        .opacity(0.5)
                }
                digits(group.value, reserving: group.widest)
            }
        }
        .animation(Motion.numeric(reduceMotion: reduceMotion), value: value)
    }

    /// The field is reserved at its widest value and the current one is drawn
    /// inside it, so shorter strings sit centred instead of shifting the layout.
    private func digits(_ text: String, reserving widest: String) -> some View {
        number(widest)
            .hidden()
            .overlay {
                number(text)
                    .contentTransition(transition)
                    .fixedSize()
            }
    }

    private func number(_ text: String) -> some View {
        styled(text)
            .numeralStyle(size: size, tracking: tracking, weight: weight)
            .lineLimit(1)
    }

    /// Colons are concatenated into the same `Text` rather than laid out beside
    /// it. One text run means the font places them — correct advance, correct
    /// baseline — while still letting them be styled down so the digits lead.
    /// A separate `Text` gets neither, which is what made them sit oddly.
    private func styled(_ text: String) -> Text {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return Text(text) }
        // The colon is centred on the x-height while the digits are lining
        // figures, so it sits low between them. Lifting it to the middle of the
        // digit is a typographic correction, not a nudge.
        let colon = Text(":")
            .foregroundStyle(.tertiary)
            .baselineOffset(size * 0.06)
        return parts.dropFirst().reduce(Text(String(parts[0]))) { running, part in
            running + colon + Text(String(part))
        }
    }
}

/// The hero numeral with its unit.
///
/// The unit is its own `Text` at ~40% of the numeral, `.regular`, `.secondary`,
/// baseline-aligned — and width-reserved, so the numeral group stays centred
/// rather than sliding as `m` becomes `h`. It sits inside the field that gets
/// replaced, so it leaves with the digits it belongs to instead of blinking
/// out from under them.
struct HeroNumeral: View {
    let measure: Format.Measure
    var size: CGFloat = Typography.Size.hero
    var tracking: CGFloat = Typography.Size.heroTracking
    var weight: Font.Weight = .medium
    var dimmed = false
    var drawsAsOneField = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What this numeral *is*, held steady while its value changes.
    private var fieldID: String { "\(measure.unit ?? "")-\(measure.motion.kind)" }
    /// Totals over an hour keep their semantic `1h 30m` value, but the units
    /// are drawn separately so they remain subordinate to the digits.
    private var isHoursMinutes: Bool {
        measure.unit == nil && measure.value.contains("h")
    }

    var body: some View {
        // One child, and it stays one child: the animation has to hang off a
        // view that outlives the `.id` below, or the transition it is meant to
        // drive is destroyed along with the numeral it was driving.
        HStack(spacing: 0) {
            Group {
                if isHoursMinutes {
                    HoursMinutesNumeral(
                        value: measure.value,
                        size: size,
                        tracking: tracking,
                        weight: weight,
                        motion: measure.motion
                    )
                } else {
                    // The unit travels with the digits. Left outside this
                    // group it wasn't part of the swap, so crossing the hour
                    // blurred `59` into `1h 00m` while the `m` beside it
                    // simply stopped existing.
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        NumeralText(
                            value: measure.value,
                            widest: measure.widest,
                            size: size,
                            tracking: tracking,
                            weight: weight,
                            motion: measure.motion,
                            drawsAsOneField: drawsAsOneField
                        )
                        if let unit = measure.unit {
                            Text("m")
                                .font(Typography.unit(size * Typography.Size.unitRatio))
                                .hidden()
                                .overlay {
                                    Text(unit)
                                        .font(Typography.unit(size * Typography.Size.unitRatio))
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                }
                        }
                    }
                }
                // `59 m` becoming `1h 30m`, or `0:00` becoming `+0:00`, is not a
                // digit rolling over — it is a different quantity in a different
                // field. Rolling one into the other reads as a glitch, so the whole
                // numeral is replaced instead.
            }
            .id(fieldID)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        }
        .animation(Motion.standard, value: fieldID)
        .foregroundStyle(dimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(measure.spoken)
    }
}

/// `1h 30m`, with the digits carrying the visual weight and the unit symbols
/// acting as quiet labels. Minutes are always present — a total that drops to
/// `1h` on the hour reads as a rounded estimate rather than a measurement — and
/// always two digits, because these units sit *inside* the numeral rather than
/// after it. A minute group that sizes to its own value pushes the `m` along
/// with it and re-centres the whole reading, which under a fast crown is the
/// labels skating about twice a second. `Format.total` pads them for that
/// reason; the group is a fixed width from `1h 00m` to `9h 59m`.
private struct HoursMinutesNumeral: View {
    let value: String
    let size: CGFloat
    let tracking: CGFloat
    let weight: Font.Weight
    let motion: NumeralMotion

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `1h 30m` split back into its two numbers. Parsing the formatted string
    /// keeps `Format` the single place that decides how a total reads.
    private var parts: (hours: String, minutes: String) {
        let pieces = value
            .split(whereSeparator: { $0 == "h" || $0 == "m" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return (pieces.first ?? "0", pieces.count > 1 ? pieces[1] : "0")
    }

    private var digitTransition: ContentTransition {
        guard !reduceMotion else { return .opacity }
        switch motion {
        case .value(let number): return .numericText(value: number)
        case .countdown: return .numericText(countsDown: true)
        case .countUp: return .numericText(countsDown: false)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            digits(parts.hours)
            unit("h")
            // A wider gap before the minutes than inside either pair, so the
            // total reads as two quantities rather than four glyphs in a row.
            Spacer().frame(width: size * 0.14)
            digits(parts.minutes)
            unit("m")
        }
        .animation(Motion.numeric(reduceMotion: reduceMotion), value: value)
    }

    private func digits(_ value: String) -> some View {
        Text(value)
            .numeralStyle(size: size, tracking: tracking, weight: weight)
            .monospacedDigit()
            .contentTransition(digitTransition)
            .fixedSize()
    }

    private func unit(_ value: String) -> some View {
        Text(value)
            .font(Typography.unit(size * Typography.Size.inlineUnitRatio))
            .foregroundStyle(.secondary)
            .fixedSize()
    }
}
