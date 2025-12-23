import SwiftUI

/// A reusable inline number stepper row with +/- buttons and tappable value
/// Flip-7 inspired: Quick steppers for common adjustments, tap value for precise entry
struct InlineNumberStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let defaultValue: Int?
    let subtitle: String?
    let isEnabled: Bool
    let disabledReason: String?
    
    @State private var showingEditor = false
    
    init(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 100,
        defaultValue: Int? = nil,
        subtitle: String? = nil,
        isEnabled: Bool = true,
        disabledReason: String? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
    }
    
    private var canDecrement: Bool {
        isEnabled && value > range.lowerBound
    }
    
    private var canIncrement: Bool {
        isEnabled && value < range.upperBound
    }
    
    private var isAtDefault: Bool {
        guard let def = defaultValue else { return false }
        return value == def
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Label
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // Stepper controls
                HStack(spacing: 8) {
                    // Decrement button
                    Button {
                        let newValue = max(range.lowerBound, value - step)
                        value = newValue
                        HapticFeedback.light()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(canDecrement ? .accentColor : Color(.systemGray4))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canDecrement)
                    
                    // Tappable value
                    Button {
                        showingEditor = true
                    } label: {
                        Text(value.formatted())
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(isEnabled ? .accentColor : .secondary)
                            .frame(minWidth: 60)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isEnabled)
                    
                    // Increment button
                    Button {
                        let newValue = min(range.upperBound, value + step)
                        value = newValue
                        HapticFeedback.light()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(canIncrement ? .accentColor : Color(.systemGray4))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canIncrement)
                }
            }
            
            // Disabled reason or custom indicator
            if !isEnabled, let reason = disabledReason {
                Text(reason)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.orange)
                    .italic()
            } else if !isAtDefault, let def = defaultValue {
                Text("Default: \(def.formatted())")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            NumericInputSheet(
                title: label,
                currentValue: value,
                range: range,
                defaultValue: defaultValue,
                onSave: { newValue in
                    value = newValue
                }
            )
            .presentationDetents([.medium])
        }
    }
}

/// Variant for use in List rows with proper styling
struct InlineNumberStepperListRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let defaultValue: Int?
    let isEnabled: Bool
    let disabledReason: String?
    
    @State private var showingEditor = false
    
    init(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 100,
        defaultValue: Int? = nil,
        isEnabled: Bool = true,
        disabledReason: String? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
    }
    
    private var canDecrement: Bool {
        isEnabled && value > range.lowerBound
    }
    
    private var canIncrement: Bool {
        isEnabled && value < range.upperBound
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(isEnabled ? .primary : .secondary)
            
            Spacer()
            
            // Decrement button
            Button {
                let newValue = max(range.lowerBound, value - step)
                value = newValue
                HapticFeedback.light()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(canDecrement ? .accentColor : Color(.systemGray4))
            }
            .buttonStyle(.borderless)
            .disabled(!canDecrement)
            
            // Tappable value
            Button {
                showingEditor = true
            } label: {
                Text(value.formatted())
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .frame(minWidth: 50)
            }
            .buttonStyle(.borderless)
            .disabled(!isEnabled)
            
            // Increment button
            Button {
                let newValue = min(range.upperBound, value + step)
                value = newValue
                HapticFeedback.light()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(canIncrement ? .accentColor : Color(.systemGray4))
            }
            .buttonStyle(.borderless)
            .disabled(!canIncrement)
        }
        .sheet(isPresented: $showingEditor) {
            NumericInputSheet(
                title: label,
                currentValue: value,
                range: range,
                defaultValue: defaultValue,
                onSave: { newValue in
                    value = newValue
                }
            )
            .presentationDetents([.medium])
        }
    }
}

#Preview("Inline Stepper") {
    struct PreviewWrapper: View {
        @State private var score = 10000
        var body: some View {
            VStack(spacing: 20) {
                InlineNumberStepperRow(
                    label: "Winning Score",
                    value: $score,
                    range: 1000...50000,
                    step: 1000,
                    defaultValue: 10000
                )
                .padding()
                
                InlineNumberStepperRow(
                    label: "Opening Score",
                    value: .constant(500),
                    range: 100...1000,
                    step: 50,
                    defaultValue: 500,
                    subtitle: "Required to get on board"
                )
                .padding()
                
                InlineNumberStepperRow(
                    label: "Disabled Example",
                    value: .constant(1000),
                    range: 100...5000,
                    isEnabled: false,
                    disabledReason: "Cannot change while in final round"
                )
                .padding()
            }
        }
    }
    return PreviewWrapper()
}

#Preview("List Row Variant") {
    struct PreviewWrapper: View {
        @State private var value = 500
        var body: some View {
            List {
                InlineNumberStepperListRow(
                    label: "Opening Score",
                    value: $value,
                    range: 100...1000,
                    step: 50,
                    defaultValue: 500
                )
            }
        }
    }
    return PreviewWrapper()
}

