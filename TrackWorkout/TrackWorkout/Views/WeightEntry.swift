import SwiftUI

struct WeightEntry: View {
    @Binding var value: String
    let isActive: Bool
    var isDisabled: Bool = false
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weight")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack {
                Text(value.isEmpty ? "0" : value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                if !isDisabled {
                    onTap()
                }
            }
            .opacity(isDisabled ? 0.5 : 1)
        }
    }
}

#Preview {
    VStack {
        WeightEntry(value: .constant("135.5"), isActive: true, onTap: {})
        WeightEntry(value: .constant(""), isActive: false, isDisabled: true, onTap: {})
    }
    .padding()
}
