import SwiftUI

/// What a turn that has lapped casts onto the turn beneath it.
///
/// Dimming says *older*; a shadow says *over*. They are different claims and a
/// lapped ring needs both — the reason the second turn of an Activity ring is
/// legible is the hard little shadow its leading cap throws, and Apple does not
/// dim the turn underneath at all.
///
/// One definition, used by both rings. The goal ring had its own literal and
/// the session ring had none, so the two shapes of the same idea were drawn to
/// different depths on two screens the user crosses between in one tap.
/// `Scripts/ring-gallery.sh` draws the candidates as `shadow.png`.
struct RingShadow: Equatable {
    var opacity: Double
    var radius: CGFloat
    /// In the ring's own space, which is rotated a quarter turn — so this casts
    /// along the arc rather than down the screen, which is the direction the
    /// thing is actually moving.
    var offset: CGFloat

    /// Hard and tight, not deep and soft: a large radius reads as a glow around
    /// the arc, and what says *over* is a short cast with an edge on it.
    ///
    /// A stop short of the hardest the grid draws. At full opacity and a radius
    /// of one the cast grows a hard edge of its own, and a hard edge is a
    /// second thing on the ring to look at rather than a cue taken without
    /// noticing.
    static let standard = RingShadow(opacity: 0.85, radius: 1.5, offset: 1.5)

    static let none = RingShadow(opacity: 0, radius: 0, offset: 0)
}

extension View {
    /// The lapped turn's shadow, or nothing at all.
    ///
    /// `cast` rather than a caller-side `if`: a branch would give the arc two
    /// identities to SwiftUI and the crossing into a lapped ring would be a
    /// replace rather than a shadow arriving.
    ///
    /// Only cast once there is a turn underneath. A shadow means *this lies
    /// over that*, and on the first turn there is no that — the arc is running
    /// in the ring's own empty groove, and a cap throwing a shadow into it
    /// would be claiming the bar floats above its own channel.
    func ringShadow(_ shadow: RingShadow, cast: Bool = true) -> some View {
        self.shadow(
            color: .black.opacity(cast ? shadow.opacity : 0),
            radius: shadow.radius,
            x: 0,
            y: shadow.offset
        )
    }
}
