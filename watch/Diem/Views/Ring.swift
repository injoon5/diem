import SwiftUI

/// One arc, possibly lapped.
///
/// Under a full turn it is a plain arc. Past one turn the completed lap dims
/// on the same path and the overflow restores only the completed portion. The
/// ring never grows a second track or competes with the content inside it.
struct RingArc<BaseStyle: ShapeStyle, LappedStyle: ShapeStyle, LapStyle: ShapeStyle>: View {
    /// Total revolutions. 1.0 is a closed ring.
    var turns: Double
    var color: BaseStyle
    var lappedColor: LappedStyle
    var lapColor: LapStyle
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
                    .stroke(lappedColor, style: .init(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(lapColor, style: .init(lineWidth: lineWidth, lineCap: .round))
                    // The only shadow in the ring, and it earns its place: it
                    // is what makes the second lap read as lying over the first.
                    //
                    // The session ring laps the same way and now casts the same
                    // shadow. This used to be its own literal, a good deal
                    // softer, so the two shapes of one idea sat at different
                    // depths on two screens a single tap apart.
                    .ringShadow(.standard)
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

/// Today against the goal, as a ring: one revolution is the goal met.
///
/// It doubles as the duration being scrubbed while the crown turns, and the
/// revolution keeps its meaning: the arc is what the session about to start
/// would be worth against the same goal.
///
/// One persistent arc handles both modes. The crown remains direct while
/// scrubbing; only the transition into and out of that mode is springed.
struct GoalRing: View {
    var goalTurns: Double
    var scrubTurns: Double = 0
    var isScrubbing = false
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

            // The day has the running screen's subject spectrum; the crown
            // makes the ring a duration control, so it resolves to the action
            // accent. Keep both arcs alive and crossfade them in place: the
            // new arc is ready for direct crown updates on the first detent.
            RingArc(
                turns: goalTurns,
                color: Palette.homeRingGradient,
                lappedColor: Palette.homeRingLappedGradient,
                lapColor: Palette.homeRingCurrentLapGradient,
                lineWidth: lineWidth
            )
            .opacity(isScrubbing ? 0 : 1)

            RingArc(
                turns: scrubTurns,
                color: ringColor,
                lappedColor: Palette.lapped(ringColor),
                lapColor: lapColor,
                lineWidth: lineWidth
            )
                .opacity(isScrubbing ? 1 : 0)
        }
        // Named rather than blanketed: a transaction over the whole ring also
        // clears the animation on its own frame and on the colours it is drawn
        // in, which are the parts that answer the wrist dropping.
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
