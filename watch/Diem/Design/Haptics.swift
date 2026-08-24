import WatchKit

/// Fired on the same frame as the visual change.
enum Haptics {
    static func crownDetent() { play(.click) }
    static func sessionComplete() { play(.success) }
    /// Softer than complete — abandoning isn't a failure.
    static func sessionAbandoned() { play(.retry) }
    static func start() { play(.start) }
    static func stop() { play(.stop) }

    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
