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
    /// Strike the seconds out of the reading, leaving dashes in their place.
    ///
    /// Always-On refreshes about once a minute, so the seconds it could draw
    /// would be a lie for most of the minute they are on screen. They used to
    /// be taken away entirely, which left a bare `24` where a clock had been —
    /// a number with no unit and no field, easily read as minutes *elapsed*.
    /// Dashes keep the reading a clock: the field, the colon and the shape of
    /// `24:--` all say the seconds exist and are simply not being counted for
    /// you right now.
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

    /// The reading either side of its last colon: the part that is always a
    /// live count, and the seconds. Each half reserves its own width, so what
    /// happens inside one cannot shift the other.
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
                if let seconds = halves.seconds {
                    // Stacked, not swapped in place: the digits and the dashes
                    // reserve the same field and cross over inside it, so the
                    // minutes in front of them never move.
                    ZStack {
                        digits(
                            secondsHidden ? Self.struckOut(seconds.value) : seconds.value,
                            reserving: seconds.widest,
                            alignment: secondsHidden ? .leading : .center,
                            // Tracking is a correction for digits, and the
                            // marks that replace them are not digits: −1.2 at
                            // this size is more than the side bearing a hyphen
                            // has, so the pair closed up and welded into one
                            // stepped mark. The field is reserved on the
                            // digits' own tracking and the mark is pinned to
                            // its leading edge, so setting this loose moves
                            // nothing.
                            tracking: secondsHidden ? 0 : nil,
                            // And a mark is not a number rolling over. The
                            // numeric transition interpolates glyphs it takes
                            // for digits, which is the other half of what was
                            // happening to the dashes.
                            transition: secondsHidden ? .identity : nil
                        )
                        // A step back while they are dashes. They are standing
                        // in for a number nobody is being told, and at full
                        // weight they read as one.
                        .foregroundStyle(
                            secondsHidden
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(.primary)
                        )
                        .id(secondsHidden)
                        .labelSwap(reduceMotion: reduceMotion)
                    }
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
        // here rather than blanketed over the view, so the seconds becoming
        // dashes can still be seen.
        .animation(
            isLuminanceReduced ? nil : Motion.numeric(reduceMotion: reduceMotion),
            value: value
        )
        .animation(Motion.dimming(reduceMotion: reduceMotion), value: secondsHidden)
    }

    /// U+2010 HYPHEN — short, with side bearings, so a pair of them reads as
    /// two marks.
    ///
    /// This was U+2012 FIGURE DASH, which is cut to exactly the width of a
    /// digit in this face: two of them meet with nothing in between and draw
    /// one long unbroken rule where two struck-out figures were meant. The en
    /// dash is barely better — half an em leaves a nick, not a gap. The hyphen
    /// is the only dash in the family narrow enough that the pair reads as a
    /// pair at the size the hero numeral is drawn.
    private static let strikeDash: Character = "\u{2010}"

    /// The seconds group with its digits struck out: `:07` becomes `:‐‐`.
    ///
    /// One mark per digit, so what is on screen still says how much is being
    /// withheld.
    private static func struckOut(_ group: String) -> String {
        let kept = group.filter { !$0.isNumber }
        let struck = group.filter(\.isNumber).count
        guard struck > 0 else { return group }
        return kept + String(repeating: String(strikeDash), count: struck)
    }

    /// The field is reserved at its widest value and the current one is drawn
    /// inside it, so shorter strings sit centred instead of shifting the layout.
    ///
    /// Centred is right for a value that is short because it is small — `5`
    /// where `59` fits. It is wrong for the seconds struck out, where the mark
    /// replaces the digits but the colon in front of them is the same colon in
    /// the same place: centring a group two glyphs narrower than its field
    /// slides that colon half a digit to the right, and on a clock whose whole
    /// job is that nothing moves, the one thing that moved was the colon.
    /// Pinned to the leading edge, the colon lands where it always lands and
    /// only the mark after it is free to be any width that looks right.
    private func digits(
        _ text: String,
        reserving widest: String,
        alignment: Alignment = .center,
        tracking overrideTracking: CGFloat? = nil,
        transition overrideTransition: ContentTransition? = nil
    ) -> some View {
        // The field is always reserved on the value's own metrics; only what is
        // drawn inside it may be set differently.
        number(widest)
            .hidden()
            .overlay(alignment: alignment) {
                number(text, tracking: overrideTracking ?? tracking)
                    .contentTransition(overrideTransition ?? transition)
                    .fixedSize()
            }
    }

    private func number(_ text: String, tracking: CGFloat? = nil) -> some View {
        let tracking = tracking ?? self.tracking
        return styled(text)
            .numeralStyle(size: size, tracking: tracking, weight: weight)
            .lineLimit(1)
            // Tracking is applied after the last glyph as well as between them,
            // so a negative value shortens the width `Text` reports by exactly
            // that much — and the last glyph is then drawn into space the
            // layout does not believe it has. At −1.2 on a 44pt face that is
            // the right arm of a `4` cut off flat where it meets the colon.
            // Given back on the trailing edge, to the reserved field and to the
            // value inside it alike, so nothing moves.
            .padding(.trailing, max(0, -tracking))
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
