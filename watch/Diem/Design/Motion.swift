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

    /// The ring only springs for a discrete mode change. Crown updates remain
    /// unanimated so the display stays physically attached to the crown.
    static func ringMode(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .linear(duration: 0.12)
            : .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)
    }

    /// The crossing into and out of Always-On, where both bars leave and the
    /// ring takes back the height between them.
    ///
    /// Critically damped and short on purpose. The display drops to about one
    /// refresh a minute on the way down, so anything with overshoot risks being
    /// caught mid-bounce and held there until the wrist comes back up.
    static func dimming(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .linear(duration: 0.16)
            : .spring(response: 0.3, dampingFraction: 1.0)
    }

    /// A recorded total arrives infrequently, so it can settle softly without
    /// looking like a timer or introducing lag into direct manipulation.
    static func ringProgress(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .linear(duration: 0.16)
            : .spring(response: 0.5, dampingFraction: 0.94, blendDuration: 0.1)
    }
}

extension View {
    /// The Always-On display refreshes about once a minute, so queued
    /// animations render as stutter on the next wake. Nothing moves while
    /// dimmed.
    ///
    /// Scope this to what actually animates on a value — a numeral rolling, an
    /// arc springing. Wrapped around a whole screen it also swallows the
    /// layout change that *is* the crossing, which is the one movement here
    /// worth seeing.
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
