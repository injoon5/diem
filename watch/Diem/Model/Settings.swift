import Foundation
import Observation

/// The two settings that exist: the subject list (in SwiftData) and one number.
@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    private let defaults: UserDefaults
    private enum Key {
        static let goalMinutes = "dailyGoalMinutes"
        static let deviceToken = "deviceToken"
        static let lastSubjectID = "lastSubjectID"
        static let syncCursor = "syncCursor"
    }

    init(defaults: UserDefaults = UserDefaults(suiteName: SnapshotStore.appGroup) ?? .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.goalMinutes) == nil {
            defaults.set(120, forKey: Key.goalMinutes)
        }
    }

    var dailyGoalMinutes: Int {
        get { access(keyPath: \.dailyGoalMinutes); return defaults.integer(forKey: Key.goalMinutes) }
        set {
            withMutation(keyPath: \.dailyGoalMinutes) {
                defaults.set(max(15, min(newValue, 12 * 60)), forKey: Key.goalMinutes)
            }
        }
    }

    var dailyGoalSeconds: TimeInterval { Double(dailyGoalMinutes) * 60 }

    /// Generated once, on first launch, and shown as a pairing code on demand.
    var deviceToken: String {
        if let existing = defaults.string(forKey: Key.deviceToken) { return existing }
        let token = UUID().uuidString
        defaults.set(token, forKey: Key.deviceToken)
        return token
    }

    /// The subject the next session defaults to.
    var lastSubjectID: UUID? {
        get {
            access(keyPath: \.lastSubjectID)
            return defaults.string(forKey: Key.lastSubjectID).flatMap(UUID.init(uuidString:))
        }
        set {
            withMutation(keyPath: \.lastSubjectID) {
                defaults.set(newValue?.uuidString, forKey: Key.lastSubjectID)
            }
        }
    }

    var syncCursor: String? {
        get { defaults.string(forKey: Key.syncCursor) }
        set { defaults.set(newValue, forKey: Key.syncCursor) }
    }
}
