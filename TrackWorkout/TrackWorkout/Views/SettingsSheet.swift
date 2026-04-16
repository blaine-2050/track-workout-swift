import SwiftUI

enum SettingsKey {
    static let syncEnabled = "sync.enabled"
    static let syncEndpoint = "sync.endpoint"
    static let authToken = "authToken"
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.syncEnabled) private var syncEnabled: Bool = false
    @AppStorage(SettingsKey.syncEndpoint) private var endpoint: String = ""
    @AppStorage(SettingsKey.authToken) private var authToken: String = ""

    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sync to remote server", isOn: $syncEnabled)
                        .accessibilityIdentifier("settings-sync-toggle")
                } footer: {
                    Text("When off, workouts are saved locally only. The app works fully offline.")
                }

                if syncEnabled {
                    Section("Endpoint") {
                        TextField("https://your-server.example.com/sync/events", text: $endpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                            .accessibilityIdentifier("settings-endpoint-field")
                    }

                    Section("API key") {
                        SecureField("API key", text: $authToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .accessibilityIdentifier("settings-apikey-field")
                    }

                    Section {
                        Button(action: testConnection) {
                            HStack {
                                Text(testing ? "Testing…" : "Test connection")
                                Spacer()
                                if let result = testResult {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(result.hasPrefix("OK") ? .green : .red)
                                }
                            }
                        }
                        .disabled(testing || endpoint.isEmpty)
                        .accessibilityIdentifier("settings-test-button")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings-done")
                }
            }
        }
    }

    private func testConnection() {
        guard let url = healthURL(from: endpoint) else {
            testResult = "Invalid URL"
            return
        }
        testing = true
        testResult = nil
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse else {
                    await MainActor.run {
                        testResult = "No response"
                        testing = false
                    }
                    return
                }
                if (200...299).contains(http.statusCode) {
                    let bodyPreview = String(data: data, encoding: .utf8)?.prefix(40) ?? ""
                    await MainActor.run {
                        testResult = "OK \(http.statusCode) \(bodyPreview)"
                        testing = false
                    }
                } else {
                    await MainActor.run {
                        testResult = "HTTP \(http.statusCode)"
                        testing = false
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    testing = false
                }
            }
        }
    }

    /// Replace `/sync/events` with `/health` for the connectivity probe.
    private func healthURL(from endpoint: String) -> URL? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        let healthString = trimmed.replacingOccurrences(of: "/sync/events", with: "/health")
        return URL(string: healthString) ?? url
    }
}

#Preview {
    SettingsSheet()
}
