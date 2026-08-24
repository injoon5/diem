import SwiftUI

/// Two faces split by role: rounded numerals read as an instrument display and
/// their open counters survive dimming, while rounded body text reads juvenile
/// at caption sizes.
enum Typography {
    /// Tracking is size-specific — one app-wide value is wrong somewhere by
    /// definition.
    enum Size {
        static let hero: CGFloat = 54
        /// `1:36:56` is seven advances wide, and at `hero` that overruns the
        /// smallest watch. One step down is enough — the clock is still the
        /// largest thing on the screen by a wide margin.
        static let heroCompact: CGFloat = 50
        static let heroTracking: CGFloat = -1.2
        /// The unit sits at ~40% of the numeral.
        static let heroUnit: CGFloat = 22

        /// The total inside the Start ring. Sized to the ring rather than to
        /// the type scale — at `title` it read as a caption in a large empty
        /// circle.
        static let ringNumeral: CGFloat = 40
        static let ringNumeralTracking: CGFloat = -1.0

        static let title: CGFloat = 34
        static let titleTracking: CGFloat = -0.8
        static let titleUnit: CGFloat = 14

        static let label: CGFloat = 13
        static let labelTracking: CGFloat = 0.3
    }

    /// Numerals: SF Compact Rounded, `.medium` — at display sizes bold closes
    /// the counters and costs legibility at a distance.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func unit(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
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

    func sectionLabelStyle() -> some View {
        self.font(Typography.text(.caption))
            .tracking(Typography.Size.labelTracking)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
