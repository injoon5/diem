import SwiftUI

enum Palette {
    /// International Orange, matching the Ultra Action Button. Defined in
    /// Display P3 — sRGB clips the hue visibly duller.
    static let accent = Color(.displayP3, red: 1.00, green: 0.35, blue: 0.06)

    /// Saturated orange desaturates perceptually as luminance drops, so the
    /// Always-On variant takes more chroma and less luminance to avoid turning
    /// muddy brown.
    static let accentDimmed = Color(.displayP3, red: 0.86, green: 0.26, blue: 0.02)

    /// A restrained copper used only for progress surfaces. Keeping it apart
    /// from the Action Button orange lets the ring read as data, not a call to
    /// action.
    static let ring = Color(.displayP3, red: 0.78, green: 0.31, blue: 0.12)
    static let ringDimmed = Color(.displayP3, red: 0.62, green: 0.22, blue: 0.09)

    /// The empty ring. White, not a dim orange — a desaturated accent reads as a
    /// second data value rather than an empty track.
    static let ghostTrack = Color.white.opacity(0.10)

    /// The pass already completed, left showing beneath the overflow drawn over
    /// the top of it. The ring and the complication's bar dim it by the same
    /// amount, or they are not the same reading in two shapes.
    static func lapped(_ color: Color) -> Color { color.opacity(0.42) }

    static func accent(luminanceReduced: Bool) -> Color {
        luminanceReduced ? accentDimmed : accent
    }

    static func ring(luminanceReduced: Bool) -> Color {
        luminanceReduced ? ringDimmed : ring
    }

    /// A fixed palette for subjects, excluding orange and its neighbours so a
    /// subject swatch is never mistaken for the accent. Colour never carries
    /// meaning alone — watch faces render complications monochrome.
    static let subjects: [Color] = [
        Color(.displayP3, red: 0.61, green: 0.80, blue: 0.20),  // lime
        Color(.displayP3, red: 0.30, green: 0.78, blue: 0.38),  // green
        Color(.displayP3, red: 0.13, green: 0.75, blue: 0.55),  // emerald
        Color(.displayP3, red: 0.10, green: 0.72, blue: 0.70),  // teal
        Color(.displayP3, red: 0.20, green: 0.73, blue: 0.86),  // cyan
        Color(.displayP3, red: 0.25, green: 0.60, blue: 0.94),  // sky
        Color(.displayP3, red: 0.31, green: 0.44, blue: 0.95),  // blue
        Color(.displayP3, red: 0.46, green: 0.38, blue: 0.93),  // indigo
        Color(.displayP3, red: 0.65, green: 0.36, blue: 0.92),  // violet
        Color(.displayP3, red: 0.85, green: 0.38, blue: 0.78),  // magenta
    ]

    /// A circular version of the subject spectrum. An angular gradient meets
    /// its own end at twelve o'clock, so leaving magenta at 1 and lime at 0
    /// put a hard colour edge at the most prominent point on the ring. Mixing
    /// those endpoints directly only traded the edge for a muddy warm patch.
    /// Walk back through the cool spectrum instead, then repeat lime at the
    /// end: the loop closes in both colour and direction without inventing a
    /// colour that is deliberately absent from the subject palette.
    private static let homeRingColors =
        subjects
        + Array(subjects.dropFirst().dropLast().reversed())
        + [subjects[0]]

    /// The same spectrum used by the running session ring. The home ring uses
    /// the whole palette when it is reporting the day, before the crown turns
    /// it into the single accent-colour duration control.
    ///
    /// Device-space interpolation loses chroma between distant swatches and
    /// left greyish troughs in an otherwise luminous ring. The perceptual
    /// colour space keeps the transitions even in both brightness and colour.
    static let homeRingGradient = homeRingStyle()

    /// A completed home-ring lap keeps the gradient visible beneath the turn
    /// currently being drawn, just as a solid goal ring does.
    static let homeRingLappedGradient = homeRingStyle(opacity: 0.42)

    static let homeRingCurrentLapGradient = homeRingStyle(opacity: 0.72)

    private static func homeRingStyle(opacity: Double = 1) -> AnyShapeStyle {
        let gradient = Gradient(colors: homeRingColors.map { $0.opacity(opacity) })
            .colorSpace(.perceptual)
        return AnyShapeStyle(
            AngularGradient.conicGradient(gradient, center: .center)
        )
    }

    static var subjectCount: Int { subjects.count }

    /// What each swatch is called, so a grid of ten colours is not a row of ten
    /// unnamed buttons to VoiceOver. In the order `subjects` declares them.
    private static let subjectNames = [
        "Lime", "Green", "Emerald", "Teal", "Cyan",
        "Sky", "Blue", "Indigo", "Violet", "Magenta",
    ]

    static func subjectName(_ index: Int) -> String {
        let wrapped = ((index % subjects.count) + subjects.count) % subjects.count
        return subjectNames[wrapped]
    }

    /// Free time — a session with no subject. Deliberately not a colour out of
    /// the palette above: it is the absence of one, and it has to read that way
    /// sitting beside them. Four spellings of this used to be scattered across
    /// the views, no two alike.
    static let free = Color.white.opacity(0.35)

    static func subject(_ index: Int?) -> Color {
        guard let index else { return free }
        return subjects[((index % subjects.count) + subjects.count) % subjects.count]
    }
}
