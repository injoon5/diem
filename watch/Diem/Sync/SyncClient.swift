import Foundation

/// The app works fully without ever pairing, so every call here is allowed to
/// fail quietly.
struct SyncClient: Sendable {
    enum Failure: Error {
        case badResponse(Int)
        case notPaired
    }

    var baseURL: URL
    var deviceToken: String
    /// The server buckets sessions into local days and needs to know which.
    var timezone: String
    /// The web shows a goal-hit rate, so it needs a copy of the one setting.
    var goalMinutes: Int

    static let defaultBaseURL = URL(string: "https://diem.ij5.dev")!

    @MainActor
    static func live() -> SyncClient {
        let configured = Bundle.main.object(forInfoDictionaryKey: "DiemAPIBaseURL") as? String
        return SyncClient(
            baseURL: configured.flatMap(URL.init(string:)) ?? defaultBaseURL,
            deviceToken: Settings.shared.deviceToken,
            timezone: TimeZone.current.identifier,
            goalMinutes: Settings.shared.dailyGoalMinutes
        )
    }

    /// Claims a pairing code to show on the watch.
    func pair() async throws -> PairResponse {
        try await send(
            path: "/api/pair",
            method: "POST",
            body: PairRequest(deviceToken: deviceToken),
            as: PairResponse.self
        )
    }

    /// Idempotent on interval id — resending an accepted interval is a no-op.
    func push(intervals: [IntervalDTO]) async throws -> [UUID] {
        try await send(
            path: "/api/intervals",
            method: "POST",
            body: IntervalPush(intervals: intervals),
            as: IntervalPushResponse.self
        ).accepted
    }

    /// Un-tells the server about intervals deleted on the watch.
    ///
    /// Intervals are immutable once ended, so there is no update — but discard
    /// exists, and without this a session thrown away on the watch stayed on
    /// the web for good.
    func delete(intervalIDs ids: [UUID]) async throws {
        _ = try await send(
            path: "/api/intervals",
            method: "DELETE",
            body: IntervalDelete(ids: ids),
            as: IntervalDeleteResponse.self
        )
    }

    func pullSubjects() async throws -> [SubjectDTO] {
        try await send(path: "/api/subjects", method: "GET", body: Optional<Never>.none, as: SubjectPage.self).subjects
    }

    /// Last-write-wins on `updatedAt`.
    func push(subjects: [SubjectDTO]) async throws {
        _ = try await send(
            path: "/api/subjects",
            method: "POST",
            body: SubjectPush(subjects: subjects),
            as: SubjectPage.self
        )
    }

    /// Ten seconds, not the URL session's default minute.
    ///
    /// Every call here is allowed to fail quietly, so the only thing a long
    /// timeout buys is a pairing spinner that sits there for a minute on a
    /// flaky connection.
    private static let timeout: TimeInterval = 10

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?,
        as: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = Self.timeout
        request.setValue(deviceToken, forHTTPHeaderField: "X-Diem-Device")
        request.setValue(timezone, forHTTPHeaderField: "X-Diem-TZ")
        request.setValue(String(goalMinutes), forHTTPHeaderField: "X-Diem-Goal")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.diem.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw status == 401 ? Failure.notPaired : Failure.badResponse(status)
        }
        return try JSONDecoder.diem.decode(Response.self, from: data)
    }
}

/// Push completed intervals, un-push deleted ones, round-trip subjects.
/// Nothing else crosses the wire.
@MainActor
enum SyncEngine {
    static func run(store: SessionStore, client: SyncClient = .live(), settings: Settings = .shared) async {
        // Offline is the normal case and stays silent. Being *refused* is not:
        // it means this watch's token was taken over by a replacement, and it
        // will never sync again. That is worth saying once, in Settings.
        func note(_ error: Error, _ settings: Settings) {
            if case SyncClient.Failure.notPaired = error { settings.isRetired = true }
        }

        let pending = store.unsyncedIntervals()
        if !pending.isEmpty {
            do {
                let accepted = try await client.push(intervals: pending.map(\.dto))
                store.markSynced(accepted)
            } catch {
                note(error, settings)
                return  // Offline is the normal case; try again next launch.
            }
        }

        // Discards, as far as the server is concerned. Kept in defaults because
        // the rows themselves are gone, and cleared only once the server has
        // agreed — an offline discard is retried on the next pass rather than
        // forgotten.
        let deleted = settings.deletedIntervalIDs
        if !deleted.isEmpty {
            do {
                try await client.delete(intervalIDs: deleted)
                settings.clearDeleted(intervalIDs: deleted)
            } catch {
                note(error, settings)
                return
            }
        }

        do {
            // Tombstones included: a deleted subject is exactly what the wire
            // format's `deletedAt` is for, and the visible list filters it out.
            // Only what has actually changed since the server last saw it —
            // this used to be a full table push on every launch.
            let local = store.subjectsForSync()
            let changed = local.filter { $0.updatedAt > (settings.subjectsPushedAt ?? .distantPast) }
            if !changed.isEmpty {
                try await client.push(subjects: changed.map(\.dto))
                settings.subjectsPushedAt = changed.map(\.updatedAt).max()
            }
            store.merge(subjects: try await client.pullSubjects())
            // A pass that got all the way through is proof the server still
            // knows this watch, whatever it thought a moment ago.
            settings.isRetired = false
        } catch {
            note(error, settings)
            return
        }
    }
}
