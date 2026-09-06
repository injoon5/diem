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
        static let deletedIntervals = "deletedIntervalIDs"
        static let subjectsPushedAt = "subjectsPushedAt"
        static let subjectsPulledAt = "subjectsPulledAt"
        static let retired = "syncRetired"
        static let activeSession = "activeSessionID"
        static let pendingSubject = "pendingSubjectID"
        /// What a pending choice of *no* subject is written as. Anything that
        /// isn't a UUID would do; this one reads.
        static let noSubject = "none"
    }

    init(defaults: UserDefaults = UserDefaults(suiteName: SnapshotStore.appGroup) ?? .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.goalMinutes) == nil {
            defaults.set(120, forKey: Key.goalMinutes)
        }
        // Minted once, here, rather than on the first read of `deviceToken`.
        // That read happens in whichever process gets there first, and two
        // processes racing it used to be able to mint two tokens and split one
        // watch's history across two devices on the server.
        if defaults.string(forKey: Key.deviceToken) == nil {
            defaults.set(UUID().uuidString, forKey: Key.deviceToken)
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

    /// Minted once, in `init`. A pure read, so it is safe from anywhere.
    var deviceToken: String {
        defaults.string(forKey: Key.deviceToken) ?? ""
    }

    /// Set when the server stops recognising this watch — which happens when
    /// the profile was moved to a replacement watch from the web.
    ///
    /// The app goes on working: everything here is local, and sync was always
    /// allowed to fail quietly. But *permanently* refused is not the same as
    /// offline, and a watch that will never sync again should not look like one
    /// that is merely out of signal.
    var isRetired: Bool {
        get { access(keyPath: \.isRetired); return defaults.bool(forKey: Key.retired) }
        set {
            guard newValue != defaults.bool(forKey: Key.retired) else { return }
            withMutation(keyPath: \.isRetired) { defaults.set(newValue, forKey: Key.retired) }
        }
    }

    /// The session that was live when this process last wrote to the log.
    ///
    /// A running session can be found again in the log — its interval is still
    /// open. A paused one cannot: pausing closes the interval, so a held
    /// session and a session that ended look exactly alike from the rows
    /// alone, and the held one used to be gone the next time the app came up.
    /// This is the one bit of session state that isn't derivable, so it is the
    /// one bit that is stored. In the App Group, because the widget's intents
    /// end and resume sessions too.
    ///
    /// Not tracked by observation: the store owns the live value, and this is
    /// only how it survives the process.
    var activeSessionID: UUID? {
        get { defaults.string(forKey: Key.activeSession).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Key.activeSession) }
    }

    /// A subject picked while paused, waiting for the next interval to open.
    ///
    /// Doubly optional like the store's own copy: the outer `nil` is "nothing
    /// pending", the inner one is a pending choice of free time — which is a
    /// choice, and lost if the two are flattened.
    var pendingSubjectID: UUID?? {
        get {
            guard let raw = defaults.string(forKey: Key.pendingSubject) else { return nil }
            return .some(UUID(uuidString: raw))
        }
        set {
            switch newValue {
            case .none:
                defaults.removeObject(forKey: Key.pendingSubject)
            case .some(let id):
                defaults.set(id?.uuidString ?? Key.noSubject, forKey: Key.pendingSubject)
            }
        }
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

    /// Intervals deleted locally that the server has already been told about,
    /// waiting to be un-told.
    ///
    /// Discarding a session deletes its rows, so there is nothing left to carry
    /// a tombstone — the id has to be kept somewhere else or the interval lives
    /// on the web forever. Only rows that were actually pushed are recorded;
    /// everything else the server never heard of.
    var deletedIntervalIDs: [UUID] {
        get {
            (defaults.array(forKey: Key.deletedIntervals) as? [String] ?? [])
                .compactMap(UUID.init(uuidString:))
        }
        set {
            // Bounded: a list that only ever grows because the server cannot be
            // reached is a defaults key that only ever grows.
            let capped = newValue.suffix(500).map(\.uuidString)
            defaults.set(capped, forKey: Key.deletedIntervals)
        }
    }

    func recordDeleted(intervalIDs ids: [UUID]) {
        guard !ids.isEmpty else { return }
        deletedIntervalIDs = deletedIntervalIDs + ids
    }

    /// The newest `updatedAt` the server has been sent.
    ///
    /// Subjects were pushed in full on every pass — a whole table over a watch
    /// radio for a list that mostly does not change. Last-write-wins makes the
    /// full push correct, not necessary.
    var subjectsPushedAt: Date? {
        get {
            let stored = defaults.double(forKey: Key.subjectsPushedAt)
            return stored > 0 ? Date(timeIntervalSince1970: stored) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.subjectsPushedAt) }
    }

    /// When the subject list was last read back.
    ///
    /// The push above is already gated on having something to say; this gates
    /// the answer. A pass now runs at the end of every session rather than
    /// twice a day, and a pull on each of them is a radio wake for a list that
    /// changes when the user renames something.
    var subjectsPulledAt: Date? {
        get {
            let stored = defaults.double(forKey: Key.subjectsPulledAt)
            return stored > 0 ? Date(timeIntervalSince1970: stored) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.subjectsPulledAt) }
    }

    func clearDeleted(intervalIDs ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let done = Set(ids)
        deletedIntervalIDs = deletedIntervalIDs.filter { !done.contains($0) }
    }
}
