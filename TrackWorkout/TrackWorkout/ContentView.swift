import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var weightUnit: String = "lbs"
    @State private var showShareSheet = false
    @State private var showRemoteDBAlert = false
    @State private var showCopiedAlert = false
    @State private var showAddMoveAlert = false
    @State private var csvContent: String = ""
    private let exportTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LogEntry.timestamp, ascending: false)],
        animation: .default)
    private var logEntries: FetchedResults<LogEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.name, ascending: true)],
        animation: .default)
    private var moves: FetchedResults<Move>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.startTime, ascending: false)],
        animation: .default)
    private var workouts: FetchedResults<Workout>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Workout Status
                WorkoutStatusBar(
                    isWorkoutInProgress: viewModel.isWorkoutInProgress,
                    onStartWorkout: startWorkout,
                    onStopWorkout: stopWorkout,
                    onCopy: copyCSV,
                    onExport: exportCSV,
                    onRemoteDB: { showRemoteDBAlert = true }
                )

                if !viewModel.syncStatusMessage.isEmpty && viewModel.syncStatusMessage != "Sync queue empty" {
                    Text(viewModel.syncStatusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal)
                        .padding(.bottom, 2)
                }

                // Move Selector
                MoveSelector(moves: Array(moves), selectedMove: $viewModel.selectedMove, onAddMove: { showAddMoveAlert = true })
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedMove) { newValue in
                        // Stamp endedAt on the last entry of the previous move
                        stampEndedAtOnPreviousEntry(now: Date())
                        try? viewContext.save()
                        viewModel.resetForMoveChange()
                        if newValue != nil && !viewModel.isWorkoutInProgress {
                            startWorkout()
                        }
                    }

                Divider()
                    .padding(.vertical, 1)

                // Weight/Reps side by side
                HStack(spacing: 12) {
                    WeightEntry(
                        value: $viewModel.weight,
                        isActive: viewModel.activeField == .weight,
                        isDisabled: viewModel.isIntervalMove
                    ) {
                        viewModel.activeField = .weight
                    }

                    RepsEntry(
                        value: $viewModel.reps,
                        isActive: viewModel.activeField == .reps,
                        isDisabled: viewModel.isIntervalMove
                    ) {
                        viewModel.activeField = .reps
                    }
                }
                .padding(.horizontal)

                // Unit picker + set timer on same line
                HStack {
                    Picker("Unit", selection: $weightUnit) {
                        Text("kg").tag("kg")
                        Text("lbs").tag("lbs")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)

                    Spacer()

                    if let setStart = viewModel.setTimerStart, viewModel.isWorkoutInProgress, !viewModel.isIntervalMove {
                        SetTimerDisplay(startDate: setStart)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // Interval entry (only for interval moves)
                if viewModel.isIntervalMove {
                    IntervalEntry(
                        hours: viewModel.intervalHours,
                        minutes: viewModel.intervalMinutes,
                        seconds: viewModel.intervalSeconds,
                        activeField: viewModel.intervalField,
                        onSelectField: { viewModel.intervalField = $0 }
                    )
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                // Numeric Keypad
                NumericKeypad(
                    onDigit: { digit in
                        viewModel.appendDigit(digit)
                    },
                    onDecimal: {
                        viewModel.appendDecimal()
                    },
                    onBackspace: {
                        viewModel.backspace()
                    },
                    onClear: {
                        viewModel.clear()
                    },
                    showDecimal: !viewModel.isIntervalMove && viewModel.activeField == .weight,
                    showColon: viewModel.isIntervalMove,
                    onColon: {
                        viewModel.advanceIntervalField()
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Log Button
                Button(action: {
                    logEntry()
                }) {
                    Text("Log")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.canLog ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!viewModel.canLog)
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 1)

                // Event History
                EventHistory(entries: Array(logEntries), moves: Array(moves), workouts: Array(workouts))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [csvContent])
            }
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Log data copied to clipboard.")
            }
            .alert("Remote Track-Workout DB", isPresented: $showRemoteDBAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Remote database support is on its way!")
            }
            .alert("Add Move", isPresented: $showAddMoveAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Custom move creation is coming soon.")
            }
            .onAppear {
                viewModel.refreshPendingSyncCount()
            }
        }
    }

    private func copyCSV() {
        UIPasteboard.general.string = buildCSV()
        showCopiedAlert = true
    }

    private func buildCSV() -> String {
        var moveDict: [UUID: Move] = [:]
        for move in moves {
            if let id = move.id {
                moveDict[id] = move
            }
        }

        var lines: [String] = []
        for entry in logEntries.reversed() {
            let moveName = moveDict[entry.moveId ?? UUID()]?.name ?? "Unknown"
            let weight = Int(entry.weight)
            let reps = entry.reps
            let timestamp = exportTimestampFormatter.string(from: entry.timestamp ?? Date())
            lines.append("\(moveName), \(timestamp), \(weight), \(reps)")
        }

        return lines.joined(separator: "\n")
    }

    private func exportCSV() {
        csvContent = buildCSV()
        showShareSheet = true
    }

    private func logEntry() {
        guard let selectedMove = viewModel.selectedMove,
              let currentWorkout = viewModel.currentWorkout else { return }

        withAnimation {
            let now = Date()
            let newEntry = LogEntry(context: viewContext)
            newEntry.id = UUID()
            newEntry.moveId = selectedMove.id ?? UUID()
            newEntry.workoutId = currentWorkout.id
            newEntry.timestamp = now
            newEntry.startedAt = viewModel.moveSelectedAt ?? viewModel.lastLoggedAt ?? now
            // endedAt will be stamped when the next entry is logged or move changes
            if viewModel.isIntervalMove {
                let duration = viewModel.intervalDurationSeconds
                guard duration > 0 else { return }
                newEntry.measurementType = "duration"
                newEntry.durationSeconds = Double(duration)
                newEntry.weight = 0
                newEntry.reps = 0
            } else {
                guard let weight = Double(viewModel.weight),
                      let reps = Int16(viewModel.reps) else { return }
                newEntry.measurementType = "weight"
                newEntry.weight = weight
                newEntry.reps = reps
                newEntry.weightUnit = weightUnit
            }

            // Stamp endedAt on the previous entry if it doesn't have one
            stampEndedAtOnPreviousEntry(now: now)

            do {
                try viewContext.save()
                viewModel.enqueueForSync(
                    logEntry: newEntry,
                    moveName: selectedMove.name ?? "Unknown"
                )
                Task {
                    await viewModel.syncNow()
                }
                viewModel.resetAfterLog()
            } catch {
                let nsError = error as NSError
                print("Error saving log entry: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func stampEndedAtOnPreviousEntry(now: Date) {
        // logEntries is sorted newest-first, so the first entry is the most recent *existing* one
        guard let previousEntry = logEntries.first else { return }
        if previousEntry.endedAt == nil {
            previousEntry.endedAt = now
        }
    }

    private func startWorkout() {
        let workout = Workout(context: viewContext)
        workout.id = UUID()
        workout.startTime = Date()

        do {
            try viewContext.save()
            withAnimation {
                viewModel.currentWorkout = workout
                viewModel.moveSelectedAt = Date()
            }
        } catch {
            let nsError = error as NSError
            print("Error starting workout: \(nsError), \(nsError.userInfo)")
            // Remove the unsaved workout from context
            viewContext.delete(workout)
        }
    }

    private func stopWorkout() {
        guard let workout = viewModel.currentWorkout else { return }

        withAnimation {
            workout.endTime = Date()

            do {
                try viewContext.save()
                viewModel.currentWorkout = nil
                viewModel.selectedMove = nil
            } catch {
                let nsError = error as NSError
                print("Error stopping workout: \(nsError), \(nsError.userInfo)")
            }
        }
    }

}

// MARK: - Set Timer Display
struct SetTimerDisplay: View {
    let startDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startDate)))
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            let seconds = elapsed % 60
            HStack(spacing: 6) {
                Text("Set Timer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

struct IntervalEntry: View {
    let hours: String
    let minutes: String
    let seconds: String
    let activeField: IntervalField
    let onSelectField: (IntervalField) -> Void

    private func formatField(_ value: String) -> String {
        value.isEmpty ? "00" : String(repeating: "0", count: max(0, 2 - value.count)) + value
    }

    var body: some View {
        HStack(spacing: 8) {
            intervalButton(value: hours, label: "HH", isActive: activeField == .hours) {
                onSelectField(.hours)
            }
            Text(":")
                .font(.title3)
                .foregroundColor(.secondary)
            intervalButton(value: minutes, label: "MM", isActive: activeField == .minutes) {
                onSelectField(.minutes)
            }
            Text(":")
                .font(.title3)
                .foregroundColor(.secondary)
            intervalButton(value: seconds, label: "SS", isActive: activeField == .seconds) {
                onSelectField(.seconds)
            }
        }
    }

    private func intervalButton(value: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(formatField(value))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            .frame(minWidth: 64)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue.opacity(0.1) : Color(.systemGray5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
