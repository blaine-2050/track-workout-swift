import SwiftUI
import CoreData

/// Type categories surfaced in the Add Move sheet.
/// Maps to LogEntry/Move measurementType values.
enum AddMoveCategory: String, CaseIterable, Identifiable {
    case strength
    case cardio    // stored as "duration"
    case other     // stored as "note_only"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strength: return "Strength"
        case .cardio:   return "Cardio"
        case .other:    return "Other"
        }
    }

    var measurementTypeValue: String {
        switch self {
        case .strength: return "strength"
        case .cardio:   return "duration"
        case .other:    return "note_only"
        }
    }

    var hint: String {
        switch self {
        case .strength: return "Weight + reps (e.g. Bench Press, Yoga Mat Lift)"
        case .cardio:   return "Duration (e.g. Bike commute, Treadmill, Stairs)"
        case .other:    return "Just a note (e.g. Stretching, Yoga, Foam roll)"
        }
    }
}

struct AddMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let existingMoves: [Move]
    /// Called with the newly-created Move so the caller can auto-select it.
    let onCreated: (Move) -> Void

    @State private var name: String = ""
    @State private var category: AddMoveCategory = .strength
    @State private var error: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        return !existingMoves.contains { ($0.name ?? "").caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Bike commute", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .accessibilityIdentifier("add-move-name")
                }

                Section {
                    Picker("Type", selection: $category) {
                        ForEach(AddMoveCategory.allCases) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-move-category")
                } footer: {
                    Text(category.hint)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("add-move-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("add-move-save")
                }
            }
        }
    }

    private func save() {
        guard canSave else {
            error = trimmedName.isEmpty ? "Name is required" : "A move with that name already exists"
            return
        }
        let nextSortOrder = (existingMoves.compactMap { $0.sortOrder }.max() ?? -1) + 1
        let move = Move(context: viewContext)
        move.id = UUID()
        move.name = trimmedName
        move.sortOrder = Int16(truncatingIfNeeded: Int(nextSortOrder))
        move.isCustom = true
        move.measurementType = category.measurementTypeValue

        do {
            try viewContext.save()
            onCreated(move)
            dismiss()
        } catch {
            self.error = "Could not save: \(error.localizedDescription)"
        }
    }
}

private extension Optional where Wrapped == Int16 {
    var nonNil: Int16 { self ?? 0 }
}
