import SwiftUI

/// Sheet for referee score editing (total and round scores)
/// Includes quick adjustment chips and confirmation
struct ScoreEditingSheet: View {
    let player: Player
    let onSave: (Int, Int) -> Void  // (newTotalScore, newRoundScore)
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingTotalScore: Int
    @State private var editingRoundScore: Int
    @State private var showingConfirmation = false
    
    private let quickAdjustments = [-500, -100, -50, 50, 100, 500]
    
    init(player: Player, onSave: @escaping (Int, Int) -> Void) {
        self.player = player
        self.onSave = onSave
        _editingTotalScore = State(initialValue: player.totalScore)
        _editingRoundScore = State(initialValue: player.roundScore)
    }
    
    private var hasChanges: Bool {
        editingTotalScore != player.totalScore || editingRoundScore != player.roundScore
    }
    
    private var changeDescription: String {
        var parts: [String] = []
        if editingTotalScore != player.totalScore {
            parts.append("Total: \(player.totalScore) → \(editingTotalScore)")
        }
        if editingRoundScore != player.roundScore {
            parts.append("Round: \(player.roundScore) → \(editingRoundScore)")
        }
        return parts.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        
                        Text("Edit Score")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        Text("Adjusting \(player.name)'s score")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)
                    
                    // Total Score Section
                    ScoreEditSection(
                        title: "Total Score",
                        subtitle: "Banked points",
                        value: $editingTotalScore,
                        originalValue: player.totalScore,
                        quickAdjustments: quickAdjustments
                    )
                    
                    // Round Score Section
                    ScoreEditSection(
                        title: "Current Round",
                        subtitle: "Points in progress (not yet banked)",
                        value: $editingRoundScore,
                        originalValue: player.roundScore,
                        quickAdjustments: [-100, -50, 50, 100, 150, 200]
                    )
                    
                    // Warning about referee actions
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        
                        Text("Score changes are logged and visible in game history. Use this for correcting errors only.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Referee Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if hasChanges {
                            showingConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
        }
        .fullScreenCover(isPresented: $showingConfirmation) {
            ConfirmationOverlay(
                title: "Confirm Score Change",
                message: "This will modify \(player.name)'s score:\n\n\(changeDescription)\n\nThis action will be logged.",
                primaryActionTitle: "Apply Changes",
                primaryActionRole: nil,
                onPrimary: {
                    onSave(editingTotalScore, editingRoundScore)
                    dismiss()
                },
                onDismiss: {
                    showingConfirmation = false
                }
            )
            .background(ClearBackgroundViewForScoreEdit())
        }
    }
}

/// Section for editing a single score value
private struct ScoreEditSection: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let originalValue: Int
    let quickAdjustments: [Int]
    
    @State private var showingEditor = false
    
    private var hasChanged: Bool {
        value != originalValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and current value
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // Tappable value display
                Button {
                    showingEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Text(value.formatted())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(hasChanged ? .orange : .primary)
                        
                        if hasChanged {
                            Text("(\(originalValue.formatted()))")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Quick adjustment chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickAdjustments, id: \.self) { adjustment in
                        QuickAdjustChip(
                            adjustment: adjustment,
                            isEnabled: value + adjustment >= 0
                        ) {
                            let newValue = max(0, value + adjustment)
                            value = newValue
                            HapticFeedback.light()
                        }
                    }
                    
                    // Reset chip
                    if hasChanged {
                        Button {
                            value = originalValue
                            HapticFeedback.light()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Reset")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .sheet(isPresented: $showingEditor) {
            NumericInputSheet(
                title: title,
                currentValue: value,
                range: 0...100000,
                defaultValue: originalValue,
                onSave: { newValue in
                    value = newValue
                }
            )
            .presentationDetents([.medium])
        }
    }
}

/// Quick adjustment chip button
private struct QuickAdjustChip: View {
    let adjustment: Int
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(adjustment > 0 ? "+\(adjustment)" : "\(adjustment)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isEnabled ? (adjustment > 0 ? .green : .red) : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isEnabled
                        ? (adjustment > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        : Color(.systemGray5)
                )
                .cornerRadius(8)
        }
        .disabled(!isEnabled)
    }
}

/// Clear background helper for fullScreenCover
private struct ClearBackgroundViewForScoreEdit: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    ScoreEditingSheet(
        player: Player(name: "Alice", requiresOpeningScore: true, openingScoreThreshold: 500)
    ) { total, round in
        print("New scores: Total=\(total), Round=\(round)")
    }
}

