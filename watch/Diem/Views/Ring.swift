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

    /// Shared with the complication's bar, which laps the same way in a
    /// different shape.
    private var lap: Lap { Lap(turns: turns) }
    private var lapped: Bool { lap.isLapped }
    private var fraction: Double { lap.fraction }

    var body: some View {
        ZStack {
            if lapped {
                Circle()
                    .stroke(Palette.lapped(color), style: .init(lineWidth: lineWidth, lineCap: .round))
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
        // Named rather than blanketed: a transaction over the whole ring also
        // clears the animation on its own frame, and the frame is exactly what
        // changes when the bars leave.
        .animation(
            isLuminanceReduced ? nil : Motion.ringMode(reduceMotion: reduceMotion),
            value: isScrubbing
        )
        .animation(
            isScrubbing || isLuminanceReduced
                ? nil
                : Motion.ringProgress(reduceMotion: reduceMotion),
            value: turns
        )
        .padding(lineWidth / 2 + 1)
        // A Circle in a non-square frame draws an ellipse. Keep it round and as
        // large as the screen allows instead of pinning a fixed size.
        .aspectRatio(1, contentMode: .fit)
    }
}
