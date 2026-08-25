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

/// The session wound onto the ring, an hour to the turn.
///
/// A straight bar of the session — one band per run of study, in that subject's
/// colour, as long as the run — bent into a circle. Past an hour it goes round
/// again over what is already there, so the band on top is always the most
/// recent hour and the turn beneath shows through dimmed, the way the goal
/// ring's lap does.
///
/// Round at the two ends of the bar, butt everywhere inside it. A rounded end on
/// *every* band would have each one bulge over its neighbour and read as a gap
/// that isn't there — but leaving the bar's own two ends squared off was the
/// other mistake, next to a goal ring that is round at both ends. The ends are
/// drawn round underneath and the butt-capped bands are laid over the top, so
/// the only round caps left showing are the two the bar actually has.
struct SubjectRing: View {
    /// A run with its colour already looked up.
    ///
    /// The ring used to take `SubjectRun` and ask the palette for a colour
    /// using the run's *subject id* — which is a `UUID`, where the palette
    /// takes an index. That did not compile, and it could not have: this view
    /// has no access to the store, so it has no way to turn an id into an index
    /// at all. Resolving it in the caller, which does, is the shape `Metrics`
    /// already uses for the same lookup.
    struct Run: Equatable {
        /// `nil` is free time — the absence of a subject, not a colour.
        var colorIndex: Int?
        var seconds: TimeInterval

        init(colorIndex: Int?, seconds: TimeInterval) {
            self.colorIndex = colorIndex
            self.seconds = seconds
        }
    }

    var runs: [Run]
    var lineWidth: CGFloat = 6

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// One revolution. The same hour the crown scrubs against, so a turn means
    /// the same thing whichever ring you are looking at.
    private static let secondsPerTurn: TimeInterval = 3600

    private struct Band: Identifiable {
        let id: Int
        let colorIndex: Int?
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
            // A run of no length is not a band, and a negative one would walk
            // the cursor backwards over the turn already drawn.
            guard run.seconds > 0 else { continue }
            let end = cursor + run.seconds / Self.secondsPerTurn
            var start = cursor
            while start < end {
                let lap = Int(start.rounded(.down))
                let stop = min(end, Double(lap + 1))
                bands.append(
                    Band(
                        id: bands.count,
                        colorIndex: run.colorIndex,
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

    /// A whole turn of the bar as one stroke, with the colour changes inside it
    /// expressed as gradient stops rather than as separate arcs.
    private struct LapArc: Identifiable {
        let id: Int
        let from: Double
        let to: Double
        let stops: [Gradient.Stop]
        /// The first and last bands of this turn, as trims. The bar's two round
        /// ends are drawn from these.
        let headBand: ClosedRange<Double>
        let tailBand: ClosedRange<Double>
    }

    /// How much of a turn a colour change is given to happen over.
    ///
    /// Roughly seven degrees — about a stroke-width of arc at the diameter this
    /// ring is drawn at, which is the distance over which two colours read as
    /// meeting rather than as one being interrupted by the other.
    private static let blend: Double = 0.02

    /// The bands grouped into turns, each turn carrying the stops that colour it.
    ///
    /// A band's colour is held flat across its whole length except for half a
    /// blend at each end that abuts a *different* colour, where the stop is
    /// pulled inwards and the gradient does the rest. Ends that are the bar's
    /// own, or that meet the same colour, or that sit on a turn boundary, are
    /// not pulled in: a turn boundary is a hard edge on purpose — it is where a
    /// later turn is laid over an earlier one.
    private func laps(_ bands: [Band], top: Int) -> [LapArc] {
        var arcs: [LapArc] = []
        var index = 0
        while index < bands.count {
            let lap = bands[index].lap
            var last = index
            while last + 1 < bands.count, bands[last + 1].lap == lap { last += 1 }
            let group = Array(bands[index...last])

            var stops: [Gradient.Stop] = []
            for (offset, band) in group.enumerated() {
                let raw = Palette.subject(band.colorIndex)
                let color = band.lap == top ? raw : Palette.lapped(raw)
                // Never more than a third of the band from either end, so a run
                // of a minute or two is still its own colour in the middle
                // rather than a smear between its neighbours.
                let room = min(Self.blend / 2, (band.to - band.from) / 3)
                let before = offset > 0 ? group[offset - 1] : nil
                let after = offset + 1 < group.count ? group[offset + 1] : nil
                let head = before.map { $0.colorIndex == band.colorIndex ? 0 : room } ?? 0
                let tail = after.map { $0.colorIndex == band.colorIndex ? 0 : room } ?? 0
                stops.append(Gradient.Stop(color: color, location: band.from + head))
                stops.append(Gradient.Stop(color: color, location: band.to - tail))
            }

            let ends = (first: group[0], last: group[group.count - 1])
            arcs.append(
                LapArc(
                    id: lap,
                    from: ends.first.from,
                    to: ends.last.to,
                    stops: stops,
                    headBand: ends.first.from...ends.first.to,
                    tailBand: ends.last.from...ends.last.to
                )
            )
            index = last + 1
        }
        return arcs
    }

    /// One turn of the bar.
    ///
    /// The stops are locations on the whole turn, and so is the arc, so the
    /// gradient lands on the stroke without either having to know where the
    /// other starts.
    private func arc(_ lap: LapArc) -> some View {
        Circle()
            .trim(from: lap.from, to: lap.to)
            .stroke(
                AngularGradient(stops: lap.stops, center: .center),
                style: .init(lineWidth: lineWidth, lineCap: .butt)
            )
    }

    /// One band, round-capped, to be laid underneath the bar.
    ///
    /// Only the overhang past the band's outer end survives what is drawn over
    /// it — that is the cap that shows. The inner end is covered by whatever
    /// abuts it, and on a bar that has lapped the head's overhang is covered by
    /// the full turn it sits on: a lapped bar quietly stops having a visible
    /// start, which is right, because it no longer has a free end there.
    ///
    /// Flat, in the colour of the band it caps — which is exactly the colour
    /// the gradient holds at that end, because the bar's own two ends are the
    /// two the blend is never pulled in from. Stroking the cap with the turn's
    /// gradient instead looks like the safer answer and is not: an angular
    /// gradient outside its own span wraps to the far end of the stop list, and
    /// the cap at the top of the ring is drawn *before* zero, so it came out in
    /// the colour of whatever was being studied last.
    ///
    /// Two things this is not. It is not the whole *turn* — laying the tail's
    /// turn over the head's put the head cap in the tail's colour. And it is
    /// not a hair of arc drawn as a dot at each end: a dot is its own circle
    /// rather than a cap on this path, and read as a bead sitting on the ring
    /// rather than as an end of it.
    private func capArc(_ band: ClosedRange<Double>, color: Color) -> some View {
        Circle()
            .trim(from: band.lowerBound, to: band.upperBound)
            .stroke(color, style: .init(lineWidth: lineWidth, lineCap: .round))
    }

    var body: some View {
        let bands = bands
        let top = bands.last?.lap ?? 0
        let laps = laps(bands, top: top)
        ZStack {
            Circle()
                .stroke(Palette.ghostTrack, style: .init(lineWidth: lineWidth, lineCap: .round))

            // The bar's two ends, round, underneath everything. The inner half
            // of each is covered by the butt-capped turn drawn over it; the
            // outer half is the cap that shows.
            if let first = laps.first, let color = first.stops.first?.color {
                capArc(first.headBand, color: color)
            }
            if let last = laps.last, let color = last.stops.last?.color {
                capArc(last.tailBand, color: color)
            }

            // Drawn in the order the day happened, so a later turn covers an
            // earlier one exactly as winding a bar round twice would.
            ForEach(laps) { lap in
                arc(lap)
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2 + 1)
        .aspectRatio(1, contentMode: .fit)
    }
}
