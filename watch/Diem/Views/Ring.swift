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

/// Today against the goal, as a ring: one revolution is the goal met.
///
/// It doubles as the duration being scrubbed while the crown turns, where one
/// revolution is an hour instead.
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

/// Today's study wound onto the ring, an hour to the turn.
///
/// A straight bar of the day — one band per run, in that subject's colour, as
/// long as the run — bent into a circle. Past an hour it goes round again over
/// what is already there, so the band on top is always the most recent hour and
/// the turn beneath shows through dimmed, the way the goal ring's lap does.
///
/// Butt caps, not round: these bands abut, and a rounded end on each would have
/// every band bulge over its neighbour and read as a gap that isn't there.
struct SubjectRing: View {
    var runs: [SubjectRun]
    var lineWidth: CGFloat = 6

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// One revolution. The same hour the crown scrubs against, so a turn means
    /// the same thing whichever ring you are looking at.
    private static let secondsPerTurn: TimeInterval = 3600

    private struct Band: Identifiable {
        let id: Int
        let subjectID: UUID?
        /// Which turn of the ring this piece lies on.
        let lap: Int
        let from: Double
        let to: Double
    }

    /// The day laid end to end, then cut at every turn of the ring.
    private var bands: [Band] {
        var bands: [Band] = []
        var cursor: Double = 0
        for run in runs {
            let end = cursor + run.seconds / Self.secondsPerTurn
            var start = cursor
            while start < end {
                let lap = Int(start.rounded(.down))
                let stop = min(end, Double(lap + 1))
                bands.append(
                    Band(
                        id: bands.count,
                        subjectID: run.subjectID,
                        lap: lap,
                        from: start - Double(lap),
                        to: stop - Double(lap)
                    )
                )
                start = stop
            }
            cursor = end
        }
        return bands
    }

    var body: some View {
        let bands = bands
        let top = bands.last?.lap ?? 0
        ZStack {
            Circle()
                .stroke(Palette.ghostTrack, style: .init(lineWidth: lineWidth, lineCap: .round))

            // Drawn in the order the day happened, so a later turn covers an
            // earlier one exactly as winding a bar round twice would.
            ForEach(bands) { band in
                let color = Palette.subject(band.subjectID)
                Circle()
                    .trim(from: band.from, to: band.to)
                    .stroke(
                        band.lap == top ? color : Palette.lapped(color),
                        style: .init(lineWidth: lineWidth, lineCap: .butt)
                    )
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2 + 1)
        .aspectRatio(1, contentMode: .fit)
    }
}
