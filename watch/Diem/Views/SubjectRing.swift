import SwiftUI

/// The session wound onto the ring, the goal to the turn — or an hour, when
/// there is no goal to close.
///
/// A straight bar of the session — one band per run of study, in that subject's
/// colour, as long as the run — bent into a circle. Past a turn it goes round
/// again over what is already there, so the band on top is always the most
/// recent turn and the turn beneath shows through dimmed, the way the goal
/// ring's lap does.
///
/// What a turn is worth is the caller's to say. A planned session hands in the
/// time it planned, so the ring closes exactly when the session is done and
/// overtime is a second lap laid over the first — which is the same thing the
/// goal ring says about the day, in the same shape.
///
/// Where each band lands and where the colours blend is `SubjectBar`, which has
/// no SwiftUI in it and is checked by `Scripts/core-check.sh`. What is left
/// here is the drawing: which colour, how dim, and in what order.
///
/// Round at the two ends of the bar, butt everywhere inside it. A rounded end on
/// *every* band would have each one bulge over its neighbour and read as a gap
/// that isn't there — but leaving the bar's own two ends squared off was the
/// other mistake, next to a goal ring that is round at both ends. The ends are
/// drawn round underneath and the butt-capped bands are laid over the top, so
/// the only round caps left showing are the two the bar actually has.
struct SubjectRing: View {
    typealias Run = SubjectBar.Run

    var runs: [Run]
    /// What one revolution is worth. The planned time where there is one.
    var secondsPerTurn: TimeInterval = SubjectBar.secondsPerTurn
    var lineWidth: CGFloat = 6
    var lapping: Lapping = .standard

    /// How a turn that has been lapped is told apart from the turn on top of
    /// it.
    ///
    /// Three numbers rather than three literals in the body, because they only
    /// mean anything against each other and the only way to set them is to look
    /// at all three at once. `Scripts/ring-gallery.sh` draws the variants —
    /// which is how these were chosen, and how the next set should be.
    ///
    /// Two things that grid settles. A track without a scrim under it is worse
    /// than nothing: laid over a turn still at full lapped strength it lightens
    /// the old colours instead of standing apart from them. And past about a
    /// scrim of .55 the spent turn stops being visible at all, which throws
    /// away the thing it is there to say — what the last turn was spent on.
    ///
    /// The scrim and the track are only ever *seen* on the part of the circle
    /// the current turn has not reached: everything behind the arc itself is
    /// covered by the arc. That is the whole point of them. The stretch ahead
    /// of the arc used to be the last turn's colours at four-tenths, which
    /// reads as ring that is filled, and a lapped session looked like an
    /// unlapped one drawn slightly wrong.
    struct Lapping: Equatable {
        /// How much of its colour a turn keeps once a later one is laid over
        /// it.
        var lapped: Double
        /// Black over the finished turn and under the current one, across the
        /// whole circle. It is what turns "the same ring, a bit duller" into
        /// "something behind something else".
        var scrim: Double
        /// The groove the current turn runs in, drawn over the scrim. Without
        /// it the part of this turn that has not happened yet is indis-
        /// tinguishable from the part of the last one that did — which is
        /// exactly the question being asked: am I on another turn or not?
        var track: Double

        /// What the turn on top casts onto the turn beneath it.
        ///
        /// Dimming says *older*; a shadow says *over*. They are different
        /// claims and the ring needs both — the whole reason the second turn is
        /// legible on an Activity ring is the hard little shadow its leading
        /// cap throws, and Apple does not dim the turn underneath at all.
        var shadow: Shadow

        struct Shadow: Equatable {
            var opacity: Double
            var radius: CGFloat
            /// In the ring's own space, which is rotated a quarter turn — so
            /// this casts along the arc rather than down the screen, which is
            /// the direction the thing is actually moving.
            var offset: CGFloat

            static let none = Shadow(opacity: 0, radius: 0, offset: 0)
        }

        /// Deliberately not `Palette.lapped`, which is the goal lap on the
        /// Start ring and on the complication's bar — those two dim by the same
        /// amount because they are one reading in two shapes, and neither of
        /// them has a scrim over the top of it. This turn is knocked back by
        /// the scrim as well, so it starts from a little further up.
        static let standard = Lapping(
            lapped: 0.34,
            scrim: 0.45,
            track: 0.10,
            // Hard and tight, not deep and soft: a large radius reads as a glow
            // around the arc, and what says *over* is a short cast with an edge
            // on it — the shadow an Activity ring throws off its leading cap.
            //
            // A stop short of the hardest the grid draws. At full opacity and a
            // radius of one the cast has a hard edge of its own, and a hard
            // edge is a second thing on the ring to look at rather than a cue
            // you take without noticing.
            shadow: Shadow(opacity: 0.85, radius: 1.5, offset: 1.5)
        )
    }

    /// The colour a stop is drawn in: the subject's own on the turn on top, and
    /// the same colour dimmed on every turn beneath it.
    private func color(_ colorIndex: Int?, lap: Int, top: Int) -> Color {
        let raw = Palette.subject(colorIndex)
        return lap == top ? raw : raw.opacity(lapping.lapped)
    }

    /// One turn of the bar.
    ///
    /// The stops are locations on the whole turn, and so is the arc, so the
    /// gradient lands on the stroke without either having to know where the
    /// other starts.
    private func arc(_ lap: SubjectBar.Lap, top: Int) -> some View {
        Circle()
            .trim(from: lap.from, to: lap.to)
            .stroke(
                AngularGradient(
                    stops: lap.stops.map {
                        Gradient.Stop(color: color($0.colorIndex, lap: lap.id, top: top), location: $0.location)
                    },
                    center: .center
                ),
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
        let laps = SubjectBar.laps(runs, perTurn: secondsPerTurn)
        let top = laps.last?.id ?? 0
        ZStack {
            Circle()
                .stroke(Palette.ghostTrack, style: .init(lineWidth: lineWidth, lineCap: .round))

            // The bar's start, round, underneath everything: its inner half is
            // covered by the butt-capped turn drawn over it and the outer half
            // is the cap that shows.
            if let first = laps.first, let stop = first.stops.first {
                capArc(first.headBand, color: color(stop.colorIndex, lap: first.id, top: top))
            }

            // Drawn in the order the day happened, so a later turn covers an
            // earlier one exactly as winding a bar round twice would.
            //
            // The end cap goes under its own turn and over every turn before
            // it, not under all of them. Drawn with the start cap at the bottom
            // of the stack it was fine until the bar lapped — and then the
            // dimmed full turn beneath was painted straight over the overhang,
            // so a session past the hour lost the round end it still has and
            // stopped square against the turn underneath.
            ForEach(laps) { lap in
                // The turn on top gets a ground of its own, once there is
                // something underneath for it to be on top of. Knocked back
                // first, then given the same empty groove the ring starts life
                // with, so the turn in progress reads as a fresh circle laid
                // over a spent one rather than as a brighter patch of the same
                // arc.
                if lap.id == top, top > 0 {
                    Circle()
                        .stroke(
                            .black.opacity(lapping.scrim),
                            style: .init(lineWidth: lineWidth, lineCap: .round)
                        )
                    Circle()
                        .stroke(
                            .white.opacity(lapping.track),
                            style: .init(lineWidth: lineWidth, lineCap: .round)
                        )
                }
                if lap.id == top, let stop = lap.stops.last {
                    capArc(lap.tailBand, color: color(stop.colorIndex, lap: lap.id, top: top))
                        .shadow(lapping.shadow, cast: top > 0)
                }
                // No shadow on the arc itself. The arc and the cap under it
                // are the same stroke on the same path, so shadowing both drew
                // the cast twice — one from the round end and a second from the
                // butt end of the turn a hair behind it. The round cap is the
                // only edge of this turn that is over the last one and visible,
                // so it is the only thing that casts.
                arc(lap, top: top)
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2 + 1)
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension View {
    /// The lapped turn's shadow, or nothing at all.
    ///
    /// `cast` rather than a caller-side `if`: a branch would give the arc two
    /// identities to SwiftUI and the crossing into a lapped ring would be a
    /// replace rather than a shadow arriving.
    ///
    /// Only cast once there is a turn underneath. A shadow means *this lies
    /// over that*, and on the first turn there is no that — the arc is running
    /// in the ring's own empty groove, and a cap throwing a shadow into it
    /// would be claiming the bar floats above its own channel. The goal ring
    /// draws the line in the same place.
    @ViewBuilder
    func shadow(_ shadow: SubjectRing.Lapping.Shadow, cast: Bool) -> some View {
        self.shadow(
            color: .black.opacity(cast ? shadow.opacity : 0),
            radius: shadow.radius,
            x: 0,
            y: shadow.offset
        )
    }
}
