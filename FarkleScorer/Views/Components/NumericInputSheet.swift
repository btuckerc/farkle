import SwiftUI

/// SwiftUI sheet for numeric input with range validation (replaces UIKit alert)
struct NumericInputSheet: View {
    let title: String
    let currentValue: Int
    let range: ClosedRange<Int>
    let onSave: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var inputValue: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(title: String, currentValue: Int, range: ClosedRange<Int>, onSave: @escaping (Int) -> Void, onCancel: @escaping () -> Void = {}) {
        self.title = title
        self.currentValue = currentValue
        self.range = range
        self.onSave = onSave
        self.onCancel = onCancel
        _inputValue = State(initialValue: "\(currentValue)")
    }
    
    private var isValid: Bool {
        guard let value = Int(inputValue) else { return false }
        return range.contains(value)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter new value")
                    .farkleCaption()
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Range: \(range.lowerBound) - \(range.upperBound)")
                        .farkleCaption()
                    
                    TextField("", text: $inputValue)
                        .keyboardType(.numberPad)
                        .farkleValueMedium()
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .focused($isFocused)
                        .onAppear {
                            isFocused = true
                        }
                    
                    if !inputValue.isEmpty && !isValid {
                        Text("Value must be between \(range.lowerBound) and \(range.upperBound)")
                            .farkleCaption()
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Save") {
                        if let value = Int(inputValue), isValid {
                            onSave(value)
                            dismiss()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isValid)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

