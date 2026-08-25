import SwiftUI

extension NumeralMotion {
    /// How a change in this field is drawn. Reduce Motion swaps the roll for a
    /// plain fade. Lives here rather than in `Format`, which stays free of
    /// SwiftUI so the number rules can be compiled and tested anywhere.
    func contentTransition(reduceMotion: Bool) -> ContentTransition {
        guard !reduceMotion else { return .opacity }
        switch self {
        // A total can jump by any amount, so the system gets the number itself
        // and works out the direction and distance of the roll.
        case .value(let number): return .numericText(value: number)
        // A count only ever goes one way, and its magnitude means nothing.
        case .countdown: return .numericText(countsDown: true)
        case .countUp: return .numericText(countsDown: false)
        }
    }
}

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
    /// Drop the seconds off the end of the reading.
    ///
    /// Always-On is the same clock with its last two digits taken away, not a
    /// screen of its own, so they leave on a slide and come back the same way.
    var secondsHidden = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var transition: ContentTransition {
        motion.contentTransition(reduceMotion: reduceMotion)
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

    /// The reading either side of its last colon: what stays when the seconds
    /// are dropped, and the seconds themselves. Each half reserves its own
    /// width, so dropping one cannot shift the other.
    private var halves: (head: DigitGroup, seconds: DigitGroup?) {
        let whole = DigitGroup(id: 0, value: value, widest: widest)
        guard value.filter({ $0 == ":" }).count == widest.filter({ $0 == ":" }).count,
              let valueCut = value.lastIndex(of: ":"),
              let widestCut = widest.lastIndex(of: ":")
        else { return (whole, nil) }
        return (
            DigitGroup(id: 0, value: String(value[..<valueCut]), widest: String(widest[..<widestCut])),
            DigitGroup(id: 1, value: String(value[valueCut...]), widest: String(widest[widestCut...]))
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            if drawsAsOneField {
                let halves = halves
                digits(halves.head.value, reserving: halves.head.widest)
                if let seconds = halves.seconds, !secondsHidden {
                    digits(seconds.value, reserving: seconds.widest)
                        // Out to the trailing edge, fading as it goes, while
                        // what's left recentres in the space it gave up.
                        .transition(
                            reduceMotion
                                ? AnyTransition.opacity
                                : AnyTransition.move(edge: .trailing).combined(with: .opacity)
                        )
                }
            } else {
                ForEach(groups) { group in
                    if group.id > 0 {
                        Text(":")
                            .numeralStyle(size: size, tracking: 0, weight: weight)
                            .opacity(0.5)
                    }
                    digits(group.value, reserving: group.widest)
                }
            }
        }
        // Nothing rolls while dimmed — the display refreshes about once a
        // minute, and a queued roll lands as stutter on the next wake. Named
        // here rather than blanketed over the view, so the seconds leaving can
        // still be seen.
        .animation(
            isLuminanceReduced ? nil : Motion.numeric(reduceMotion: reduceMotion),
            value: value
        )
        .animation(Motion.dimming(reduceMotion: reduceMotion), value: secondsHidden)
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
    /// How present the numeral is.
    ///
    /// A clock that is counting has the screen. Past its deadline it steps
    /// back — the session has already done what was asked of it — and held it
    /// steps back further, because it is no longer measuring anything and
    /// should stop insisting that it is.
    enum Prominence {
        case counting
        case overtime
        case held

        var opacity: Double {
            switch self {
            case .counting: 1
            case .overtime: 0.6
            case .held: 0.45
            }
        }
    }

    let measure: Format.Measure
    var size: CGFloat = Typography.Size.hero
    var tracking: CGFloat = Typography.Size.heroTracking
    var weight: Font.Weight = .medium
    var prominence: Prominence = .counting
    var drawsAsOneField = false
    var secondsHidden = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// What this numeral *is*, held steady while its value changes.
    ///
    /// The reserved width is part of that. An open-ended session reaching an
    /// hour goes from `59:59` to `1:00:00` — a wider field, a smaller face and
    /// a digit group that wasn't there before, all of which used to arrive
    /// between one second and the next with the numeral treating it as the
    /// same field simply rolling.
    private var fieldID: String {
        "\(measure.unit ?? "")-\(measure.motion.kind)-\(measure.widest)"
    }
    /// Always-On is already dim. Stepping back from there costs legibility
    /// that the state doesn't need to buy twice.
    private var shownOpacity: Double {
        isLuminanceReduced ? max(0.6, prominence.opacity) : prominence.opacity
    }

    private var unitFont: Font {
        Typography.unit(size * Typography.Size.unitRatio, behind: weight)
    }
    /// Totals over an hour keep their semantic `1h 30m` value, but the units
    /// are drawn separately so they remain subordinate to the digits.
    private var isHoursMinutes: Bool {
        measure.unit == nil && measure.value.contains("h")
    }

    var body: some View {
        // One child, and it stays one child: the animation has to hang off a
        // view that outlives the `.id` below, or the transition it is meant to
        // drive is destroyed along with the numeral it was driving.
        //
        // A `ZStack`, not an `HStack`. A blur replace has both numerals alive
        // at once, and side by side in a row that is what they did — the field
        // widened to hold both, so `59m` slid left while `1h 00m` arrived to
        // its right, and the reverse on the way back down pushed the `m` out
        // over the ring. Stacked, the two occupy the same place and the swap
        // happens where the reading already is.
        ZStack {
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
                            drawsAsOneField: drawsAsOneField,
                            secondsHidden: secondsHidden
                        )
                        if let unit = measure.unit {
                            Text("m")
                                .font(unitFont)
                                .hidden()
                                .overlay {
                                    Text(unit)
                                        .font(unitFont)
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
        // Not while dimmed: the display refreshes about once a minute there,
        // and a blur-replace queued against it lands as stutter on the wake.
        //
        // `swap`, not `fill`: crossing the hour is one reading becoming
        // another, and at `fill`'s 0.35 response the crossing was a thing you
        // watched happen rather than something you noticed had happened.
        .animation(isLuminanceReduced ? nil : Motion.swap(reduceMotion: reduceMotion), value: fieldID)
        .opacity(shownOpacity)
        // Suppressed while dimmed like everything else on this screen: the
        // display refreshes about once a minute there, and a fade queued
        // against it lands as stutter on the wake.
        .animation(
            isLuminanceReduced ? nil : Motion.fill(reduceMotion: reduceMotion),
            value: shownOpacity
        )
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
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// `1h 30m` split back into its two numbers. Parsing the formatted string
    /// keeps `Format` the single place that decides how a total reads.
    private var parts: (hours: String, minutes: String) {
        let pieces = value
            .split(whereSeparator: { $0 == "h" || $0 == "m" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return (pieces.first ?? "0", pieces.count > 1 ? pieces[1] : "0")
    }

    private var digitTransition: ContentTransition {
        motion.contentTransition(reduceMotion: reduceMotion)
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
        // The sibling above suppresses its roll while dimmed; this one did not,
        // and it is the numeral the Start screen shows in Always-On once the
        // day is past an hour.
        .animation(
            isLuminanceReduced ? nil : Motion.numeric(reduceMotion: reduceMotion),
            value: value
        )
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
            .font(Typography.unit(size * Typography.Size.inlineUnitRatio, behind: weight))
            .foregroundStyle(.secondary)
            .fixedSize()
    }
}
