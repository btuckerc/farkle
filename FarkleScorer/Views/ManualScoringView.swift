import SwiftUI

struct ManualScoringView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var inputScore = ""
    @FocusState private var isInputFocused: Bool
    @State private var isEditMode = false
    @State private var editingPlayerID: UUID? = nil
    @State private var editingPlayerName = ""
    @State private var newPlayerName = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Physical Dice Tracker")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Manually track scores from physical dice")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Current Player Display
                    if let currentPlayer = gameEngine.currentPlayer {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Current Turn")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(currentPlayer.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )

            // Score Input Section
            VStack(spacing: 12) {
                HStack {
                    TextField("Enter score", text: $inputScore)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isInputFocused)
                        .onSubmit {
                            addScore()
                        }

                    Button("Add") {
                        addScore()
                    }
                    .disabled(inputScore.isEmpty || Int(inputScore) == nil || Int(inputScore)! <= 0)
                    .buttonStyle(.borderedProminent)
                }

                // Quick Score Buttons
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach([50, 100, 150, 200, 250, 300, 400, 500], id: \.self) { score in
                        Button("\(score)") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                gameEngine.addManualScore(score)
                            }
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }

            // Current Score Display
            ScoreDisplayCard(gameEngine: gameEngine)

            // Score History
            if !gameEngine.manualScoreHistory.isEmpty {
                ScoreHistorySection(gameEngine: gameEngine)
                    .transition(.opacity.combined(with: .scale))
            }

            // Action Buttons
            ManualActionButtonsSection(gameEngine: gameEngine)

            Spacer()
        }
        .padding()
        .animation(.easeInOut(duration: 0.3), value: gameEngine.manualScoreHistory.count)
        .onTapGesture {
            isInputFocused = false
        }
    }

    private func addScore() {
        guard let score = Int(inputScore), score > 0 else { return }
        gameEngine.addManualScore(score)
        inputScore = ""
        isInputFocused = false
    }


}

struct ScoreDisplayCard: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Turn Total:")
                    .font(.subheadline)
                    .foregroundColor(FarkleTheme.textSecondary)

                Spacer()

                Text("\(gameEngine.manualTurnScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(FarkleTheme.buttonPrimary)
            }

            if let player = gameEngine.currentPlayer {
                HStack {
                    Text("Round Total:")
                        .font(.subheadline)
                        .foregroundColor(FarkleTheme.textSecondary)

                    Spacer()

                    Text("\(player.roundScore + gameEngine.manualTurnScore)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(FarkleTheme.buttonSecondary)
                }
            }
        }
        .padding()
        .background(FarkleTheme.accentBackground)
        .cornerRadius(10)
    }
}

struct ScoreHistorySection: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Score History")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button("Clear All") {
                    clearAllScores()
                }
                .font(.caption)
                .foregroundColor(FarkleTheme.dangerRed)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                ForEach(Array(gameEngine.manualScoreHistory.enumerated()), id: \.offset) { index, score in
                    Button(action: {
                        removeScore(at: index)
                    }) {
                        Text("\(score)")
                            .font(.caption)
                            .padding(6)
                            .background(FarkleTheme.buttonSecondary.opacity(0.1))
                            .foregroundColor(FarkleTheme.buttonSecondary)
                            .cornerRadius(4)
                    }
                }
            }

            if !gameEngine.manualScoreHistory.isEmpty {
                Text("Tap a score to remove it")
                    .font(.caption2)
                    .foregroundColor(FarkleTheme.textSecondary)
                    .italic()
            }
        }
        .padding()
        .background(FarkleTheme.cardBackground.opacity(0.5))
        .cornerRadius(10)
    }

    private func removeScore(at index: Int) {
        // Remove the specific score from the history
        let removedScore = gameEngine.manualScoreHistory[index]
        gameEngine.manualScoreHistory.remove(at: index)
        gameEngine.manualTurnScore -= removedScore
    }

    private func clearAllScores() {
        gameEngine.manualScoreHistory.removeAll()
        gameEngine.manualTurnScore = 0
    }
}

struct ManualActionButtonsSection: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        HStack(spacing: 12) {
            // Skip Turn Button (moved to first position)
            Button(action: { gameEngine.skipPlayer() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Skip Turn")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(FarkleTheme.buttonUndo)
                .cornerRadius(8)
            }

            // Farkle Button
            Button(action: { gameEngine.farkleManualTurn() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Farkle")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(FarkleTheme.dangerRed)
                .cornerRadius(8)
            }

            // Bank Score Button (moved to last position)
            Button(action: {
                if gameEngine.canPlayerBank() {
                    gameEngine.bankManualScore()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Bank\nScore")
                        .multilineTextAlignment(.center)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    gameEngine.canPlayerBank() ? FarkleTheme.buttonSecondary : FarkleTheme.textSecondary.opacity(0.3)
                )
                .cornerRadius(8)
            }
            .disabled(!gameEngine.canPlayerBank())
            .onTapGesture {
                // Show feedback when disabled due to 500-point requirement
                if gameEngine.manualTurnScore > 0 && !gameEngine.canPlayerBank() {
                    // This will trigger the existing "need points" banner
                    // The validation logic is already handled by canPlayerBank()
                }
            }
        }
    }
}

#Preview {
    ManualScoringView(gameEngine: {
        let engine = GameEngine()
        engine.addPlayer(name: "Test Player")
        engine.startGame()
        engine.toggleManualMode()
        return engine
    }())
}
