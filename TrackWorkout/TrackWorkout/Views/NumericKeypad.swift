import SwiftUI

struct NumericKeypad: View {
    let onDigit: (String) -> Void
    let onDecimal: () -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void
    let showDecimal: Bool
    let showColon: Bool
    let onColon: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                KeypadButton(label: "\(digit)") {
                    onDigit("\(digit)")
                }
            }

            // Bottom row
            if showColon {
                KeypadButton(label: ":") {
                    onColon()
                }
            } else if showDecimal {
                KeypadButton(label: ".") {
                    onDecimal()
                }
            } else {
                KeypadButton(label: "C", style: .secondary) {
                    onClear()
                }
            }

            KeypadButton(label: "0") {
                onDigit("0")
            }

            KeypadButton(label: "delete.left.fill", isSystemImage: true, style: .secondary) {
                onBackspace()
            }
        }
    }
}

enum KeypadButtonStyle {
    case primary
    case secondary
}

struct KeypadButton: View {
    let label: String
    var isSystemImage: Bool = false
    var style: KeypadButtonStyle = .primary

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isSystemImage {
                    Image(systemName: label)
                        .font(.title3)
                } else {
                    Text(label)
                        .font(.title2)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(style == .primary ? .primary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(style == .primary ? Color(.systemGray5) : Color(.systemGray))
            .cornerRadius(10)
        }
        .buttonStyle(KeypadButtonPressStyle())
    }
}

struct KeypadButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NumericKeypad(
        onDigit: { print($0) },
        onDecimal: { print(".") },
        onBackspace: { print("backspace") },
        onClear: { print("clear") },
        showDecimal: true,
        showColon: false,
        onColon: { print(":") }
    )
    .padding()
}
