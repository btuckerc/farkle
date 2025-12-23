import SwiftUI
import AVFoundation

struct TurnManagementView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isRolling = false

    var body: some View {
        VStack(spacing: 16) {
            // Current Player Header
            CurrentPlayerHeader(gameEngine: gameEngine)

            // Dice Count and Roll Button
            RollSection(gameEngine: gameEngine, isRolling: $isRolling)

            // Game Status and Warnings
            GameStatusSection(gameEngine: gameEngine)

            // Status message spacing and undo button area
            VStack(spacing: 8) {
                // Consistent spacing whether status messages are visible or not
                Spacer().frame(height: 8)

                // Undo button (show when user can undo last selection)
                if gameEngine.canUndo && !gameEngine.isManualMode {
                    Button(action: { gameEngine.undoLastSelection() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo Last Selection")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: gameEngine.canUndo)
                }
            }
        }
    }
}

struct CurrentPlayerHeader: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 8) {
            if let currentPlayer = gameEngine.currentPlayer {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentPlayer.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)

                        Text("Current Turn")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(currentPlayer.displayScore)")
                            .font(.title2)
                            .fontWeight(.bold)

                        if currentPlayer.roundScore > 0 {
                            Text("+\(currentPlayer.roundScore) this round")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                // Player Status Indicators
                PlayerStatusIndicators(player: currentPlayer, gameEngine: gameEngine)
            }
        }
    }
}

struct PlayerStatusIndicators: View {
    let player: Player
    let gameEngine: GameEngine

    var body: some View {
        HStack(spacing: 12) {
            // On Board Status - only show if they're on board (remove redundant "Need 500")
            if gameEngine.require500Opening && player.isOnBoard {
                StatusBadge(
                    text: "On Board",
                    color: .green,
                    icon: "checkmark.circle"
                )
            }

            // Farkle Warning
            if player.consecutiveFarkles > 0 {
                StatusBadge(
                    text: "\(player.consecutiveFarkles) Farkle\(player.consecutiveFarkles > 1 ? "s" : "")",
                    color: player.consecutiveFarkles >= 2 ? .red : .orange,
                    icon: "exclamationmark.triangle"
                )
            }

            Spacer()
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

struct RollSection: View {
    @ObservedObject var gameEngine: GameEngine
    @Binding var isRolling: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Hot dice indicator (keep this special moment)
            if !gameEngine.isManualMode && gameEngine.remainingDice == 6 {
                if gameEngine.currentPlayer?.gameHistory.last?.selectedDice.count == 6 {
                    HStack {
                        Spacer()
                        Text("🔥 Hot Dice!")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        Spacer()
                    }
                }
            }

            // Current round score (more important info)
            if let currentPlayer = gameEngine.currentPlayer, currentPlayer.roundScore > 0 {
                HStack {
                    Text("Round Score: \(currentPlayer.roundScore)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)

                    Spacer()

                    Text("Select scoring dice below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private var diceText: String {
        gameEngine.remainingDice == 1 ? "Die" : "Dice"
    }

    private var canRoll: Bool {
        gameEngine.currentRoll.isEmpty && gameEngine.gameState == .playing || gameEngine.gameState == .finalRound
    }

    private func rollDice() {
        guard canRoll else { return }

        // Play dice rolling sound effect
        SoundManager.shared.playDiceRoll()

        isRolling = true

        // Add some visual delay to simulate rolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let _ = gameEngine.rollDice()
            isRolling = false
        }
    }
}

struct GameStatusSection: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 8) {
            // Game state specific messages
            switch gameEngine.gameState {
            case .finalRound:
                FinalRoundIndicator(gameEngine: gameEngine)

            case .gameOver:
                GameOverIndicator(gameEngine: gameEngine)

            default:
                if let currentPlayer = gameEngine.currentPlayer {
                    TurnStatusMessages(player: currentPlayer, gameEngine: gameEngine)
                }
            }
        }
    }
}

struct FinalRoundIndicator: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.orange)

                Text("Final Round")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Spacer()
            }

            if gameEngine.isFinalRoundActive {
                HStack {
                    Text(gameEngine.finalRoundDescription)
                        .font(.subheadline)
                        .foregroundColor(.orange)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GameOverIndicator: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.gold)

                Text("Game Over!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.gold)

                Spacer()
            }

            if let winner = gameEngine.getPlayerRanking().first {
                HStack {
                    Text("\(winner.name) wins with \(winner.totalScore) points!")
                        .fontWeight(.medium)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
}

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

struct TurnStatusMessages: View {
    let player: Player
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Opening score requirement message
            if gameEngine.require500Opening && !player.isOnBoard {
                StatusMessage(
                    text: "Need \(gameEngine.openingScoreThreshold - player.roundScore) more points to get on the board",
                    color: .orange,
                    icon: "target"
                )
            }

            // Triple farkle warning
            if player.consecutiveFarkles == 2 && gameEngine.enableTripleFarkleRule {
                StatusMessage(
                    text: "Warning: One more farkle = \(gameEngine.tripleFarklePenalty) point penalty!",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
            }

            // Winning proximity
            if player.totalScore >= gameEngine.winningScore * 8 / 10 {
                let needed = gameEngine.winningScore - player.totalScore
                if needed > 0 {
                    StatusMessage(
                        text: "Just \(needed) points away from winning!",
                        color: .green,
                        icon: "flag.fill"
                    )
                }
            }
        }
    }
}

struct StatusMessage: View {
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 12) // Fixed icon width

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true) // Prevent horizontal expansion
                .lineLimit(2) // Allow wrapping but limit lines

            Spacer(minLength: 0) // Flexible spacer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    TurnManagementView(gameEngine: {
        let engine = GameEngine()
        engine.addPlayer(name: "Test Player")
        engine.startGame()
        return engine
    }())
}

// MARK: - Sound Manager
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    func playDiceRoll() {
        // Create a realistic dice rolling sound with multiple rapid clicks
        playDiceRollingSequence()

        // Add haptic feedback for better user experience
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

        private func playDiceRollingSequence() {
        // Dice hitting table/cup sounds - rapid succession like real dice
        let diceSounds: [SystemSoundID] = [
            1306, // Pop
            1104, // Click
            1105, // Click variation
            1123, // Tock
            1104, // Click
            1105, // Click variation
        ]

        // Initial splash - dice hitting table rapidly
        for (index, soundID) in diceSounds.enumerated() {
            let delay = Double(index) * 0.06 // 60ms between sounds - rapid succession
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AudioServicesPlaySystemSound(SystemSoundID(soundID))
            }
        }

        // Quick settling - a few more rapid clicks as dice settle
        let settlingStartTime = Double(diceSounds.count) * 0.06
        let settlingSounds = [1104, 1105, 1123]

        for i in 0..<4 {
            let randomSound = settlingSounds.randomElement() ?? 1104
            // Faster settling with slight randomization
            let delay = settlingStartTime + (0.08 * Double(i)) + Double.random(in: 0...0.03)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AudioServicesPlaySystemSound(SystemSoundID(randomSound))
            }
        }

        // Final click as dice come to rest - much shorter total duration
        DispatchQueue.main.asyncAfter(deadline: .now() + settlingStartTime + 0.4) {
            AudioServicesPlaySystemSound(SystemSoundID(1104)) // Final click
        }
    }

    private func playCustomSound(named soundName: String) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") ??
                       Bundle.main.url(forResource: soundName, withExtension: "wav") else {
            print("Sound file \(soundName) not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.5 // Adjust volume as needed
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error)")
        }
    }
}
