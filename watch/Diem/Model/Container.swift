import Foundation
import SwiftData

/// One container, shared by the app and by intents running out of process.
enum DiemContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Interval.self, Subject.self])
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(SnapshotStore.appGroup)
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // A store that can't open is unrecoverable; an in-memory fallback at
            // least keeps the session in front of the user instead of crashing.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }()

    @MainActor
    static let store = SessionStore(context: ModelContext(shared))
}
