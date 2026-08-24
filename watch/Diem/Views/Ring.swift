import SwiftUI

/// One arc, possibly lapped.
///
/// Under a full turn it is a plain arc. Past one turn the completed lap dims
/// on the same path and the overflow restores only the completed portion. The
/// ring never grows a second track or competes with the content inside it.
struct RingArc: View {
    /// Total revolutions. 1.0 is a closed ring.
    var turns: Double
    var color: Color
    var lapColor: Color
    var lineWidth: CGFloat

    /// Exactly one turn is a closed ring, not a lap: the overflow band only
    /// appears once there is something to draw over the top.
    private var lapped: Bool { turns > 1 }
    private var fraction: Double {
        guard turns > 0 else { return 0 }
        guard lapped else { return min(turns, 1) }
        let remainder = turns - turns.rounded(.down)
        return remainder == 0 ? 1 : remainder
    }

    var body: some View {
        ZStack {
            if lapped {
                Circle()
                    .stroke(color.opacity(0.42), style: .init(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(lapColor, style: .init(lineWidth: lineWidth, lineCap: .round))
                    // The only shadow in the ring, and it earns its place: it
                    // is what makes the second lap read as lying over the first.
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
            if !lapped {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: .init(lineWidth: lineWidth, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
    }
}

/// The Start screen ring: today's progress at rest, the duration being scrubbed
/// while the crown turns.
///
/// One persistent arc handles both modes. The crown remains direct while
/// scrubbing; only the transition into and out of that mode is springed.
struct StartRing: View {
    var goalTurns: Double
    var scrubTurns: Double
    var isScrubbing: Bool
    var lineWidth: CGFloat = 10

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringColor: Color {
        isScrubbing
            ? Palette.accent(luminanceReduced: isLuminanceReduced).opacity(0.72)
            : Palette.ring(luminanceReduced: isLuminanceReduced)
    }
    private var turns: Double { isScrubbing ? scrubTurns : goalTurns }
    private var lapColor: Color { ringColor.opacity(isScrubbing ? 0.9 : 0.72) }

    var body: some View {
        ZStack {
            // One track, one arc. The halo and inner hairline that used to sit
            // under this turned the empty ring into a murky band instead of a
            // groove for the arc to run in.
            Circle()
                .stroke(Palette.ghostTrack, style: .init(lineWidth: lineWidth, lineCap: .round))

            // One revolution is 60 minutes while scrubbing. This view stays in
            // place throughout both states, so there is no cross-fade seam.
            RingArc(turns: turns, color: ringColor, lapColor: lapColor, lineWidth: lineWidth)
        }
        .animation(Motion.ringMode(reduceMotion: reduceMotion), value: isScrubbing)
        .animation(isScrubbing ? nil : Motion.ringProgress(reduceMotion: reduceMotion), value: turns)
        .stillWhenDimmed(isLuminanceReduced)
        .padding(lineWidth / 2 + 1)
        // A Circle in a non-square frame draws an ellipse. Keep it round and as
        // large as the screen allows instead of pinning a fixed size.
        .aspectRatio(1, contentMode: .fit)
    }
}
