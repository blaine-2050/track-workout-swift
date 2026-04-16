import SwiftUI

/// First-class cardio entry: one tap to start a segment, one tap to stop.
/// Computes durationSeconds from elapsed wall-clock and hands it to the
/// owning view's `onStop` callback for persistence.
///
/// Manual HH:MM:SS entry remains available via the existing IntervalEntry
/// + numeric keypad in the parent view; this view is the *primary*
/// cardio path.
struct CardioEntry: View {
    let isRunning: Bool
    let startDate: Date?
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isRunning, let startDate = startDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = max(0, Int(context.date.timeIntervalSince(startDate)))
                    let hours = elapsed / 3600
                    let minutes = (elapsed % 3600) / 60
                    let seconds = elapsed % 60
                    Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.green)
                        .accessibilityIdentifier("cardio-elapsed")
                }
                Button(action: onStop) {
                    Text("Stop segment")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .accessibilityIdentifier("cardio-stop")
            } else {
                Button(action: onStart) {
                    Text("Start segment")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .accessibilityIdentifier("cardio-start")
            }
        }
    }
}

#Preview("Idle") {
    CardioEntry(isRunning: false, startDate: nil, onStart: {}, onStop: {})
        .padding()
}

#Preview("Running") {
    CardioEntry(isRunning: true, startDate: Date().addingTimeInterval(-125), onStart: {}, onStop: {})
        .padding()
}
