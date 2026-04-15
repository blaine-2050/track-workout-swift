import SwiftUI

struct WorkoutStatusBar: View {
    let isWorkoutInProgress: Bool
    let onStartWorkout: () -> Void
    let onStopWorkout: () -> Void
    let onCopy: () -> Void
    let onExport: () -> Void
    let onRemoteDB: () -> Void

    var body: some View {
        HStack {
            Text("Track Workout")
                .font(.headline)

            Spacer()

            HStack(spacing: 12) {
                if isWorkoutInProgress {
                    statusBarButton("Stop", action: onStopWorkout)
                } else {
                    statusBarButton("Start", action: onStartWorkout)
                }

                exportMenu
            }
        }
        .padding(.horizontal)
        .padding(.top, 3)
        .padding(.bottom, 2)
    }

    private var exportMenu: some View {
        Menu {
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button(action: onExport) {
                Label("Save to File", systemImage: "folder")
            }
            Button(action: onExport) {
                Label("iCloud", systemImage: "icloud.and.arrow.up")
            }
            Button(action: onExport) {
                Label("Reminders", systemImage: "checklist")
            }
            Button(action: onRemoteDB) {
                Label("Remote Track-Workout DB", systemImage: "globe")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private func statusBarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
        }
    }
}

#Preview("In Progress") {
    WorkoutStatusBar(
        isWorkoutInProgress: true,
        onStartWorkout: {},
        onStopWorkout: {},
        onCopy: {},
        onExport: {},
        onRemoteDB: {}
    )
}

#Preview("Not In Progress") {
    WorkoutStatusBar(
        isWorkoutInProgress: false,
        onStartWorkout: {},
        onStopWorkout: {},
        onCopy: {},
        onExport: {},
        onRemoteDB: {}
    )
}
