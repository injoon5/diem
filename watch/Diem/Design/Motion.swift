import SwiftUI

enum Motion {
    /// Critically damped. `.spring`, not `.easeInOut`, for anything
    /// re-targetable: springs blend velocity on interrupt, easing curves restart
    /// and leave a visible seam.
    static let standard = Animation.spring(response: 0.35, dampingFraction: 1.0)

    /// Bounce only where the gesture carried momentum — the end of a crown flick.
    static let flick = Animation.spring(response: 0.35, dampingFraction: 0.74)

    /// Digit rolls. Reduce Motion swaps the roll for a plain fade.
    static func numeric(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.12) : standard
    }

    /// Ring fill on a discrete change. Reduce Motion drops the spring.
    static func fill(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.2) : standard
    }
}

extension View {
    /// The Always-On display refreshes about once a minute, so queued
    /// animations render as stutter on the next wake. Nothing moves while dimmed.
    func stillWhenDimmed(_ isLuminanceReduced: Bool) -> some View {
        transaction { transaction in
            if isLuminanceReduced { transaction.animation = nil }
        }
    }

    /// Cross-fading two different strings reads as a double image.
    func labelSwap(reduceMotion: Bool) -> some View {
        transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
    }
}
