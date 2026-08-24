import Foundation

/// How a numeral should roll when it changes.
///
/// `.numericText(value:)` hands the system the actual number, so it works out
/// both the direction and the size of the jump — right for a total that can
/// move by any amount. A count has a known direction and no meaningful
/// magnitude, so it gets `.numericText(countsDown:)` instead.
enum NumeralMotion: Equatable {
    case value(Double)
    case countdown
    case countUp

    /// Which kind of field this is, stable as the value inside it changes — so
    /// a numeral can tell "the number moved" from "this is a different number
    /// now" and pick a roll or a replace accordingly.
    var kind: Int {
        switch self {
        case .value: 0
        case .countdown: 1
        case .countUp: 2
        }
    }
}

/// The number formats, and — just as important — the widest string each field
/// can ever hold, so a hero numeral can reserve its frame and never shift.
enum Format {
    /// A numeral and its unit, kept apart so the unit can be its own `Text` at
    /// ~40% of the numeral size.
    struct Measure: Equatable {
        var value: String
        var unit: String?
        /// The widest value this field can produce, for frame reservation.
        var widest: String
        var spoken: String
        var motion: NumeralMotion
    }

    /// Totals: `0 m`, `45 m`, `1h 30m`. Past an hour the minutes stay on
    /// screen — `1h` alone reads as an estimate, `1h 00m` reads as a reading.
    static func total(_ seconds: TimeInterval) -> Measure {
        let seconds = max(0, seconds)
        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return Measure(
                value: "\(minutes)",
                unit: "m",
                widest: "59",
                spoken: "\(minutes) minute\(minutes == 1 ? "" : "s")",
                motion: .value(Double(minutes))
            )
        }
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return Measure(
            // Zero-padded, for the same reason the running clock pads: the
            // minutes are the last digits before the `m`, so a leading digit
            // appearing or dropping drags the unit labels sideways. Scrubbed
            // fast, `1h 5m` to `1h 10m` to `1h 15m` is that shift landing
            // twice a second.
            value: String(format: "%dh %02dm", hours, minutes),
            unit: nil,
            widest: "88h 88m",
            spoken: "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s")",
            motion: .value(Double(totalMinutes))
        )
    }

    /// A running count: `25:00`, and `1:25:00` once it runs past an hour.
    /// Timed sessions count down, free ones up.
    static func clock(
        _ seconds: TimeInterval,
        span: TimeInterval? = nil,
        countsDown: Bool = true
    ) -> Measure {
        let total = Int(max(0, seconds).rounded(countsDown ? .up : .down))
        let widest = (span ?? seconds) >= 3600 ? "0:00:00" : "00:00"
        return Measure(
            value: hms(total, forceHours: widest.count > 5),
            unit: nil,
            widest: widest,
            spoken: spoken(total),
            motion: countsDown ? .countdown : .countUp
        )
    }

    /// Overtime: `+3:20`, shown dimmer.
    static func overtime(_ seconds: TimeInterval, span: TimeInterval? = nil) -> Measure {
        let total = Int(max(0, seconds).rounded(.down))
        let widest = (span ?? seconds) >= 3600 ? "+0:00:00" : "+00:00"
        return Measure(
            value: "+" + hms(total, forceHours: widest.count > 6),
            unit: nil,
            widest: widest,
            spoken: "\(spoken(total)) over",
            motion: .countUp
        )
    }

    /// The Always-On layout drops to minutes only.
    static func minutesOnly(_ seconds: TimeInterval) -> Measure {
        let minutes = Int(max(0, seconds) / 60)
        return Measure(
            value: "\(minutes)",
            unit: "m",
            widest: "888",
            spoken: "\(minutes) minutes",
            motion: .value(Double(minutes))
        )
    }

    /// A duration being scrubbed: `25m`, `1h 30m`, `2h 0m`. Minutes are never
    /// dropped — the same reading rule the hero numeral follows. Unpadded,
    /// unlike the numeral: this one is prose, set in a label that is free to
    /// take whatever width it needs.
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        guard minutes >= 60 else { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private static func hms(_ total: Int, forceHours: Bool) -> String {
        let (hours, minutes, seconds) = (total / 3600, (total % 3600) / 60, total % 60)
        if hours > 0 || forceHours {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        // Minutes are zero-padded so the running clock holds its width as the
        // leading digit drops — `25:00` to `09:59` is the same five characters.
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func spoken(_ total: Int) -> String {
        let (hours, minutes, seconds) = (total / 3600, (total % 3600) / 60, total % 60)
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if hours == 0 && seconds > 0 { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.isEmpty ? "zero" : parts.joined(separator: " ")
    }
}
