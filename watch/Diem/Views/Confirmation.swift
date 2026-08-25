import Foundation
import Observation

/// A question that takes itself back.
///
/// Two screens ask one: the stop button before it ends a session, and Discard
/// before it deletes one. Both work the same way and had better keep working
/// the same way — the first tap arms, the second commits, and a question left
/// standing withdraws itself, because a stale question on a wrist is an
/// accident waiting for the next tap.
@MainActor
@Observable
final class Confirmation {
    /// Long enough to read and answer, short enough that a question can't
    /// still be standing when the wrist comes back up.
    static let window: Duration = .seconds(6)

    private(set) var isArmed = false
    @ObservationIgnored private var timeout: Task<Void, Never>?

    /// Arms the question and starts the clock on it.
    func ask() {
        isArmed = true
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: Confirmation.window)
            guard !Task.isCancelled else { return }
            self?.isArmed = false
        }
    }

    /// Takes it back — answered, abandoned, or gone off screen.
    func withdraw() {
        timeout?.cancel()
        isArmed = false
    }
}
