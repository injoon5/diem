import SwiftUI

/// The watch shows a code; you enter it once on the web to claim the device.
struct PairingView: View {
    @State private var code: String?
    @State private var expiresAt: Date?
    @State private var failed = false
    @State private var loading = true
    /// A fixed anchor, so the countdown doesn't re-phase on every redraw.
    @State private var anchor = Date.now

    var body: some View {
        TimelineView(.periodic(from: anchor, by: 1)) { context in
            content(now: context.date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Pair")
        .task { await load() }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        VStack(spacing: 8) {
            if let code, !hasExpired(asOf: now) {
                Text(code)
                    .numeralStyle(size: 32, tracking: 2, weight: .medium)
                    // Spelled out, character by character. A four-character
                    // code read as a word is a code you have to ask for twice.
                    // Spelled from the string that is actually drawn, too — it
                    // used to be spelled from the raw one while the screen
                    // uppercased it, so a lowercase code was announced in a
                    // different case from the one being transcribed.
                    .accessibilityLabel(code.map(String.init).joined(separator: " "))
                Text("Enter this on diem.ij5.dev")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                // The server sends an expiry and the screen used to throw it
                // away, so a code that had lapsed looked exactly like a fresh
                // one. Shown only once it is close enough to matter.
                if let remaining = remaining(asOf: now), remaining <= Self.warnWithin {
                    Text("Expires in \(Format.duration(remaining.rounded(.up)))")
                        .font(Typography.text(.caption2))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            } else if loading {
                ProgressView()
            } else if code != nil {
                // Expired rather than never fetched: say which, and offer the
                // one thing that helps.
                Text("That code has expired.")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("New Code") { Task { await load() } }
            } else if failed {
                Text("Couldn't reach the server.")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await load() } }
            }
        }
    }

    /// Close enough that a code might lapse while it is being typed.
    private static let warnWithin: TimeInterval = 5 * 60

    private func remaining(asOf now: Date) -> TimeInterval? {
        expiresAt.map { $0.timeIntervalSince(now) }
    }

    private func hasExpired(asOf now: Date) -> Bool {
        guard let remaining = remaining(asOf: now) else { return false }
        return remaining <= 0
    }

    private func load() async {
        loading = true
        failed = false
        code = nil
        expiresAt = nil
        do {
            // Uppercased once, here, so the screen and the spoken label cannot
            // disagree about a value being copied by hand into another device.
            let response = try await SyncClient.live().pair()
            code = response.code.uppercased()
            expiresAt = response.expiresAt
            // Pairing creates a device row for this token, so whatever the
            // server thought of it before, it knows it now.
            Settings.shared.isRetired = false
        } catch {
            failed = true
        }
        loading = false
    }
}
