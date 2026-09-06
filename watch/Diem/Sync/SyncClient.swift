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
    /// How stale the subject list is allowed to get before a pass goes and
    /// asks for it.
    ///
    /// The pull used to run on every pass, which was fine when a pass meant
    /// launch and backgrounding. Now that a pass also means the end of a
    /// session, a discard, and a retry, ending a session and then dropping the
    /// wrist was two full round trips seconds apart — and on a watch the radio
    /// wake is the whole cost, not the handful of rows it carries back. A push
    /// still pulls straight after, because that is how the merge sees what the
    /// server made of it.
    static let subjectPullInterval: TimeInterval = 30 * 60

    /// A bound on one pass, so a server that keeps refusing rows cannot turn a
    /// sync into an unbounded loop. Two hundred intervals to a batch, which is
    /// years of studying before a backlog could reach the end of it.
    static let maxBatchesPerPass = 25

    /// Returns whether the whole pass got through. Nothing here reads the
    /// answer to decide what to show — `SyncScheduler` reads it to decide
    /// whether to come back.
    @discardableResult
    static func run(
        store: SessionStore,
        client: SyncClient = .live(),
        settings: Settings = .shared,
        now: Date = .now
    ) async -> Bool {
        // Offline is the normal case and stays silent. Being *refused* is not:
        // it means this watch's token was taken over by a replacement, and it
        // will never sync again. That is worth saying once, in Settings.
        func note(_ error: Error, _ settings: Settings) {
            if case SyncClient.Failure.notPaired = error { settings.isRetired = true }
        }

        // Whether anything actually crossed the wire. A pass with nothing to
        // send and a fresh enough subject list does no work at all, and a pass
        // that did no work is not evidence of anything — least of all that the
        // server still knows this watch.
        var reached = false

        // A batch at a time until the backlog is gone. One batch used to be the
        // whole pass, so a watch that had been offline for a fortnight reported
        // a clean sync with two hundred intervals sent and the rest still
        // waiting on somebody to trigger another pass.
        var lastBatch: [UUID] = []
        for _ in 0..<maxBatchesPerPass {
            let pending = store.unsyncedIntervals()
            guard !pending.isEmpty else { break }
            let ids = pending.map(\.id)
            // The same rows twice running means the marks are not sticking —
            // a store that has stopped accepting writes. Sending them again is
            // no more likely to work the third time.
            guard ids != lastBatch else { break }
            lastBatch = ids
            // Discarding a session while its push is in flight has to leave a
            // tombstone behind, and only the store knows which rows are up in
            // the air.
            store.beginUpload(ids)
            defer { store.endUpload(ids) }
            do {
                let accepted = try await client.push(intervals: pending.map(\.dto))
                store.markSynced(accepted)
                reached = true
                // Something in the batch was refused. The next round would
                // offer it again and hear the same answer, so leave the rest
                // for a later pass rather than spinning on it here.
                guard accepted.count == pending.count else { break }
            } catch {
                note(error, settings)
                return false  // Offline is the normal case, and retried.
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
                reached = true
            } catch {
                note(error, settings)
                return false
            }
        }

        do {
            // Tombstones included: a deleted subject is exactly what the wire
            // format's `deletedAt` is for, and the visible list filters it out.
            // Only what has actually changed since the server last saw it —
            // this used to be a full table push on every launch.
            let local = store.subjectsForSync()
            let changed = local.filter { $0.updatedAt > (settings.subjectsPushedAt ?? .distantPast) }
            // Both the payload and the watermark are taken from the same values
            // before the request goes out. They used to be read either side of
            // it, off model objects that a rename during the round trip could
            // move underneath — which marked the edit pushed without ever
            // having sent it, and no later pass would look at it again.
            let payload = changed.map(\.dto)
            let watermark = payload.map(\.updatedAt).max()
            if !payload.isEmpty {
                try await client.push(subjects: payload)
                settings.subjectsPushedAt = watermark
                reached = true
            }
            let stale = now.timeIntervalSince(settings.subjectsPulledAt ?? .distantPast)
                >= subjectPullInterval
            if !changed.isEmpty || stale {
                store.merge(subjects: try await client.pullSubjects())
                settings.subjectsPulledAt = now
                reached = true
            }
            // A pass that got all the way through is proof the server still
            // knows this watch, whatever it thought a moment ago — but only if
            // it actually asked it something.
            if reached { settings.isRetired = false }
        } catch {
            note(error, settings)
            return false
        }
        return true
    }
}
