import SwiftUI

/// Two faces split by role: rounded numerals read as an instrument display and
/// their open counters survive dimming, while rounded body text reads juvenile
/// at caption sizes.
enum Typography {
    /// Tracking is size-specific — one app-wide value is wrong somewhere by
    /// definition.
    enum Size {
        /// The running clock. Set to the width of the ring it now sits inside
        /// rather than to the width of the screen — a numeral that overhangs
        /// the arc drawn behind it reads as a mistake, and this is still the
        /// largest thing on the screen by a wide margin.
        static let hero: CGFloat = 44
        /// `1:36:56` is seven advances wide, and at `hero` that overruns the
        /// ring on the smallest watch. One step down is enough.
        static let heroCompact: CGFloat = 38
        static let heroTracking: CGFloat = -1.2

        /// The total inside the Start ring. Sized to the ring rather than to
        /// the type scale — at `title` it read as a caption in a large empty
        /// circle.
        static let ringNumeral: CGFloat = 40
        static let ringNumeralTracking: CGFloat = -1.0

        static let title: CGFloat = 34
        static let titleTracking: CGFloat = -0.8

        static let label: CGFloat = 13
        static let labelTracking: CGFloat = 0.3

        /// The unit sits at a fraction of the numeral it labels rather than at
        /// a size of its own: the same numeral is drawn at 54, 40 and 34, and a
        /// fixed point size can only be right for one of them. Two fixed ones
        /// used to be declared here and read by nothing, quietly disagreeing
        /// with what the numerals actually drew.
        static let unitRatio: CGFloat = 0.40
        /// A shade smaller where the unit sits inside the reading — `1h 30m` —
        /// rather than trailing it, so it stays a label between two numbers.
        static let inlineUnitRatio: CGFloat = 0.36
    }

    /// Numerals: SF Compact Rounded, `.medium` — at display sizes bold closes
    /// the counters and costs legibility at a distance.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Units are set one step behind the numeral they label. Always-On drops
    /// the numeral a weight — dimming optically thickens strokes — and the unit
    /// has to come down with it, or a `.regular` `m` starts to lead a
    /// `.regular` number.
    static func unit(_ size: CGFloat, behind weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight == .medium ? .regular : .light, design: .rounded)
    }

    /// Text: SF Compact, the system default face.
    static func text(_ style: Font.TextStyle) -> Font { .system(style) }
}

extension View {
    /// Every numeral is monospaced, or digit widths shift as the count advances
    /// and the number twitches sideways.
    func numeralStyle(size: CGFloat, tracking: CGFloat, weight: Font.Weight = .medium) -> some View {
        self.font(Typography.numeral(size, weight: weight))
            .monospacedDigit()
            .tracking(tracking)
    }

    /// Takes the style rather than baking one in. It used to apply `.secondary`
    /// itself, which meant a caller asking for something quieter had to set it
    /// *before* this modifier to be heard at all — the innermost foreground
    /// style is the one that paints, so `.sectionLabelStyle().foregroundStyle(
    /// .tertiary)` read as a request and rendered as nothing.
    func sectionLabelStyle<S: ShapeStyle>(_ style: S = HierarchicalShapeStyle.secondary) -> some View {
        self.font(Typography.text(.caption))
            .tracking(Typography.Size.labelTracking)
            .foregroundStyle(style)
            .textCase(.uppercase)
    }
}
