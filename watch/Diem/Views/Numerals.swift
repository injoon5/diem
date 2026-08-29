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
                        Group {
                            if secondsHidden {
                                struck(seconds.value, reserving: seconds.widest)
                            } else {
                                digits(seconds.value, reserving: seconds.widest)
                            }
                        }
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

    /// The seconds struck out: `:07` becomes a colon and two dashes, one mark
    /// per digit, so what is on screen still says how much is being withheld.
    ///
    /// Each mark is centred in a cell exactly one digit wide, rather than set
    /// as a string of dashes. Set as text, the gap between the pair is whatever
    /// side bearings the dash happens to carry, and the numeral's own tracking
    /// is then subtracted from it: at −1.2 on a 44pt face the two marks closed
    /// up and welded into one long stepped rule where two struck-out figures
    /// were meant. Picking a narrower dash only moved the problem — this went
    /// through the figure dash, the en dash and U+2010 looking for a glyph that
    /// would hold itself apart. In a digit-wide cell the gap is the digit
    /// advance the mark stands in for, which is the width it should have been
    /// all along, and the plain hyphen is free to be the plain hyphen.
    private func struck(_ group: String, reserving widest: String) -> some View {
        let prefix = String(group.prefix { !$0.isNumber })
        let marks = group.filter(\.isNumber).count
        // Pinned to the leading edge, so the colon lands where the colon
        // always lands. Centring a group narrower than its field slides it
        // half a digit right, and on a clock whose whole job is that nothing
        // moves, the one thing that moved was the colon.
        return number(widest)
            .hidden()
            .overlay(alignment: .leading) {
                HStack(spacing: 0) {
                    if !prefix.isEmpty {
                        number(prefix)
                    }
                    ForEach(0..<marks, id: \.self) { _ in
                        // The cell carries the digit's metrics, including the
                        // trailing give the numeral's negative tracking needs;
                        // the mark inside is set loose of both, because a mark
                        // is not a digit and tracking is a correction for
                        // digits.
                        number("8")
                            .hidden()
                            .overlay {
                                Text(verbatim: "-")
                                    .numeralStyle(size: size, tracking: 0, weight: weight)
                                    .fixedSize()
                            }
                    }
                }
                .fixedSize()
            }
    }

    /// The field is reserved at its widest value and the current one is drawn
    /// inside it, so shorter strings sit centred instead of shifting the layout.
    ///
    /// Centred is right for a value that is short because it is small — `5`
    /// where `59` fits. The seconds struck out are the exception and have
    /// their own view; see `struck(_:reserving:)`.
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
        // A total is one field from `0m` to `9h 59m`, so crossing the hour
        // does not replace the numeral. Replacing it was the first thing tried
        // and the worst: a blur replace has both readings alive in the same
        // place, and two numbers on one baseline do not blur into each other
        // the way two pictures do — for four frames `59` and `00` were
        // superimposed and the screen read `5900`.
        //
        // Ten hours and up takes a wider field and still changes field, and
        // that one is cut rather than drawn — a reading nobody reaches
        // mid-scrub.
        guard !isTotal else { return "total-\(measure.widest.count > 6)" }
        return "\(measure.unit ?? "")-\(measure.motion.kind)-\(measure.widest)"
    }
    /// A total, either side of the hour.
    ///
    /// `59m` and `1h 00m` are one reading of one quantity that happens to grow
    /// an hours place, so they go to the same renderer. `unit == "m"` is only
    /// ever a sub-hour total; nothing else in `Format` carries a unit.
    private var isTotal: Bool {
        measure.unit == "m" || (measure.unit == nil && measure.value.contains("h"))
    }
    /// Always-On is already dim. Stepping back from there costs legibility
    /// that the state doesn't need to buy twice.
    private var shownOpacity: Double {
        isLuminanceReduced ? max(0.6, prominence.opacity) : prominence.opacity
    }

    private var unitFont: Font {
        Typography.unit(size * Typography.Size.unitRatio, behind: weight)
    }
    var body: some View {
        // One child, and it stays one child: the animation has to hang off a
        // view that outlives the `.id` below, or the transition it is meant to
        // drive is destroyed along with the numeral it was driving.
        //
        // A `ZStack`, not an `HStack`. A blur replace has both numerals alive
        // at once, and side by side in a row that is what they did — the field
        // widened to hold both, so the outgoing reading slid left while the
        // incoming one arrived to its right, and the reverse on the way back
        // pushed the unit out over the ring. Stacked, the two occupy the same
        // place and the swap happens where the reading already is.
        ZStack {
            Group {
                if isTotal {
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
                // `0:00` becoming `+0:00` is not a digit rolling over — it is
                // a different quantity in a different field. Rolling one into
                // the other reads as a glitch, so the whole numeral is
                // replaced instead. A total crossing the hour is the same kind
                // of change and takes the same `.id`, but is drawn as a cut
                // rather than a replace — see `isTotal`.
            }
            .id(fieldID)
            .transition(
                isTotal
                    ? AnyTransition.identity
                    : (reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            )
        }
        // Not while dimmed: the display refreshes about once a minute there,
        // and a blur-replace queued against it lands as stutter on the wake.
        // Not for a total either — see `isTotal`. `.identity` and a nil
        // animation together are what make that a cut and not a fast fade:
        // either one alone still leaves both readings on screen for a frame.
        //
        // `swap`, not `fill`, for the field changes that are drawn: at
        // `fill`'s 0.35 response the crossing was a thing you watched happen
        // rather than something you noticed had happened.
        .animation(
            isTotal || isLuminanceReduced ? nil : Motion.swap(reduceMotion: reduceMotion),
            value: fieldID
        )
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

/// A total: `45m`, `1h 30m`. The digits carry the visual weight and the unit
/// symbols act as quiet labels.
///
/// Minutes are always present past the hour — a total that drops to `1h` reads
/// as a rounded estimate rather than a measurement — and always two digits,
/// because these units sit *inside* the numeral rather than after it. A minute
/// group that sizes to its own value pushes the `m` along with it and
/// re-centres the whole reading, which under a fast crown is the labels skating
/// about twice a second. `Format.total` pads them for that reason; the group is
/// a fixed width from `1h 00m` to `9h 59m`.
///
/// Under the hour there is no hours place and the minutes are unpadded, so the
/// group reserves two digits and centres one inside it — `5` where `59` fits,
/// without the reading shifting. Crossing the hour, that reservation is already
/// the right width for `00`, so the minutes roll in place and only the hours
/// place has to arrive.
private struct HoursMinutesNumeral: View {
    let value: String
    let size: CGFloat
    let tracking: CGFloat
    let weight: Font.Weight
    let motion: NumeralMotion

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// `1h 30m` split back into its two numbers, or `45` with no hours place.
    /// Parsing the formatted string keeps `Format` the single place that
    /// decides how a total reads.
    private var parts: (hours: String?, minutes: String) {
        let pieces = value
            .split(whereSeparator: { $0 == "h" || $0 == "m" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard value.contains("h") else { return (nil, pieces.first ?? "0") }
        return (pieces.first ?? "0", pieces.count > 1 ? pieces[1] : "0")
    }

    private var digitTransition: ContentTransition {
        motion.contentTransition(reduceMotion: reduceMotion)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            if let hours = parts.hours {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    digits(hours, reserving: String(repeating: "8", count: hours.count))
                    label("h")
                    // A wider gap before the minutes than inside either pair,
                    // so the total reads as two quantities rather than four
                    // glyphs in a row.
                    Spacer().frame(width: size * 0.14)
                }
                // Blurred in, not scaled in. Scaled was the second thing tried
                // and it read `190` for six frames: `h` is the only glyph that
                // tells `1h 00` from `190`, it is drawn at a third of the
                // digits' size, and a scale takes it below legibility while
                // the `1` beside it is still plainly a digit. A blur degrades
                // the two together — the hours place is a smudge or it is
                // `1h`, and there is no frame where it is a bare `1`.
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
            digits(parts.minutes, reserving: "88")
            label("m")
        }
        // The row is centred, so as the hours place blurs in the minutes
        // travel right into the slot they occupy in `1h 00m`, and the reverse
        // on the way down. One timing for the slide, the roll and the blur —
        // the crossing is one event, and the last time this screen ran two
        // curves against each other they were close enough to look like a
        // mistake rather than a choice.
        .animation(
            isLuminanceReduced ? nil : Motion.numeric(reduceMotion: reduceMotion),
            value: value
        )
    }

    /// The field is reserved at its widest value and the current one drawn
    /// inside it, so a shorter reading sits centred instead of moving the
    /// labels around it.
    private func digits(_ value: String, reserving widest: String) -> some View {
        number(widest)
            .hidden()
            .overlay {
                number(value)
                    .contentTransition(digitTransition)
                    .fixedSize()
            }
    }

    private func number(_ value: String) -> some View {
        Text(value)
            .numeralStyle(size: size, tracking: tracking, weight: weight)
            .monospacedDigit()
            // Tracking is applied after the last glyph as well as between
            // them, so a negative value shortens the width `Text` reports by
            // exactly that much and the last digit is drawn into space the
            // layout does not believe it has. Given back on the trailing edge,
            // to the reserved field and the value inside it alike, so nothing
            // moves. The same correction `NumeralText` makes, for the same
            // reason — these digits are set on the same face at the same
            // tracking.
            .padding(.trailing, max(0, -tracking))
    }

    private func label(_ value: String) -> some View {
        Text(value)
            .font(Typography.unit(size * Typography.Size.inlineUnitRatio, behind: weight))
            .foregroundStyle(.secondary)
            .fixedSize()
    }
}
