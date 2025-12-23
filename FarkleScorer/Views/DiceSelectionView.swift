import SwiftUI

struct DiceSelectionView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var selectedIndices: Set<Int> = []
    @State private var showingSuggestions = false
    @State private var validationWarning: String? = nil
    @State private var invalidIndices: Set<Int> = []
    
    // PERF: Single shared ScoringEngine instance - no repeated allocations
    private let scoringEngine = ScoringEngine()
    
    // PERF: Precomputed scoring indices - computed once per roll, not per-die
    private var scoringIndices: Set<Int> {
        scoringEngine.getScoringDiceIndices(for: gameEngine.currentRoll)
    }

    private var selectedDice: [Int] {
        selectedIndices.compactMap { (index: Int) -> Int? in
            guard index < gameEngine.currentRoll.count else { return nil }
            return gameEngine.currentRoll[index]
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Preserved calculator points banner (compact)
            if gameEngine.hasManualTurnInProgress {
                HStack(spacing: 4) {
                    Image(systemName: "calculator")
                        .font(.caption2)
                    Text("Calculator: \(gameEngine.manualTurnScore) pts saved")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Farkle Acknowledgment Overlay
            if gameEngine.pendingFarkle {
                FarkleAcknowledgmentView(gameEngine: gameEngine)
                    .transition(.scale.combined(with: .opacity))
            } else if !gameEngine.currentRoll.isEmpty {
                // Compact dice area
                VStack(spacing: 8) {
                    // Dice grid with integrated toolbar
                    DiceGridWithToolbar(
                        dice: gameEngine.currentRoll,
                        selectedIndices: $selectedIndices,
                        invalidIndices: invalidIndices,
                        scoringIndices: scoringIndices,
                        allScoringDiceSelected: allScoringDiceSelected,
                        hasSelectableScoring: hasSelectableScoring,
                        showingSuggestions: $showingSuggestions,
                        onSelectionChanged: updateSelection,
                        onToggleSelectAll: toggleSelectAll
                    )
                    
                    // Compact warnings (only when needed)
                    if gameEngine.invalidSelectionWarning {
                        CompactWarningBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: "Select at least one scoring die to continue",
                            color: .red
                        )
                    } else if let warning = validationWarning {
                        let isJustTip = warning.starts(with: "Tip:")
                        CompactWarningBanner(
                            icon: isJustTip ? "lightbulb.fill" : "exclamationmark.triangle.fill",
                            message: warning,
                            color: isJustTip ? .blue : .orange,
                            showFixButton: !isJustTip,
                            onFix: fixInvalidSelection
                        )
                    }
                    
                    // Suggestions (compact, overlay-style)
                    if showingSuggestions {
                        CompactSuggestionsView(gameEngine: gameEngine) { suggestion in
                            selectSuggestion(suggestion)
                            showingSuggestions = false
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(12)
        .background(FarkleTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: FarkleTheme.shadowColor, radius: 6, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: gameEngine.pendingFarkle)
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
        .onChange(of: gameEngine.currentRoll) { _, _ in
            // PERF: Only reset local state; engine state resets are handled by GameEngine itself
            selectedIndices.removeAll()
            validationWarning = nil
            invalidIndices.removeAll()
            showingSuggestions = false
        }
    }

    private func updateSelection() {
        let dice: [Int] = selectedIndices.compactMap { index in
            guard index < gameEngine.currentRoll.count else { return nil }
            return gameEngine.currentRoll[index]
        }

        // PERF: Use shared scoringEngine instance
        let validation = scoringEngine.validateDiceSelection(selectedIndices, for: gameEngine.currentRoll)

        if validation.isValid {
            // Check if it's a tip (valid but with a suggestion)
            if validation.reason?.starts(with: "Tip:") == true {
                validationWarning = validation.reason
                invalidIndices = []
            } else {
                validationWarning = nil
                invalidIndices = []
            }
            gameEngine.selectDice(dice)
        } else {
            validationWarning = validation.reason
            invalidIndices = Set(validation.invalidIndices)
            // Still update the engine with the selection to show the score
            gameEngine.selectDice(dice)
        }
    }

    private func selectSuggestion(_ suggestion: ScoringOption) {
        // Find indices of dice that match the suggestion
        var remainingToSelect = suggestion.selectedDice.sorted()
        var newSelection: Set<Int> = []

        for (index, die) in gameEngine.currentRoll.enumerated() {
            if let matchIndex = remainingToSelect.firstIndex(of: die) {
                newSelection.insert(index)
                remainingToSelect.remove(at: matchIndex)
            }
        }

        selectedIndices = newSelection
        updateSelection()
    }

    private var hasSelectableScoring: Bool {
        !gameEngine.currentRoll.isEmpty && !scoringIndices.isEmpty
    }

    private var allScoringDiceSelected: Bool {
        // PERF: Use precomputed scoringIndices
        guard hasSelectableScoring else { return false }
        return scoringIndices.isSubset(of: selectedIndices)
    }

    private func selectAllScoringDice() {
        // PERF: Use precomputed scoringIndices
        selectedIndices = scoringIndices
        updateSelection()
    }

    private func toggleSelectAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if allScoringDiceSelected {
                // Deselect all
                selectedIndices.removeAll()
            } else {
                // Select all scoring dice
                selectAllScoringDice()
                return // selectAllScoringDice already calls updateSelection()
            }
            updateSelection()
        }
    }

    private func fixInvalidSelection() {
        // PERF: Use shared scoringEngine instance
        
        // Try to find the best valid selection based on current selection
        // Count dice values in current selection
        let diceCounts = Dictionary(grouping: selectedIndices) { index in
            gameEngine.currentRoll[index]
        }.mapValues { $0.count }

        var newSelection: Set<Int> = []

        // For each die value, decide whether to select all or none
        for (dieValue, count) in diceCounts {
            let allIndicesForValue = gameEngine.currentRoll.enumerated().compactMap { (index, value) in
                value == dieValue ? index : nil
            }

            if count >= 3 || (dieValue == 1) || (dieValue == 5) {
                // If we have 3+ of this value, or it's 1s or 5s, select all of this value
                if allIndicesForValue.count >= 3 {
                    // Select all of this value for three-of-a-kind
                    newSelection.formUnion(allIndicesForValue)
                } else if dieValue == 1 || dieValue == 5 {
                    // Select all 1s and 5s
                    newSelection.formUnion(allIndicesForValue)
                }
            }
        }

        // If we couldn't create a valid selection, fall back to precomputed scoring indices
        if newSelection.isEmpty {
            newSelection = scoringIndices
        }

        // Validate the new selection
        let validation = scoringEngine.validateDiceSelection(newSelection, for: gameEngine.currentRoll)

        if validation.isValid {
            selectedIndices = newSelection
        } else {
            // If still invalid, just deselect the problematic dice
            selectedIndices.subtract(invalidIndices)
        }

        updateSelection()
    }
}

// MARK: - Compact Dice Grid with Integrated Toolbar
struct DiceGridWithToolbar: View {
    let dice: [Int]
    @Binding var selectedIndices: Set<Int>
    let invalidIndices: Set<Int>
    let scoringIndices: Set<Int>
    let allScoringDiceSelected: Bool
    let hasSelectableScoring: Bool
    @Binding var showingSuggestions: Bool
    let onSelectionChanged: () -> Void
    let onToggleSelectAll: () -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    
    var body: some View {
        VStack(spacing: 0) {
            // Dice grid first
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(dice.enumerated()), id: \.offset) { index, die in
                    DiceView(
                        value: die,
                        isSelected: selectedIndices.contains(index),
                        canScore: scoringIndices.contains(index),
                        isInvalid: invalidIndices.contains(index)
                    ) {
                        toggleSelection(at: index)
                    }
                }
            }
            .padding(12)
            .background(FarkleTheme.tertiaryBackground)
            
            // Toolbar row below dice
            HStack(spacing: 8) {
                // Select All/None toggle with clear labels
                Button(action: onToggleSelectAll) {
                    HStack(spacing: 5) {
                        Image(systemName: allScoringDiceSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13, weight: .medium))
                        Text(allScoringDiceSelected ? "Select None" : "Select All Scoring")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(hasSelectableScoring ? .blue : .gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill((hasSelectableScoring ? Color.blue : Color.gray).opacity(0.1))
                    )
                }
                .disabled(!hasSelectableScoring)
                
                Spacer()
                
                // Suggestions toggle with label - square button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingSuggestions.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showingSuggestions ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tips")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple.opacity(showingSuggestions ? 0.15 : 0.08))
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(FarkleTheme.tertiaryBackground)
        }
        .cornerRadius(14)
    }
    
    private func toggleSelection(at index: Int) {
        guard scoringIndices.contains(index) else { return }
        HapticFeedback.selectionChanged()
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
        onSelectionChanged()
    }
}

// MARK: - Compact Warning Banner
struct CompactWarningBanner: View {
    let icon: String
    let message: String
    let color: Color
    var showFixButton: Bool = false
    var onFix: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Spacer(minLength: 4)
            
            if showFixButton, let onFix = onFix {
                Button("Fix", action: onFix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Compact Suggestions View
struct CompactSuggestionsView: View {
    let gameEngine: GameEngine
    let onSuggestionSelected: (ScoringOption) -> Void
    
    /// Safely computed suggestions with guard against empty/invalid state
    private var suggestions: [ScoringOption] {
        // Guard against empty or invalid roll state
        guard !gameEngine.currentRoll.isEmpty,
              gameEngine.currentRoll.count <= 6,
              gameEngine.currentRoll.allSatisfy({ $0 >= 1 && $0 <= 6 }) else {
            return []
        }
        
        // Safely get suggestions with a limit
        let allSuggestions = gameEngine.getPossibleScorings(for: gameEngine.currentRoll)
        return Array(allSuggestions.prefix(3))
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Use stable identifier based on suggestion content, not array index
            ForEach(suggestions, id: \.stableId) { suggestion in
                Button(action: { onSuggestionSelected(suggestion) }) {
                    HStack(spacing: 8) {
                        // Dice chips - use index for display only
                        HStack(spacing: 2) {
                            ForEach(0..<min(4, suggestion.selectedDice.count), id: \.self) { idx in
                                Text("\(suggestion.selectedDice[idx])")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.purple.opacity(0.8))
                                    .cornerRadius(3)
                            }
                            if suggestion.selectedDice.count > 4 {
                                Text("+\(suggestion.selectedDice.count - 4)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                        }
                        
                        Text(suggestion.description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(suggestion.score)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct DiceView: View {
    let value: Int
    let isSelected: Bool
    let canScore: Bool
    let isInvalid: Bool
    let onTap: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                onTap()
            }
        }) {
            ZStack {
                // Dice background
                RoundedRectangle(cornerRadius: 10)
                    .fill(diceBackgroundColor)
                    .shadow(color: .black.opacity(0.2), radius: isPressed ? 2 : 3, x: 0, y: isPressed ? 1 : 2)

                // Selection ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isInvalid ? FarkleTheme.diceInvalid : FarkleTheme.diceSelected, lineWidth: 2.5)
                        .scaleEffect(1.05)
                }

                // Invalid selection indicator (brief shake, not continuous)
                if isInvalid && isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(FarkleTheme.diceInvalid, lineWidth: 2.5)
                        .scaleEffect(1.1)
                        .opacity(0.8)
                }

                // PERF: Static scoring indicator - no continuous animation
                // Uses a subtle but clear border to show scoreable dice
                if canScore && !isSelected && !isInvalid {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(FarkleTheme.diceScoring.opacity(0.7), lineWidth: 2)
                        .shadow(color: FarkleTheme.diceScoring.opacity(0.3), radius: 3, x: 0, y: 0)
                        .scaleEffect(1.02)
                }

                // Dice dots or number
                DiceDotsView(value: value)
                
                // Differentiate Without Color: show icons for state
                if differentiateWithoutColor {
                    DiceStateIndicator(isSelected: isSelected, canScore: canScore, isInvalid: isInvalid)
                }
            }
            .frame(width: 60, height: 60)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        // Accessibility support
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityValue(accessibilityValueText)
        .accessibilityAddTraits(.isButton)
    }

    private var diceBackgroundColor: Color {
        if isSelected && isInvalid {
            return FarkleTheme.diceInvalid.opacity(0.2)
        } else if isSelected {
            return FarkleTheme.diceSelected.opacity(0.2)
        } else if canScore {
            return FarkleTheme.diceScoring.opacity(0.1)
        } else {
            return FarkleTheme.cardBackground
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabelText: String {
        "Die showing \(value)"
    }
    
    private var accessibilityValueText: String {
        if isSelected && isInvalid {
            return "Selected, invalid selection"
        } else if isSelected {
            return "Selected"
        } else if canScore {
            return "Can score"
        } else {
            return "Cannot score"
        }
    }
    
    private var accessibilityHintText: String {
        if canScore {
            return isSelected ? "Double tap to deselect" : "Double tap to select"
        } else {
            return "This die cannot score"
        }
    }
}

/// Visual indicator for dice state when Differentiate Without Color is enabled
struct DiceStateIndicator: View {
    let isSelected: Bool
    let canScore: Bool
    let isInvalid: Bool
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                if isSelected && isInvalid {
                    // Invalid selection: warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Circle().fill(FarkleTheme.diceInvalid))
                } else if isSelected {
                    // Selected: checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FarkleTheme.diceSelected)
                } else if canScore {
                    // Can score: star indicator
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(FarkleTheme.diceScoring)
                }
            }
            Spacer()
        }
        .padding(4)
    }
}

struct DiceDotsView: View {
    let value: Int

    var body: some View {
        ZStack {
            // Use dots for visual dice representation
            switch value {
            case 1:
                Circle()
                    .fill(FarkleTheme.diceDots)
                    .frame(width: 8, height: 8)
            case 2:
                                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Spacer()
                        }
                        HStack(spacing: 16) {
                            Spacer()
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                    }
                .frame(width: 24, height: 24)
            case 3:
                                    VStack(spacing: 6) {
                        HStack {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Spacer()
                        }
                        Center {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                        HStack {
                            Spacer()
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                    }
                .frame(width: 24, height: 24)
            case 4:
                                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                    }
            case 5:
                                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                        Center {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                    }
            case 6:
                                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                            Circle().fill(FarkleTheme.diceDots).frame(width: 6, height: 6)
                        }
                    }
            default:
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }
}

struct Center<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack {
            Spacer()
            content
            Spacer()
        }
    }
}

// ActionButtonsSection removed - actions moved to floating action bar in ContentView

struct FarkleAcknowledgmentView: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 20) {
            // Large FARKLE display
            VStack(spacing: 12) {
                Text("💀 FARKLE! 💀")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .scaleEffect(1.2)

                Text("\(gameEngine.farklePlayerName) scored no points!")
                    .font(.headline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)

                // Show the dice that caused the farkle
                if !gameEngine.farkleDice.isEmpty {
                    VStack(spacing: 8) {
                        Text("Dice rolled:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: min(6, gameEngine.farkleDice.count)), spacing: 8) {
                            ForEach(Array(gameEngine.farkleDice.enumerated()), id: \.offset) { _, die in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 40, height: 40)

                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        .frame(width: 40, height: 40)

                                    Text("\(die)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Text("All points in this round are lost.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Hint to use bottom bar
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                    Text("Tap below to continue")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(FarkleTheme.textSecondary)
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(FarkleTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
        )
    }
}

#Preview {
    DiceSelectionView(gameEngine: {
        let engine = GameEngine()
        engine.addPlayer(name: "Test Player")
        engine.startGame()
        engine.currentRoll = [1, 2, 3, 5, 5, 6]
        return engine
    }())
}
