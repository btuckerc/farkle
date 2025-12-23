import SwiftUI

/// SwiftUI sheet for numeric input with range validation, optional default, and keyboard toolbar
/// Flip-7 inspired: clean UX with reset-to-default and Done toolbar
struct NumericInputSheet: View {
    let title: String
    let currentValue: Int
    let range: ClosedRange<Int>
    let defaultValue: Int?
    let onSave: (Int) -> Void
    let onCancel: () -> Void
    
    @State private var inputValue: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(
        title: String,
        currentValue: Int,
        range: ClosedRange<Int>,
        defaultValue: Int? = nil,
        onSave: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.currentValue = currentValue
        self.range = range
        self.defaultValue = defaultValue
        self.onSave = onSave
        self.onCancel = onCancel
        _inputValue = State(initialValue: "\(currentValue)")
    }
    
    private var parsedValue: Int? {
        Int(inputValue)
    }
    
    private var clampedValue: Int {
        guard let value = parsedValue else { return range.lowerBound }
        return max(range.lowerBound, min(range.upperBound, value))
    }
    
    private var isValid: Bool {
        guard let value = parsedValue else { return false }
        return range.contains(value)
    }
    
    private var isAtDefault: Bool {
        guard let defaultVal = defaultValue, let value = parsedValue else { return false }
        return value == defaultVal
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Instructions
                Text("Enter new value")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
                // Text field with focus border
                TextField("", text: $inputValue)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isFocused = false
                            }
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                    }
                
                // Range hint and reset
                HStack {
                    Text("Range: \(range.lowerBound.formatted()) – \(range.upperBound.formatted())")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    // Reset to default button
                    if let defaultVal = defaultValue, !isAtDefault {
                        Button("Reset to \(defaultVal.formatted())") {
                            inputValue = "\(defaultVal)"
                            HapticFeedback.light()
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.accentColor)
                    }
                }
                
                // Validation message
                if !inputValue.isEmpty && !isValid {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Value will be clamped to \(clampedValue.formatted())")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let finalValue = clampedValue
                        onSave(finalValue)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Focus text field when sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isValid)
        }
    }
}

#Preview("With Default") {
    NumericInputSheet(
        title: "Winning Score",
        currentValue: 10000,
        range: 1000...50000,
        defaultValue: 10000,
        onSave: { _ in }
    )
}

#Preview("Without Default") {
    NumericInputSheet(
        title: "Custom Score",
        currentValue: 500,
        range: 100...5000,
        onSave: { _ in }
    )
}
