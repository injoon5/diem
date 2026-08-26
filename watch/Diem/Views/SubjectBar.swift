import Foundation

/// The geometry of the session bar that `SubjectRing` winds onto a circle:
/// where each run lands, where the turns cut it, and where the colour changes
/// blend into one another.
///
/// Kept apart from the view, and free of SwiftUI, for the same reason `Scrub`
/// is: these are decisions about numbers, and numbers can be checked. A ring is
/// a picture, and a picture drawn wrong looks like a picture. Every case that
/// is awkward to reach on a wrist — a subject changed two seconds ago, a dozen
/// subjects in an hour, a session past the turn — is a list of doubles here.
enum SubjectBar {
    /// A run with its colour already looked up.
    ///
    /// The ring has no access to the store, so it cannot turn a subject id into
    /// a palette index; the caller, which does, resolves it.
    struct Run: Equatable {
        /// `nil` is free time — the absence of a subject, not a colour.
        var colorIndex: Int?
        var seconds: TimeInterval

        init(colorIndex: Int?, seconds: TimeInterval) {
            self.colorIndex = colorIndex
            self.seconds = seconds
        }
    }

    /// One revolution, when nothing else says otherwise: the hour the crown
    /// scrubs against, so a turn means the same thing on both screens.
    ///
    /// A session with a planned time hands its own number in instead, and then
    /// a closed ring is the session done rather than an hour gone — which is
    /// the reading somebody who set a goal actually wants. Free sessions have
    /// no such number and keep the hour.
    static let secondsPerTurn: TimeInterval = 3600

    /// How much of a turn a colour change is given to happen over.
    ///
    /// Roughly seven degrees — about a stroke-width of arc at the diameter this
    /// ring is drawn at, which is the distance over which two colours read as
    /// meeting rather than as one being interrupted by the other.
    static let blend: Double = 0.02

    /// A stretch of one colour lying on one turn of the ring.
    struct Band: Equatable, Identifiable {
        let id: Int
        let colorIndex: Int?
        /// Which turn of the ring this piece lies on.
        let lap: Int
        let from: Double
        let to: Double

        var length: Double { to - from }
    }

    /// A colour held at a point along the turn. Two per band: one where it
    /// takes over and one where it starts giving way.
    struct Stop: Equatable {
        let colorIndex: Int?
        let location: Double
    }

    /// A whole turn of the bar as one stroke, with the colour changes inside it
    /// expressed as gradient stops rather than as separate arcs.
    struct Lap: Equatable, Identifiable {
        let id: Int
        let from: Double
        let to: Double
        let stops: [Stop]
        /// The first and last bands of this turn, as trims. The bar's two round
        /// ends are drawn from these.
        let headBand: ClosedRange<Double>
        let tailBand: ClosedRange<Double>
    }

    /// The day laid end to end, then cut at every turn of the ring.
    ///
    /// `perTurn` is what one revolution is worth. A planned session passes its
    /// own length; anything else leaves it alone. Nought or less is not a
    /// length — it would divide the whole bar to infinity — so it falls back
    /// to the hour rather than drawing nothing.
    static func bands(_ runs: [Run], perTurn: TimeInterval = secondsPerTurn) -> [Band] {
        let turn = perTurn > 0 ? perTurn : secondsPerTurn
        var bands: [Band] = []
        var cursor: Double = 0
        for run in runs {
            // A run of no length is not a band, and a negative one would walk
            // the cursor backwards over the turn already drawn.
            guard run.seconds > 0 else { continue }
            let end = cursor + run.seconds / turn
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

    /// The furthest turn reached — the one drawn at full strength, with every
    /// turn under it dimmed.
    static func top(_ bands: [Band]) -> Int { bands.last?.lap ?? 0 }

    /// The bands grouped into turns, each turn carrying the stops that colour it.
    ///
    /// A band's colour is held flat across its whole length except for half a
    /// blend at each end that abuts a *different* colour, where the stop is
    /// pulled inwards and the gradient does the rest. Ends that are the bar's
    /// own, or that meet the same colour, or that sit on a turn boundary, are
    /// not pulled in: a turn boundary is a hard edge on purpose — it is where a
    /// later turn is laid over an earlier one.
    static func laps(_ runs: [Run], perTurn: TimeInterval = secondsPerTurn) -> [Lap] {
        laps(bands(runs, perTurn: perTurn))
    }

    static func laps(_ bands: [Band]) -> [Lap] {
        var arcs: [Lap] = []
        var index = 0
        while index < bands.count {
            let lap = bands[index].lap
            var last = index
            while last + 1 < bands.count, bands[last + 1].lap == lap { last += 1 }
            let group = Array(bands[index...last])

            var stops: [Stop] = []
            for (offset, band) in group.enumerated() {
                let before = offset > 0 ? group[offset - 1] : nil
                let after = offset + 1 < group.count ? group[offset + 1] : nil
                stops.append(Stop(colorIndex: band.colorIndex, location: band.from + room(band, meeting: before)))
                stops.append(Stop(colorIndex: band.colorIndex, location: band.to - room(band, meeting: after)))
            }

            let ends = (first: group[0], last: group[group.count - 1])
            arcs.append(
                Lap(
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

    /// How far into `band` the stop at the join with `neighbour` is pulled.
    ///
    /// Half a blend, but never more than a third of *either* band from the
    /// join. Clamping against this band alone was not enough: it kept a long
    /// run's own half-blend when the run that follows it is seconds old, so the
    /// twenty minutes behind you got a full seven degrees to fade over and the
    /// subject you just switched to had a tenth of a degree to be its own
    /// colour in. What you saw for the first half-minute of a new subject was
    /// the old one washing out, not the new one starting. A join is one event
    /// and both sides give up the same amount of arc to it.
    private static func room(_ band: Band, meeting neighbour: Band?) -> Double {
        guard let neighbour, neighbour.colorIndex != band.colorIndex else { return 0 }
        return min(blend / 2, band.length / 3, neighbour.length / 3)
    }
}
