import SwiftUI

/// The watch shows a code; you enter it once on the web to claim the device.
struct PairingView: View {
    @State private var code: String?
    @State private var failed = false
    @State private var loading = true

    var body: some View {
        VStack(spacing: 8) {
            if let code {
                Text(code)
                    .numeralStyle(size: 32, tracking: 2, weight: .medium)
                    .textCase(.uppercase)
                    // Spelled out, character by character. A four-character
                    // code read as a word is a code you have to ask for twice.
                    .accessibilityLabel(code.map(String.init).joined(separator: " "))
                Text("Enter this on diem.app")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if loading {
                ProgressView()
            } else if failed {
                Text("Couldn't reach the server.")
                    .font(Typography.text(.footnote))
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await load() } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Pair")
        .task { await load() }
    }

    private func load() async {
        loading = true
        failed = false
        do {
            code = try await SyncClient.live().pair().code
        } catch {
            failed = true
        }
        loading = false
    }
}
