import WatchKit

/// Fired on the same frame as the visual change.
enum Haptics {
    static func crownDetent() { play(.click) }
    static func sessionComplete() { play(.success) }
    /// Softer than complete — abandoning isn't a failure.
    static func sessionAbandoned() { play(.retry) }
    /// The crown turned somewhere it cannot go: back past nothing at all.
    ///
    /// The same waveform as abandoning, and for the same reason — both are the
    /// watch saying *that did not happen*. Deliberately not `.failure`, which
    /// is three sharp taps and would be an alarm for what is only the end of a
    /// range, and deliberately not `.click`, which is the sound of the crown
    /// working.
    static func refused() { play(.retry) }
    static func start() { play(.start) }
    static func stop() { play(.stop) }

    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
