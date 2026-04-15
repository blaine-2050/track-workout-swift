import SwiftUI

// MARK: - Grouping Models

private struct WorkoutGroup: Identifiable {
    let id: UUID
    let startTime: Date?
    let endTime: Date?
    let sets: [WorkoutSet]
}

private struct WorkoutSet: Identifiable {
    let id: String // composite key
    let moveName: String
    let setNumber: Int // 1-based
    let startTime: Date?
    let entries: [LogEntry]
}

// MARK: - Grouping Logic

private func groupByWorkout(entries: [LogEntry], moves: [Move], workouts: [Workout] = []) -> [WorkoutGroup] {
    // Build workout lookup by id
    let workoutDict = Dictionary(uniqueKeysWithValues: workouts.compactMap { w in
        guard let id = w.id else { return nil as (UUID, Workout)? }
        return (id, w)
    }.compactMap { $0 })

    let moveDict = Dictionary(uniqueKeysWithValues: moves.compactMap { move in
        guard let id = move.id else { return nil as (UUID, Move)? }
        return (id, move)
    }.compactMap { $0 })

    // Group entries by workoutId
    var workoutBuckets: [UUID: [LogEntry]] = [:]
    var workoutOrder: [UUID] = []
    // Entries without workoutId go into a fallback bucket
    let fallbackId = UUID()

    for entry in entries {
        let wid = entry.workoutId ?? fallbackId
        if workoutBuckets[wid] == nil {
            workoutOrder.append(wid)
            workoutBuckets[wid] = []
        }
        workoutBuckets[wid]!.append(entry)
    }

    // Sort workouts: most recent first (by earliest entry timestamp)
    let sortedWorkoutIds = workoutOrder.sorted { a, b in
        let aTime = workoutBuckets[a]?.compactMap({ $0.timestamp }).min() ?? Date.distantPast
        let bTime = workoutBuckets[b]?.compactMap({ $0.timestamp }).min() ?? Date.distantPast
        return aTime > bTime
    }

    return sortedWorkoutIds.map { wid in
        let rawEntries = workoutBuckets[wid]!
        // Sort entries within workout: oldest first (for grouping consecutive sets)
        let sorted = rawEntries.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        let sets = groupIntoSets(entries: sorted, moveDict: moveDict)
        let startTime = sorted.first?.timestamp
        let endTime = workoutDict[wid]?.endTime
        return WorkoutGroup(id: wid, startTime: startTime, endTime: endTime, sets: sets.reversed())
    }
}

private func groupIntoSets(entries: [LogEntry], moveDict: [UUID: Move]) -> [WorkoutSet] {
    guard !entries.isEmpty else { return [] }

    var sets: [WorkoutSet] = []
    var currentMoveId: UUID? = nil
    var currentEntries: [LogEntry] = []
    var setIndex = 0

    for entry in entries {
        let moveId = entry.moveId
        if moveId != currentMoveId {
            if !currentEntries.isEmpty {
                let moveName = moveDict[currentMoveId ?? UUID()]?.name ?? "Unknown"
                let setStart = currentEntries.first?.startedAt ?? currentEntries.first?.timestamp
                sets.append(WorkoutSet(
                    id: "\(currentMoveId?.uuidString ?? "nil")-\(setIndex)",
                    moveName: moveName,
                    setNumber: setIndex + 1,
                    startTime: setStart,
                    entries: currentEntries
                ))
                setIndex += 1
            }
            currentMoveId = moveId
            currentEntries = [entry]
        } else {
            currentEntries.append(entry)
        }
    }

    // Flush last group
    if !currentEntries.isEmpty {
        let moveName = moveDict[currentMoveId ?? UUID()]?.name ?? "Unknown"
        let setStart = currentEntries.first?.startedAt ?? currentEntries.first?.timestamp
        sets.append(WorkoutSet(
            id: "\(currentMoveId?.uuidString ?? "nil")-\(setIndex)",
            moveName: moveName,
            setNumber: setIndex + 1,
            startTime: setStart,
            entries: currentEntries
        ))
    }

    return sets
}

// MARK: - Time Formatting

private func formatTime(_ date: Date?) -> String {
    guard let date = date else { return "—" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

private func formatElapsed(start: Date?, end: Date?) -> String {
    guard let start = start, let end = end else { return "—" }
    let interval = end.timeIntervalSince(start)
    guard interval >= 0 else { return "—" }
    let totalSeconds = Int(interval)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds)) hours"
    } else if minutes > 0 {
        return "\(minutes):\(String(format: "%02d", seconds)) min"
    } else {
        return "\(seconds) sec"
    }
}

// MARK: - Views

struct EventHistory: View {
    let entries: [LogEntry]
    let moves: [Move]
    var workouts: [Workout] = []

    private var workoutGroups: [WorkoutGroup] {
        groupByWorkout(entries: entries, moves: moves, workouts: workouts)
    }

    var body: some View {
        if entries.isEmpty {
            Text("No entries yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(workoutGroups) { group in
                        WorkoutGroupView(group: group)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct WorkoutGroupView: View {
    let group: WorkoutGroup

    private var isInProgress: Bool {
        group.startTime != nil && group.endTime == nil
    }

    private var workoutDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Workout header
            if let startTime = group.startTime {
                Text("Workout started on \(workoutDateFormatter.string(from: startTime))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                // Live elapsed timer for in-progress workouts
                if isInProgress {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = max(0, Int(context.date.timeIntervalSince(startTime)))
                        let minutes = elapsed / 60
                        let seconds = elapsed % 60
                        Text("Elapsed: \(String(format: "%d:%02d", minutes, seconds))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }
                }
            }

            ForEach(group.sets) { workoutSet in
                WorkoutSetView(workoutSet: workoutSet)
            }

            // Workout summary (shown when workout has ended)
            if let endTime = group.endTime {
                WorkoutSummaryView(
                    startTime: group.startTime,
                    endTime: endTime,
                    sets: group.sets
                )
            }
        }
    }
}

private struct WorkoutSummaryView: View {
    let startTime: Date?
    let endTime: Date
    let sets: [WorkoutSet]

    private var totalSets: Int { sets.count }

    private var totalEntries: Int {
        sets.reduce(0) { $0 + $1.entries.count }
    }

    private var totalWeightMoved: Double {
        sets.flatMap(\.entries).reduce(0.0) { sum, entry in
            guard entry.durationSeconds == 0 else { return sum }
            return sum + entry.weight * Double(entry.reps)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
            Text("Workout ended at \(formatTime(endTime))")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            HStack(spacing: 16) {
                if let startTime = startTime {
                    Text("Duration: \(formatElapsed(start: startTime, end: endTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("Sets: \(totalSets)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if totalWeightMoved > 0 {
                    Text("Total: \(totalWeightMoved, specifier: "%.0f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct WorkoutSetView: View {
    let workoutSet: WorkoutSet

    private var setElapsed: String? {
        guard let firstStart = workoutSet.entries.first?.startedAt ?? workoutSet.entries.first?.timestamp else { return nil }
        let lastEnd = workoutSet.entries.last?.endedAt ?? Date()
        return formatElapsed(start: firstStart, end: lastEnd)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Set header
            HStack {
                Text("Set \(workoutSet.setNumber) — \(workoutSet.moveName) at \(formatTime(workoutSet.startTime))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let elapsed = setElapsed {
                    Text(elapsed)
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 2)

            // Entry rows (newest first within set for display)
            ForEach(workoutSet.entries.reversed(), id: \.id) { entry in
                EntryRow(entry: entry)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct EntryRow: View {
    let entry: LogEntry

    private var totalWeight: Double {
        entry.weight * Double(entry.reps)
    }

    private var unitLabel: String {
        entry.weightUnit ?? "lbs"
    }

    var body: some View {
        HStack {
            if entry.durationSeconds > 0 {
                Text("Duration \(formattedDuration)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } else {
                HStack(spacing: 12) {
                    Text("\(entry.weight, specifier: "%.0f") \(unitLabel)")
                        .font(.subheadline)
                        .frame(minWidth: 56, alignment: .trailing)
                    Text("×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(entry.reps)")
                        .font(.subheadline)
                        .frame(width: 24, alignment: .trailing)
                    Text("=")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalWeight, specifier: "%.0f") \(unitLabel)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(minWidth: 64, alignment: .trailing)
                }
            }
            Spacer()
            Text(formatElapsed(start: entry.startedAt ?? entry.timestamp, end: entry.endedAt ?? Date()))
                .font(.subheadline)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .background(Color(.systemBackground))
    }

    private var formattedDuration: String {
        let total = Int(entry.durationSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", secs)) hours"
        } else if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", secs)) min"
        } else {
            return "\(secs) sec"
        }
    }
}

#Preview {
    EventHistory(entries: [], moves: [])
}
