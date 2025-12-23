import SwiftUI

/// Simple chip selector for any Identifiable type
struct SimpleChips<T: Identifiable & Hashable>: View {
    let options: [T]
    let selectedOption: T?
    let onSelect: (T) -> Void
    let labelForOption: (T) -> String
    let iconForOption: (T) -> String
    let colorForOption: ((T) -> Color)?
    
    init(
        options: [T],
        selectedOption: T?,
        onSelect: @escaping (T) -> Void,
        labelForOption: @escaping (T) -> String,
        iconForOption: @escaping (T) -> String,
        colorForOption: ((T) -> Color)? = nil
    ) {
        self.options = options
        self.selectedOption = selectedOption
        self.onSelect = onSelect
        self.labelForOption = labelForOption
        self.iconForOption = iconForOption
        self.colorForOption = colorForOption
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options) { option in
                    SimpleChip(
                        isSelected: selectedOption?.id == option.id,
                        label: labelForOption(option),
                        icon: iconForOption(option),
                        color: colorForOption?(option),
                        onTap: {
                            onSelect(option)
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct SimpleChip: View {
    let isSelected: Bool
    let label: String
    let icon: String
    let color: Color?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color ?? .primary)
                    .frame(width: 24, height: 24)
                
                Text(label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color ?? .blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? (color ?? .blue).opacity(0.15) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? (color ?? .blue).opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .buttonStyle(.plain)
    }
}

