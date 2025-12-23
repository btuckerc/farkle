import SwiftUI

struct DiceSelectionView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var selectedIndices: Set<Int> = []
    @State private var showingSuggestions = false
    @State private var validationWarning: String? = nil
    @State private var invalidIndices: Set<Int> = []
    @State private var tapAnimationScale: CGFloat = 1.0
    @State private var textAnimationOpacity: Double = 1.0

    private var selectedDice: [Int] {
        selectedIndices.compactMap { (index: Int) -> Int? in
            guard index < gameEngine.currentRoll.count else { return nil }
            return gameEngine.currentRoll[index]
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 16) {
                        // Header with farkle detection
            HStack {
                // Animated call-to-action instead of static text - hide during farkle
                if !gameEngine.pendingFarkle {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .scaleEffect(tapAnimationScale)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: tapAnimationScale)

                        Text("Tap scoring dice to select")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .opacity(textAnimationOpacity)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: textAnimationOpacity)
                    }
                    .onAppear {
                        tapAnimationScale = 1.1
                        textAnimationOpacity = 0.8
                    }
                }

                Spacer()

                if !gameEngine.currentRoll.isEmpty && !gameEngine.canScoreAnyPoints(for: gameEngine.currentRoll) && !gameEngine.pendingFarkle {
                    Text("FARKLE!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.5).repeatCount(3), value: gameEngine.currentRoll)
                }
            }

            // Farkle Acknowledgment Overlay
            if gameEngine.pendingFarkle {
                FarkleAcknowledgmentView(gameEngine: gameEngine)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
            } else {
                // Natural responsive layout with wiggle prevention
                VStack(spacing: 16) {
                    // Dice display
                    if !gameEngine.currentRoll.isEmpty {
                        DiceGrid(
                            dice: gameEngine.currentRoll,
                            selectedIndices: $selectedIndices,
                            invalidIndices: invalidIndices,
                            onSelectionChanged: updateSelection
                        )

                        // Action buttons row - ALWAYS PRESENT to prevent layout shifts
                        HStack(spacing: 12) {
                            // Select All/None toggle button - always present, may be disabled
                            Button(action: toggleSelectAll) {
                                HStack(spacing: 8) {
                                    Image(systemName: allScoringDiceSelected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 20)

                                    Text(allScoringDiceSelected ? "Select None" : "Select All Scoring")
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .foregroundColor(hasSelectableScoring ? .blue : .gray)
                                .frame(width: 180, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background((hasSelectableScoring ? Color.blue : Color.gray).opacity(allScoringDiceSelected ? 0.15 : 0.1))
                                .cornerRadius(8)
                            }
                            .disabled(!hasSelectableScoring)

                            // Suggestions toggle button
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingSuggestions.toggle()
                                }

                                if showingSuggestions {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut(duration: 0.6)) {
                                            proxy.scrollTo("suggestions", anchor: .center)
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: showingSuggestions ? "lightbulb.fill" : "lightbulb")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.purple)
                                    .padding(10)
                                    .background(Color.purple.opacity(showingSuggestions ? 0.15 : 0.08))
                                    .cornerRadius(8)
                            }
                            .frame(width: 44)
                        }
                        .frame(height: 44)
                    }

                    // Selection info card - STABLE LAYOUT
                    SelectionInfoCard(
                        selectedDice: selectedDice,
                        score: gameEngine.turnScore,
                        gameEngine: gameEngine,
                        hasSelection: !selectedIndices.isEmpty
                    )

                    // Warning area - ALWAYS PRESENT CONTAINER to prevent layout shifts
                    Group {
                        if gameEngine.invalidSelectionWarning {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Invalid Selection")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                                Text("You must select at least one scoring die combination before continuing to roll.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .transition(.opacity)
                        } else if let warning = validationWarning {
                            let isJustTip = warning.starts(with: "Tip:")
                            let color: Color = isJustTip ? .blue : .orange
                            let title = isJustTip ? "Scoring Tip" : "Selection Rule Violation"

                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: isJustTip ? "lightbulb.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(color)
                                    Text(title)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                }
                                Text(warning)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                if !isJustTip {
                                    Button("Fix Selection") {
                                        fixInvalidSelection()
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(color.opacity(0.1))
                            .cornerRadius(12)
                            .transition(.opacity)
                        }
                    }

                    // Suggestions area
                    if showingSuggestions && !gameEngine.currentRoll.isEmpty {
                        SuggestionsSection(gameEngine: gameEngine) { suggestion in
                            selectSuggestion(suggestion)
                            showingSuggestions = false
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .id("suggestions")
                    }
                }
            }
            }
            .padding()
            .animation(.easeInOut(duration: 0.3), value: gameEngine.pendingFarkle)
            .onChange(of: gameEngine.currentRoll) { _, _ in
                selectedIndices.removeAll()
                validationWarning = nil
                invalidIndices.removeAll()
                gameEngine.selectDice([])
            }
        }
    }

    private func updateSelection() {
        let dice: [Int] = selectedIndices.compactMap { index in
            guard index < gameEngine.currentRoll.count else { return nil }
            return gameEngine.currentRoll[index]
        }

                // Validate the selection according to Farkle rules
        let scoringEngine = ScoringEngine()
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
        !gameEngine.currentRoll.isEmpty && gameEngine.canScoreAnyPoints(for: gameEngine.currentRoll)
    }

    private var allScoringDiceSelected: Bool {
        guard hasSelectableScoring else { return false }
        let scoringEngine = ScoringEngine()
        let scoringIndices = scoringEngine.getScoringDiceIndices(for: gameEngine.currentRoll)
        return !scoringIndices.isEmpty && scoringIndices.isSubset(of: selectedIndices)
    }

    private func selectAllScoringDice() {
        let scoringEngine = ScoringEngine()
        let scoringIndices = scoringEngine.getScoringDiceIndices(for: gameEngine.currentRoll)
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
        let scoringEngine = ScoringEngine()

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

        // If we couldn't create a valid selection, fall back to selecting all scoring dice
        if newSelection.isEmpty {
            let scoringIndices = scoringEngine.getScoringDiceIndices(for: gameEngine.currentRoll)
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

struct DiceGrid: View {
    let dice: [Int]
    @Binding var selectedIndices: Set<Int>
    let invalidIndices: Set<Int>
    let onSelectionChanged: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(dice.enumerated()), id: \.offset) { index, die in
                DiceView(
                    value: die,
                    isSelected: selectedIndices.contains(index),
                    canScore: canScore(at: index),
                    isInvalid: invalidIndices.contains(index)
                ) {
                    toggleSelection(at: index)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }

    private func canScore(at index: Int) -> Bool {
        let scoringEngine = ScoringEngine()
        return scoringEngine.canDieScore(at: index, in: dice)
    }

    private func toggleSelection(at index: Int) {
        // Only allow selection of dice that can actually score
        guard canScore(at: index) else { return }

        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
        onSelectionChanged()
    }
}

struct DiceView: View {
    let value: Int
    let isSelected: Bool
    let canScore: Bool
    let isInvalid: Bool
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var glowOpacity: Double = 0.6
    @State private var glowRadius: CGFloat = 2

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                onTap()
            }
        }) {
            ZStack {
                // Dice background
                RoundedRectangle(cornerRadius: 12)
                    .fill(diceBackgroundColor)
                    .shadow(color: .black.opacity(0.2), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
                    .scaleEffect(isPressed ? 0.95 : 1.0)

                // Selection ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isInvalid ? FarkleTheme.diceInvalid : FarkleTheme.diceSelected, lineWidth: 3)
                        .scaleEffect(1.05)
                }

                // Invalid selection indicator
                if isInvalid && isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FarkleTheme.diceInvalid, lineWidth: 3)
                        .scaleEffect(1.1)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: isInvalid)
                }

                // Scoring indicator with attractive glow animation
                if canScore && !isSelected && !isInvalid {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FarkleTheme.diceScoring.opacity(glowOpacity), lineWidth: 2)
                        .shadow(color: FarkleTheme.diceScoring.opacity(glowOpacity * 0.4), radius: glowRadius, x: 0, y: 0)
                        .scaleEffect(1.02)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                glowOpacity = 0.9
                                glowRadius = 6
                            }
                        }
                }

                // Dice dots or number
                DiceDotsView(value: value)
            }
            .frame(width: 70, height: 70)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
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

struct SelectionInfoCard: View {
    let selectedDice: [Int]
    let score: Int
    let gameEngine: GameEngine
    let hasSelection: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Selected:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // FIXED SIZE container for dice selection - never changes dimensions
                        HStack(spacing: 4) {
                            if hasSelection {
                                // Show up to 6 dice with fixed positions
                                ForEach(0..<6, id: \.self) { index in
                                    if index < selectedDice.count {
                                        Text("\(selectedDice[index])")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(FarkleTheme.diceSelected)
                                            .cornerRadius(4)
                                    } else {
                                        // Invisible placeholder to maintain consistent width
                                        Text("")
                                            .frame(width: 24, height: 24)
                                    }
                                }
                            } else {
                                Text("—")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 164, height: 24, alignment: .leading) // Fixed width for 6 dice + spacing
                            }
                        }
                        .frame(width: 164, height: 24) // FIXED DIMENSIONS - 6 dice (24px) + 5 spacers (4px)
                    }

                    HStack {
                        Text("Round Total:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading) // Fixed width

                        let currentRoundScore = gameEngine.currentPlayer?.roundScore ?? 0
                        let projectedTotal = currentRoundScore + (hasSelection ? score : 0)

                        // FIXED WIDTH container for round total to prevent any text width changes
                        Text(hasSelection && score > 0 ? "\(currentRoundScore) + \(score) = \(projectedTotal)" : "\(currentRoundScore)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .monospacedDigit() // Consistent digit width
                            .frame(width: 100, alignment: .leading) // FIXED WIDTH regardless of content
                            .lineLimit(1)
                            .minimumScaleFactor(0.8) // Scale down if needed but maintain width
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing) {
                    // FIXED WIDTH container for points - exactly 80px regardless of value
                    Text("\(hasSelection ? score : 0) pts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(hasSelection ? .blue : .secondary)
                        .monospacedDigit() // Consistent digit width
                        .frame(width: 80, alignment: .trailing) // EXACT FIXED WIDTH
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(FarkleTheme.cardBackground.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hasSelection ? FarkleTheme.diceSelected.opacity(0.3) : FarkleTheme.textSecondary.opacity(0.2), lineWidth: 1)
        )
        .frame(height: 100) // Fixed height
        .opacity(hasSelection ? 1.0 : 0.6)
    }
}

struct SuggestionsSection: View {
    let gameEngine: GameEngine
    let onSuggestionSelected: (ScoringOption) -> Void

    private var suggestions: [ScoringOption] {
        guard !gameEngine.currentRoll.isEmpty else { return [] }
        return Array(gameEngine.getPossibleScorings(for: gameEngine.currentRoll)
            .prefix(4)) // Show top 4 suggestions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggestions")
                .font(.headline)
                .fontWeight(.semibold)

            if suggestions.isEmpty {
                Text("No scoring combinations available")
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            onSelect: { onSuggestionSelected(suggestion) }
                        )
                    }
                }
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ScoringOption
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("Dice: \(suggestion.selectedDice.map(String.init).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(suggestion.score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            }

            // Acknowledge button
            Button(action: { gameEngine.acknowledgeFarkle() }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Next Player")
                        .fontWeight(.semibold)
                }
                .font(.title3)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10)
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
