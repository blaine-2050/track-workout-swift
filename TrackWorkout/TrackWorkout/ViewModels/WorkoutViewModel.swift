import SwiftUI
import CoreData
import TrackWorkoutCore

enum ActiveField {
    case weight
    case reps
}

enum IntervalField {
    case hours
    case minutes
    case seconds
}

private enum SyncConfig {
    static let defaultEndpoint = "http://localhost:3000/sync/events"
    static let endpointDefaultsKey = "sync.endpoint"
    static let tokenDefaultsKey = "authToken"
    static let cursorDefaultsKey = "sync.nextCursor"
}

private enum SyncDateCodec {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        fractional.string(from: date)
    }

    static func parse(_ value: String) -> Date? {
        fractional.date(from: value) ?? standard.date(from: value)
    }
}

private struct SyncEventPayload: Codable {
    let id: String
    let moveId: String
    let move: String
    let measurementType: String
    let weight: Double
    let reps: Int
    let durationSeconds: Int
    let endedAt: String?
    let weightRecordedAt: String?
    let repsRecordedAt: String?
    let intensity: Double?
    let intensityMetric: String?
    let intervalKind: String?
    let intervalLabel: String?
    let startedAt: String
    let updatedAt: String

    init(event: WorkoutEvent) {
        self.id = event.id.uuidString
        self.moveId = (event.moveId ?? event.id).uuidString
        self.move = event.move
        self.measurementType = event.measurementType.rawValue
        self.weight = event.weight ?? 0
        self.reps = event.reps ?? 0
        self.durationSeconds = event.durationSeconds ?? 0
        self.endedAt = event.endedAt.map { SyncDateCodec.string(from: $0) }
        self.weightRecordedAt = event.weightRecordedAt.map { SyncDateCodec.string(from: $0) }
            ?? (event.measurementType == .strength ? SyncDateCodec.string(from: event.updatedAt) : nil)
        self.repsRecordedAt = event.repsRecordedAt.map { SyncDateCodec.string(from: $0) }
            ?? (event.measurementType == .strength ? SyncDateCodec.string(from: event.updatedAt) : nil)
        self.intensity = event.measurementType == .aerobic ? (event.intensity ?? 0) : nil
        self.intensityMetric = event.measurementType == .aerobic ? (event.intensityMetric ?? "estimated_effort") : nil
        self.intervalKind = event.measurementType == .aerobic ? (event.intervalKind?.rawValue ?? "work") : nil
        self.intervalLabel = event.measurementType == .aerobic ? event.intervalLabel : nil
        self.startedAt = SyncDateCodec.string(from: event.startedAt)
        self.updatedAt = SyncDateCodec.string(from: event.updatedAt)
    }
}

private struct SyncRequestPayload: Codable {
    let cursor: String?
    let events: [SyncEventPayload]
}

private struct SyncAcceptedPayload: Codable {
    let id: String
    let action: String
}

private struct SyncConflictPayload: Codable {
    let id: String
    let reason: String
    let serverUpdatedAt: String?
    let clientUpdatedAt: String
}

private struct SyncResponsePayload: Codable {
    let serverTime: String
    let nextCursor: String
    let accepted: [SyncAcceptedPayload]
    let conflicts: [SyncConflictPayload]
}

private struct ApiErrorPayload: Codable {
    let error: String
    let code: String
}

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var selectedMove: Move?
    @Published var weight: String = ""
    @Published var reps: String = ""
    @Published var activeField: ActiveField = .weight
    @Published var currentWorkout: Workout?
    @Published var intervalHours: String = ""
    @Published var intervalMinutes: String = ""
    @Published var intervalSeconds: String = ""
    @Published var intervalField: IntervalField = .hours
    @Published var isSticky: Bool = false
    @Published var moveSelectedAt: Date?
    @Published var lastLoggedAt: Date?
    @Published var pendingSyncCount: Int = 0
    @Published var syncStatusMessage: String = "Sync queue empty"

    private var outbox: LocalOutbox = LocalOutbox()
    private let outboxFileURL: URL

    init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let syncDirectory = appSupportURL.appendingPathComponent("TrackWorkoutSync", isDirectory: true)

        try? FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        self.outboxFileURL = syncDirectory.appendingPathComponent("outbox.json")

        loadOutbox()
        refreshPendingSyncCount()
    }

    var isWorkoutInProgress: Bool {
        currentWorkout != nil
    }

    var workoutDuration: String {
        guard let workout = currentWorkout, let startTime = workout.startTime else {
            return ""
        }
        let interval = Date().timeIntervalSince(startTime)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// The reference date for the set timer: last log time or move selection time
    var setTimerStart: Date? {
        moveSelectedAt
    }

    var canLog: Bool {
        if isIntervalMove {
            return currentWorkout != nil &&
            selectedMove != nil &&
            intervalDurationSeconds > 0
        }
        return currentWorkout != nil &&
        selectedMove != nil &&
        !weight.isEmpty &&
        Double(weight) != nil &&
        Double(weight)! > 0 &&
        !reps.isEmpty &&
        Int(reps) != nil &&
        Int(reps)! > 0
    }

    var isIntervalMove: Bool {
        guard let name = selectedMove?.name else { return false }
        return ["MTB", "Elipitical", "Treadmill"].contains(name)
    }

    var intervalDurationSeconds: Int {
        let hours = Int(intervalHours) ?? 0
        let minutes = Int(intervalMinutes) ?? 0
        let seconds = Int(intervalSeconds) ?? 0
        return hours * 3600 + minutes * 60 + seconds
    }

    func appendDigit(_ digit: String) {
        if isIntervalMove {
            appendIntervalDigit(digit)
            return
        }
        if isSticky {
            switch activeField {
            case .weight: weight = ""
            case .reps: reps = ""
            }
            isSticky = false
        }
        switch activeField {
        case .weight:
            if weight.count < 6 {
                weight += digit
            }
        case .reps:
            if reps.count < 3 {
                reps += digit
            }
        }
    }

    func appendDecimal() {
        if isIntervalMove { return }
        guard activeField == .weight else { return }
        if isSticky {
            weight = "0."
            isSticky = false
            return
        }
        guard !weight.contains(".") else { return }
        if weight.isEmpty {
            weight = "0."
        } else {
            weight += "."
        }
    }

    func backspace() {
        if isIntervalMove {
            backspaceInterval()
            return
        }
        if isSticky {
            switch activeField {
            case .weight: weight = ""
            case .reps: reps = ""
            }
            isSticky = false
            return
        }
        switch activeField {
        case .weight:
            if !weight.isEmpty {
                weight.removeLast()
            }
        case .reps:
            if !reps.isEmpty {
                reps.removeLast()
            }
        }
    }

    func clear() {
        if isIntervalMove {
            clearIntervalField()
            return
        }
        isSticky = false
        switch activeField {
        case .weight:
            weight = ""
        case .reps:
            reps = ""
        }
    }

    func resetAfterLog() {
        // Keep weight and reps visible (sticky) — both replaced on first keypress
        isSticky = true
        activeField = .weight
        intervalHours = ""
        intervalMinutes = ""
        intervalSeconds = ""
        intervalField = .hours
        lastLoggedAt = Date()
        moveSelectedAt = Date()
    }

    func resetForMoveChange() {
        weight = ""
        reps = ""
        isSticky = false
        activeField = .weight
        intervalHours = ""
        intervalMinutes = ""
        intervalSeconds = ""
        intervalField = .hours
        moveSelectedAt = Date()
    }

    func advanceIntervalField() {
        switch intervalField {
        case .hours:
            intervalField = .minutes
        case .minutes:
            intervalField = .seconds
        case .seconds:
            intervalField = .seconds
        }
    }

    func enqueueForSync(logEntry: LogEntry, moveName: String) {
        guard let entryId = logEntry.id,
              let moveId = logEntry.moveId,
              let startedAt = logEntry.startedAt ?? logEntry.timestamp else {
            syncStatusMessage = "Sync skipped: missing event identifiers"
            return
        }

        let measurementType: MeasurementType = (logEntry.measurementType ?? "weight") == "duration" ? .aerobic : .strength

        let event = WorkoutEvent(
            id: entryId,
            move: moveName,
            moveId: moveId,
            startedAt: startedAt,
            measurementType: measurementType,
            weight: measurementType == .strength ? logEntry.weight : nil,
            reps: measurementType == .strength ? Int(logEntry.reps) : nil,
            durationSeconds: measurementType == .aerobic ? Int(logEntry.durationSeconds) : nil,
            updatedAt: Date()
        )

        outbox.enqueue(event)
        persistOutbox()
        refreshPendingSyncCount()
        syncStatusMessage = "Queued \(pendingSyncCount) event(s)"
    }

    func refreshPendingSyncCount() {
        pendingSyncCount = outbox.items.count
        if pendingSyncCount == 0 && syncStatusMessage.hasPrefix("Queued") {
            syncStatusMessage = "Sync queue empty"
        }
    }

    func syncNow() async {
        guard !outbox.items.isEmpty else {
            syncStatusMessage = "Sync queue empty"
            return
        }

        guard let endpointURL = syncEndpointURL() else {
            syncStatusMessage = "Sync endpoint is invalid"
            return
        }

        syncStatusMessage = "Syncing \(outbox.items.count) event(s)..."

        let payload = SyncRequestPayload(
            cursor: UserDefaults.standard.string(forKey: SyncConfig.cursorDefaultsKey),
            events: outbox.items.map { SyncEventPayload(event: $0.event) }
        )

        do {
            let encoded = try JSONEncoder().encode(payload)
            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.httpBody = encoded
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = UserDefaults.standard.string(forKey: SyncConfig.tokenDefaultsKey), !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                syncStatusMessage = "Sync failed: no HTTP response"
                return
            }

            if httpResponse.statusCode == 401 {
                syncStatusMessage = "Sync failed: auth required (set authToken in UserDefaults)"
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let apiError = try? JSONDecoder().decode(ApiErrorPayload.self, from: data) {
                    syncStatusMessage = "Sync failed: \(apiError.code)"
                } else {
                    syncStatusMessage = "Sync failed: HTTP \(httpResponse.statusCode)"
                }
                return
            }

            let syncResponse = try JSONDecoder().decode(SyncResponsePayload.self, from: data)
            let acceptedIds = Set(syncResponse.accepted.compactMap { UUID(uuidString: $0.id) })
            let conflictIds = Set(syncResponse.conflicts.compactMap { UUID(uuidString: $0.id) })
            let toClear = acceptedIds.union(conflictIds)
            outbox.clearProcessed(ids: toClear)
            persistOutbox()

            UserDefaults.standard.set(syncResponse.nextCursor, forKey: SyncConfig.cursorDefaultsKey)
            refreshPendingSyncCount()

            if syncResponse.conflicts.isEmpty {
                syncStatusMessage = "Sync complete (\(acceptedIds.count) accepted)"
            } else {
                syncStatusMessage = "Sync complete (\(acceptedIds.count) accepted, \(syncResponse.conflicts.count) conflicts)"
            }
        } catch {
            syncStatusMessage = "Sync failed: \(error.localizedDescription)"
        }
    }

    private func syncEndpointURL() -> URL? {
        let custom = UserDefaults.standard.string(forKey: SyncConfig.endpointDefaultsKey)
        let raw = (custom?.isEmpty == false) ? custom! : SyncConfig.defaultEndpoint
        return URL(string: raw)
    }

    private func loadOutbox() {
        guard let data = try? Data(contentsOf: outboxFileURL) else {
            outbox = LocalOutbox()
            return
        }

        do {
            outbox = try JSONDecoder().decode(LocalOutbox.self, from: data)
        } catch {
            outbox = LocalOutbox()
        }
    }

    private func persistOutbox() {
        do {
            let data = try JSONEncoder().encode(outbox)
            try data.write(to: outboxFileURL, options: .atomic)
        } catch {
            syncStatusMessage = "Failed to persist sync queue"
        }
    }

    private func appendIntervalDigit(_ digit: String) {
        switch intervalField {
        case .hours:
            if intervalHours.count < 2 {
                intervalHours += digit
                if intervalHours.count >= 2 {
                    intervalField = .minutes
                }
            }
        case .minutes:
            if intervalMinutes.count < 2 {
                intervalMinutes += digit
                if intervalMinutes.count >= 2 {
                    intervalField = .seconds
                }
            }
        case .seconds:
            if intervalSeconds.count < 2 {
                intervalSeconds += digit
            }
        }
    }

    private func backspaceInterval() {
        switch intervalField {
        case .hours:
            if !intervalHours.isEmpty { intervalHours.removeLast() }
        case .minutes:
            if !intervalMinutes.isEmpty { intervalMinutes.removeLast() }
        case .seconds:
            if !intervalSeconds.isEmpty { intervalSeconds.removeLast() }
        }
    }

    private func clearIntervalField() {
        switch intervalField {
        case .hours:
            intervalHours = ""
        case .minutes:
            intervalMinutes = ""
        case .seconds:
            intervalSeconds = ""
        }
    }
}
