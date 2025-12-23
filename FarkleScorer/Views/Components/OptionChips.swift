import SwiftUI

/// Horizontal scrolling chip selector for multi-option selection (Flip7-style)
struct OptionChips<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let options: [T]
    let selectedOption: T
    let onSelect: (T) -> Void
    let labelForOption: (T) -> String
    let iconForOption: (T) -> String
    let colorForOption: ((T) -> Color)?
    let previewColorsForOption: ((T) -> [Color])?
    
    init(
        options: [T],
        selectedOption: T,
        onSelect: @escaping (T) -> Void,
        labelForOption: @escaping (T) -> String,
        iconForOption: @escaping (T) -> String,
        colorForOption: ((T) -> Color)? = nil,
        previewColorsForOption: ((T) -> [Color])? = nil
    ) {
        self.options = options
        self.selectedOption = selectedOption
        self.onSelect = onSelect
        self.labelForOption = labelForOption
        self.iconForOption = iconForOption
        self.colorForOption = colorForOption
        self.previewColorsForOption = previewColorsForOption
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.rawValue) { option in
                    OptionChip(
                        option: option,
                        isSelected: option == selectedOption,
                        label: labelForOption(option),
                        icon: iconForOption(option),
                        color: colorForOption?(option),
                        previewColors: previewColorsForOption?(option),
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

struct OptionChip: View {
    let option: Any
    let isSelected: Bool
    let label: String
    let icon: String
    let color: Color?
    let previewColors: [Color]?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
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
                
                // Preview colors row (for palette selection)
                if let previewColors = previewColors {
                    HStack(spacing: 3) {
                        ForEach(0..<min(4, previewColors.count), id: \.self) { i in
                            Circle()
                                .fill(previewColors[i])
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 2)
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

