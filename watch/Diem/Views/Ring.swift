import SwiftUI

/// One arc, possibly lapped.
///
/// Under a full turn it is a plain arc. Past one turn the completed lap stays
/// solid and the remainder is drawn over it with a drop shadow, so an
/// overlapping band reads as in front rather than as a second colour.
struct RingArc: View {
    /// Total revolutions. 1.0 is a closed ring.
    var turns: Double
    var color: Color
    var lapColor: Color
    var lineWidth: CGFloat

    private var lapped: Bool { turns >= 1 }
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
                    .stroke(color, style: .init(lineWidth: lineWidth, lineCap: .round))
            }
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    lapped ? lapColor : color,
                    style: .init(lineWidth: lineWidth, lineCap: .round)
                )
                .shadow(color: .black.opacity(lapped ? 0.85 : 0), radius: 3, x: 0, y: 1)
        }
        .rotationEffect(.degrees(-90))
    }
}

/// The Start screen ring: today's progress at rest, the duration being scrubbed
/// while the crown turns.
///
/// The two arcs share a `matchedGeometryEffect` identity, so the change of mode
/// moves one continuous object instead of dissolving one arc into another. The
/// ghost track stays in both modes — it is what the overflow shadow falls on.
struct StartRing: View {
    var goalTurns: Double
    var scrubTurns: Double
    var isScrubbing: Bool
    var namespace: Namespace.ID
    var lineWidth: CGFloat = 9

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { Palette.accent(luminanceReduced: isLuminanceReduced) }

    var body: some View {
        ZStack {
            Circle().stroke(Palette.ghostTrack, style: .init(lineWidth: lineWidth, lineCap: .round))

            if isScrubbing {
                // One revolution is 60 minutes. Bound straight to the crown —
                // a spring here would put lag between the crown and the arc.
                RingArc(turns: scrubTurns, color: accent, lapColor: accent, lineWidth: lineWidth)
                    .matchedGeometryEffect(id: "ring.arc", in: namespace)
                    .transition(.opacity)
            } else {
                RingArc(
                    turns: goalTurns,
                    color: accent,
                    lapColor: accent.opacity(0.55),
                    lineWidth: lineWidth
                )
                .matchedGeometryEffect(id: "ring.arc", in: namespace)
                .transition(.opacity)
            }
        }
        .animation(Motion.fill(reduceMotion: reduceMotion), value: isScrubbing)
        .animation(isScrubbing ? nil : Motion.fill(reduceMotion: reduceMotion), value: goalTurns)
        .stillWhenDimmed(isLuminanceReduced)
        .padding(lineWidth / 2)
    }
}
