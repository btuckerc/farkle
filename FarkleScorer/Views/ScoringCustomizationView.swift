import SwiftUI

/// View for customizing scoring rules (house rules)
/// Uses ScoringRulesStore for persistence and affects actual gameplay
struct ScoringCustomizationView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss

    // Local copy of rules for editing (applied on save)
    @State private var editingRules: ScoringRulesStore
    @State private var hasUnsavedChanges = false
    
    private var canEdit: Bool {
        gameEngine.canEditRules
    }
    
    init(gameEngine: GameEngine) {
        self.gameEngine = gameEngine
        _editingRules = State(initialValue: gameEngine.scoringRulesStore)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(editingRules.isCustomized ? .orange : .secondary)
                        
                        Text("Scoring Rules")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text("Customize point values for dice combinations")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Custom indicator
                        if editingRules.isCustomized {
                            HStack(spacing: 6) {
                                Image(systemName: "paintbrush.fill")
                                    .font(.caption)
                                Text("Using Custom Rules")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Host-only banner (in multiplayer)
                        if !canEdit, let reason = gameEngine.editingDisabledReason {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(.orange)
                                Text(reason)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Single Dice Section
                    ScoringSection(title: "Single Dice", icon: "die.face.1") {
                        ForEach(ScoringRulesStore.singleDiceFields, id: \.label) { field in
                            ScoringFieldRow(
                                rules: $editingRules,
                                field: field,
                                isEnabled: canEdit,
                                onChanged: { hasUnsavedChanges = true }
                            )
                        }
                    }

                    // Three of a Kind Section
                    ScoringSection(title: "Three of a Kind", icon: "die.face.3") {
                        ForEach(ScoringRulesStore.threeOfAKindFields, id: \.label) { field in
                            ScoringFieldRow(
                                rules: $editingRules,
                                field: field,
                                isEnabled: canEdit,
                                onChanged: { hasUnsavedChanges = true }
                            )
                        }
                    }

                    // Special Combinations Section
                    ScoringSection(title: "Special Combinations", icon: "sparkles") {
                        ForEach(ScoringRulesStore.specialCombinationFields, id: \.label) { field in
                            ScoringFieldRow(
                                rules: $editingRules,
                                field: field,
                                isEnabled: canEdit,
                                onChanged: { hasUnsavedChanges = true }
                            )
                        }
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: saveAndDismiss) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(canEdit && hasUnsavedChanges ? "Save Changes" : "Done")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        if canEdit && editingRules.isCustomized {
                            Button(action: resetToDefaults) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Reset to Official Rules")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Scoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        if canEdit && (hasUnsavedChanges || editingRules != gameEngine.scoringRulesStore) {
            gameEngine.scoringRulesStore = editingRules
            gameEngine.saveScoringRules()
            HapticFeedback.medium()
        }
        dismiss()
    }

    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.2)) {
            editingRules = ScoringRulesStore.officialDefaults
            hasUnsavedChanges = true
        }
        HapticFeedback.light()
    }
}

// MARK: - Supporting Views

/// Section wrapper with icon and title
private struct ScoringSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        FarkleCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                
                VStack(spacing: 8) {
                    content()
                }
            }
        }
    }
}

/// Row for editing a single scoring field
private struct ScoringFieldRow: View {
    @Binding var rules: ScoringRulesStore
    let field: ScoringRulesStore.FieldInfo
    let isEnabled: Bool
    let onChanged: () -> Void
    
    @State private var showingEditor = false
    
    private var value: Int {
        rules[keyPath: field.key]
    }
    
    private var isAtDefault: Bool {
        value == field.defaultValue
    }
    
    private var canDecrement: Bool {
        isEnabled && value > field.range.lowerBound
    }
    
    private var canIncrement: Bool {
        isEnabled && value < field.range.upperBound
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                
                if !isAtDefault {
                    Text("Official: \(field.defaultValue)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Decrement
                Button {
                    let newValue = max(field.range.lowerBound, value - field.step)
                    rules[keyPath: field.key] = newValue
                    onChanged()
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(canDecrement ? .accentColor : .gray.opacity(0.3))
                        .font(.title2)
                }
                .disabled(!canDecrement)

                // Tappable value
                Button {
                    if isEnabled {
                        showingEditor = true
                    }
                } label: {
                    Text(value.formatted())
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isEnabled ? (isAtDefault ? .primary : .orange) : .secondary)
                        .frame(minWidth: 55)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isAtDefault ? Color.clear : Color.orange.opacity(0.5), lineWidth: 1)
                        )
                }
                .disabled(!isEnabled)

                // Increment
                Button {
                    let newValue = min(field.range.upperBound, value + field.step)
                    rules[keyPath: field.key] = newValue
                    onChanged()
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(canIncrement ? .accentColor : .gray.opacity(0.3))
                        .font(.title2)
                }
                .disabled(!canIncrement)
            }
        }
        .sheet(isPresented: $showingEditor) {
            NumericInputSheet(
                title: field.label,
                currentValue: value,
                range: field.range,
                defaultValue: field.defaultValue,
                onSave: { newValue in
                    rules[keyPath: field.key] = newValue
                    onChanged()
                }
            )
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    ScoringCustomizationView(gameEngine: GameEngine())
}
