import SwiftUI

struct MoveSelector: View {
    let moves: [Move]
    @Binding var selectedMove: Move?
    var onAddMove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(moves, id: \.id) { move in
                    Button(action: {
                        selectedMove = move
                    }) {
                        HStack {
                            Text(move.name ?? "Unknown")
                            if selectedMove?.id == move.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedMove?.name ?? "Select Exercise")
                        .foregroundColor(selectedMove == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }

            if let onAddMove = onAddMove {
                Button(action: onAddMove) {
                    Text("+")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
        }
    }
}

#Preview {
    MoveSelector(moves: [], selectedMove: .constant(nil))
        .padding()
}
