import AppIntents
import Foundation
import SwiftData
import WatchKit

/// Subjects, as Siri and Shortcuts see them.
struct SubjectEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Subject")
    static let defaultQuery = SubjectQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct SubjectQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [SubjectEntity] {
        let wanted = Set(identifiers)
        return DiemContainer.store.subjects()
            .filter { wanted.contains($0.id) }
            .map { SubjectEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SubjectEntity] {
        DiemContainer.store.subjects().map { SubjectEntity(id: $0.id, name: $0.name) }
    }
}

/// Built before any surface that depends on it — Siri, Shortcuts, the Control on
/// the Action Button and the widget buttons all run these.
struct StartSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Studying"
    static let description = IntentDescription("Start a study session, timed or open-ended.")
    static let openAppWhenRun = false

    @Parameter(title: "Subject")
    var subject: SubjectEntity?

    @Parameter(title: "Duration", defaultUnit: .minutes)
    var duration: Measurement<UnitDuration>?

    static var parameterSummary: some ParameterSummary {
        Summary("Study \(\.$subject) for \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DiemContainer.store
        // Whichever process this is may have been holding a view of the log
        // from before the last change — the app's and the extension's stores
        // only ever drop their own caches.
        store.refresh()
        let seconds = duration.map { Int($0.converted(to: .seconds).value) }

        // Starting closes whatever was running, which is right — the user asked
        // for a new session, not a summary. But from a surface with no screen
        // that used to happen in total silence: a press of the Action Button
        // could end two hours of study and answer "Studying." The session that
        // was ended is named before the one that replaced it.
        let ended = store.activeSession.flatMap { previous in
            previous.studiedSec >= 60 ? previous : nil
        }
        store.start(subjectID: subject?.id, plannedSec: seconds.flatMap { $0 > 0 ? $0 : nil })
        Haptics.start()

        let name = subject?.name
        let started: IntentDialog = switch (name, seconds) {
        case let (name?, seconds?): "Studying \(name) for \(Format.duration(Double(seconds)))."
        case let (name?, nil): "Studying \(name)."
        case let (nil, seconds?): "Studying for \(Format.duration(Double(seconds)))."
        default: "Studying."
        }
        guard let ended else { return .result(dialog: started) }
        let previousName = store.subject(ended.lastSubjectID)?.name ?? "the last session"
        return .result(
            dialog: "Ended \(previousName) at \(Format.duration(ended.studiedSec)). \(started)"
        )
    }
}

struct PauseSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Studying"
    static let description = IntentDescription("Pause or resume the current session.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DiemContainer.store
        store.refresh()
        guard store.activeSessionID != nil else { return .result(dialog: "Nothing is running.") }
        if store.isPaused {
            store.resume()
            return .result(dialog: "Resumed.")
        }
        store.pause()
        return .result(dialog: "Paused.")
    }
}

struct EndSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "End Studying"
    static let description = IntentDescription("End the current session.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = DiemContainer.store
        // The card's layout reads the snapshot and is always fresh; this reads
        // the store, which may not be. Ending from the card used to be able to
        // answer "Nothing is running." for a session that plainly was.
        store.refresh()
        guard store.activeSessionID != nil else { return .result(dialog: "Nothing is running.") }
        // Ending from Siri or a widget must not leave a Done screen queued for
        // whenever the app is next opened. Ending from the Smart Stack card
        // with the app already on screen behind it is a different thing: that
        // ends the session the user is looking at, and it should land on the
        // summary like any other end.
        let landsOnSummary = Self.appIsOnScreen
        guard let session = store.end(presentingDone: landsOnSummary) else {
            Haptics.sessionAbandoned()
            return .result(dialog: "Too short to keep.")
        }
        // The summary fires its own haptic on appearance, and it fires the
        // *right* one — success for a session that ran to term, the softer stop
        // for one ended early. This used to fire success unconditionally on top
        // of it, so ending a four-minute session from the card with the app
        // behind it felt like "you finished" followed by "you stopped".
        if !landsOnSummary {
            if session.isComplete { Haptics.sessionComplete() } else { Haptics.stop() }
        }
        return .result(dialog: "\(Format.duration(session.studiedSec)) studied.")
    }

    /// Whether this is the app with a screen to land on — not the widget
    /// extension, which runs the same intent in its own process and has none.
    ///
    /// `.inactive` counts. The app now holds an extended runtime session for as
    /// long as a session runs, so it can be the frontmost app with the wrist
    /// down — where the state is not `.active` but the summary is still exactly
    /// what the next wrist raise should land on. Only `.background` means there
    /// is nothing there.
    @MainActor
    private static var appIsOnScreen: Bool {
        guard Bundle.main.bundleURL.pathExtension != "appex" else { return false }
        return WKApplication.shared().applicationState != .background
    }
}

struct DiemShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start studying in \(.applicationName)",
                "Study with \(.applicationName)",
            ],
            shortTitle: "Start Studying",
            systemImageName: "book"
        )
        AppShortcut(
            intent: EndSessionIntent(),
            phrases: ["Stop studying in \(.applicationName)"],
            shortTitle: "End Studying",
            systemImageName: "stop.fill"
        )
    }
}
