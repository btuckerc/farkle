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
            // Preserved digital roll banner
            if gameEngine.hasDigitalTurnInProgress {
                HStack(spacing: 6) {
                    Image(systemName: "die.face.6")
                        .font(.caption)
                    Text("Digital roll paused — banking here will bank Calculator points")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
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
    @AppStorage("requireHoldToConfirm") private var requireHoldToConfirm: Bool = true
    @State private var activeConfirmation: ActiveConfirmation? = nil
    
    private var canBank: Bool {
        gameEngine.canPlayerBank()
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top row: Skip and Farkle
            HStack(spacing: 12) {
                if requireHoldToConfirm {
                    // Hold-to-confirm mode (default)
                    CompactHoldButton(
                        title: "Skip",
                        icon: "forward.fill",
                        holdDuration: 0.5,
                        backgroundColor: FarkleTheme.buttonUndo,
                        action: {
                            gameEngine.skipPlayer()
                        }
                    )
                    
                    CompactHoldButton(
                        title: "Farkle",
                        icon: "xmark.circle.fill",
                        holdDuration: 0.5,
                        backgroundColor: FarkleTheme.dangerRed,
                        action: {
                            gameEngine.farkleManualTurn()
                        }
                    )
                } else {
                    // Tap-to-confirm mode (accessibility friendly)
                    Button(action: {
                        HapticFeedback.light()
                        activeConfirmation = .skipTurn
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Skip")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(FarkleTheme.buttonUndo)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        HapticFeedback.light()
                        activeConfirmation = .farkleManual
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Farkle")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(FarkleTheme.dangerRed)
                        .cornerRadius(10)
                    }
                }
            }
            
            // Bottom row: Bank Score
            if requireHoldToConfirm {
                HoldToConfirmButton(
                    holdDuration: 0.6,
                    backgroundColor: canBank ? FarkleTheme.buttonPrimary : FarkleTheme.textSecondary.opacity(0.3),
                    isEnabled: canBank,
                    action: {
                        gameEngine.bankManualScore()
                    }
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        VStack(spacing: 2) {
                            Text("Bank Score")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            if canBank {
                                Text("Hold to confirm")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .opacity(0.7)
                            } else if gameEngine.manualTurnScore > 0 {
                                Text("Need more points to get on board")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .opacity(0.7)
                            }
                        }
                    }
                }
            } else {
                Button(action: {
                    HapticFeedback.light()
                    activeConfirmation = .bankScore
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Bank Score")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canBank ? FarkleTheme.buttonPrimary : FarkleTheme.textSecondary.opacity(0.3))
                    .cornerRadius(12)
                }
                .disabled(!canBank)
            }
        }
        .fullScreenCover(item: $activeConfirmation) { confirmation in
            ConfirmationOverlay(
                title: confirmation.title,
                message: confirmation.message,
                primaryActionTitle: confirmation.primaryActionTitle,
                primaryActionRole: confirmation.isDestructive ? .destructive : nil,
                onPrimary: {
                    performConfirmation(confirmation)
                },
                onDismiss: {
                    activeConfirmation = nil
                }
            )
            .background(ClearBackgroundView())
        }
    }
    
    private func performConfirmation(_ confirmation: ActiveConfirmation) {
        switch confirmation {
        case .skipTurn:
            gameEngine.skipPlayer()
        case .bankScore:
            gameEngine.bankManualScore()
        case .farkleManual:
            gameEngine.farkleManualTurn()
        default:
            break
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
