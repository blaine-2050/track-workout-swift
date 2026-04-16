import SwiftUI

/// Free-text note editor. Bound to a String — caller decides where the
/// text lives (e.g. WorkoutViewModel.pendingNote during entry, or a
/// per-entry binding when editing a logged entry).
struct NoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var note: String
    var title: String = "Note"

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $draft)
                    .padding()
                    .accessibilityIdentifier("note-textfield")
                Text("\(draft.count) / 1000")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("note-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Cap at 1000 chars per spec.
                        note = String(draft.prefix(1000))
                        dismiss()
                    }
                    .accessibilityIdentifier("note-save")
                }
            }
            .onAppear {
                draft = note
            }
        }
    }
}

#Preview {
    NoteSheet(note: .constant("wind in face"))
}
