import Foundation

/// The crown stepping curve: 1-minute steps to 60m, 5-minute to 4h, 15-minute
/// beyond. Detents are integers so `digitalCrownRotation` can be discrete and
/// each step can fire its own haptic.
enum DurationScrub {
    static let minStep = 0
    static let maxStep = 112  // 8h

    static func minutes(forStep step: Int) -> Int {
        let step = min(max(step, minStep), maxStep)
        switch step {
        case ...60: return step
        case ...96: return 60 + (step - 60) * 5
        default: return 240 + (step - 96) * 15
        }
    }

    static func seconds(forStep step: Int) -> TimeInterval {
        Double(minutes(forStep: step)) * 60
    }

    static func step(forMinutes minutes: Int) -> Int {
        switch minutes {
        case ...60: return max(0, minutes)
        case ...240: return 60 + (minutes - 60) / 5
        default: return min(maxStep, 96 + (minutes - 240) / 15)
        }
    }

    /// Seconds at a fractional crown position, interpolated across the
    /// stepping curve.
    ///
    /// The value that gets committed is always a whole step — this exists so
    /// the ring can track the crown continuously between two detents instead of
    /// jumping a sixth of a degree at a time.
    static func seconds(forFractionalStep step: Double) -> TimeInterval {
        let clamped = min(max(step, Double(minStep)), Double(maxStep))
        let low = Int(clamped.rounded(.down))
        let high = min(low + 1, maxStep)
        let t = clamped - Double(low)
        return seconds(forStep: low) * (1 - t) + seconds(forStep: high) * t
    }

    /// One full revolution of the ring is 60 minutes.
    static func turns(forSeconds seconds: TimeInterval) -> Double {
        seconds / 3600
    }
}

/// The daily goal: 15-minute steps from 15 minutes to 12 hours.
enum GoalScrub {
    static let minStep = 0
    static let maxStep = 47

    static func minutes(forStep step: Int) -> Int {
        (min(max(step, minStep), maxStep) + 1) * 15
    }

    static func step(forMinutes minutes: Int) -> Int {
        min(max(minutes / 15 - 1, minStep), maxStep)
    }
}
