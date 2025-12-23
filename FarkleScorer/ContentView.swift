import SwiftUI
import AVFoundation
import AudioToolbox

// Dynamic theme system that adapts to light/dark mode
struct FarkleTheme {
    // MARK: - Semantic Background Colors (adapt to light/dark)
    
    /// Primary background - uses system background
    static var background: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Card/surface background - uses secondary system background
    static var cardBackground: Color { Color(.secondarySystemBackground) }
    
    /// Tertiary surface for nested elements
    static var tertiaryBackground: Color { Color(.tertiarySystemBackground) }
    
    // MARK: - Text Colors (semantic)
    
    static var textPrimary: Color { .primary }
    static var textSecondary: Color { .secondary }
    
    // MARK: - Shadow (adapts to color scheme)
    
    static var shadowColor: Color { Color.black.opacity(0.1) }
    
    // MARK: - Accent Colors (consistent across modes)
    
    /// Primary action color (green for positive actions like banking)
    static var buttonPrimary: Color { Color(red: 0.2, green: 0.6, blue: 0.2) }
    static var buttonSecondary: Color { Color(red: 0.2, green: 0.6, blue: 0.2).opacity(0.8) }
    
    /// Danger/destructive actions
    static var buttonDanger: Color { Color(red: 0.85, green: 0.25, blue: 0.25) }
    static var dangerRed: Color { Color(red: 0.85, green: 0.25, blue: 0.25) }
    
    /// Undo/neutral actions
    static var buttonUndo: Color { Color(.systemGray) }
    
    /// Accent background for highlights
    static var accentBackground: Color { Color.accentColor.opacity(0.1) }
    
    // MARK: - Dice Colors
    
    /// Dice dot color - adapts to color scheme
    static var diceDots: Color { .primary }
    
    /// Selected dice highlight
    static var diceSelected: Color { Color(red: 0.0, green: 0.5, blue: 0.9) }
    
    /// Scoring dice highlight (green)
    static var diceScoring: Color { Color(red: 0.1, green: 0.7, blue: 0.1) }
    
    /// Invalid/warning dice highlight (orange)
    static var diceInvalid: Color { Color(red: 0.9, green: 0.6, blue: 0.1) }
}

struct ContentView: View {
    @StateObject private var multiplayerGameEngine = MultiplayerGameEngine()

    var gameEngine: GameEngine {
        multiplayerGameEngine.gameEngine
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Farkle-themed background
                FarkleTheme.background
                    .ignoresSafeArea()

                switch gameEngine.gameState {
                case .setup:
                    MultiplayerGameSetupView(multiplayerGameEngine: multiplayerGameEngine)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))

                case .playing, .finalRound, .gameOver:
                    ActiveGameView(gameEngine: gameEngine, multiplayerGameEngine: multiplayerGameEngine)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: gameEngine.gameState)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ActiveGameView: View {
    @ObservedObject var gameEngine: GameEngine
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @State private var showingScoreboard = false
    @State private var showingGameHistory = false
    @State private var showingRulesEditor = false
    @State private var showingSettings = false
    @State private var showingThemePicker = false

    @State private var leaderboardExpanded = false

        // Computed property for dynamic bottom offset
    private var floatingModalBottomOffset: CGFloat {
        let baseOffset: CGFloat = 35 // Closer to bottom

        // Calculate additional offset based on content
        var contentHeight: CGFloat = 70 // Base action bar height

        // Add height for round score indicator
        if let currentPlayer = gameEngine.currentPlayer, currentPlayer.roundScore > 0 {
            contentHeight += 45 // Round score height + spacing
        }

        // Adjust for different action bar states
        if gameEngine.canUndo {
            contentHeight += 25 // Extra height for undo button
        }

        return baseOffset + (contentHeight / 2)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar with current player
                TopBarView(gameEngine: gameEngine,
                          showingScoreboard: $showingScoreboard,
                          showingGameHistory: $showingGameHistory,
                          showingRulesEditor: $showingRulesEditor,
                          showingSettings: $showingSettings,
                          showingThemePicker: $showingThemePicker,
                          leaderboardExpanded: $leaderboardExpanded)

                Divider()

                // Top-positioned "need points" banner (moved from bottom)
                if let currentPlayer = gameEngine.currentPlayer,
                   gameEngine.require500Opening && currentPlayer.totalScore < gameEngine.openingScoreThreshold {
                    let pointsNeeded = gameEngine.openingScoreThreshold - currentPlayer.totalScore

                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .foregroundColor(FarkleTheme.buttonPrimary)
                            .font(.subheadline)
                        Text("Need \(pointsNeeded) points to get on the board")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(FarkleTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(FarkleTheme.accentBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                                // Main game area - reorganized with dice selection at top
                ScrollView {
                    VStack(spacing: 16) {
                        // Dice selection area at the top (priority content)
                        if gameEngine.isManualMode {
                            ManualScoringView(gameEngine: gameEngine)
                                .padding()
                                .background(FarkleTheme.cardBackground)
                                .cornerRadius(16)
                                .shadow(color: FarkleTheme.shadowColor, radius: 4, x: 0, y: 2)

                            // Manual Mode Scoreboard
                            ManualModeScoreboardView(gameEngine: gameEngine)
                                .padding()
                                .background(FarkleTheme.cardBackground)
                                .cornerRadius(16)
                                .shadow(color: FarkleTheme.shadowColor, radius: 4, x: 0, y: 2)
                        } else if !gameEngine.currentRoll.isEmpty {
                            DiceSelectionView(gameEngine: gameEngine)
                                .padding()
                                .background(FarkleTheme.cardBackground)
                                .cornerRadius(16)
                                .shadow(color: FarkleTheme.shadowColor, radius: 4, x: 0, y: 2)
                        }

                        // Streamlined turn info section removed - round score moved to floating element

                        // Bottom padding to account for floating action bar
                        Spacer().frame(height: 120)
                    }
                    .padding()
                }
            }

                        // Removed old leaderboard position - now integrated with player name

                        // Bottom floating elements - dynamically positioned based on content
            GeometryReader { geometry in
                VStack(spacing: 8) {



                    // Floating Action Bar for dice controls - dynamically positioned from bottom
                    if !gameEngine.isManualMode {
                        FloatingActionBar(gameEngine: gameEngine)
                    }
                }
                .frame(maxWidth: .infinity)
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height - floatingModalBottomOffset
                )
                        }


        }
        .sheet(isPresented: $showingScoreboard) {
            ScoreboardView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingGameHistory) {
            GameHistoryView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingRulesEditor) {
            GameRulesEditorView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingSettings) {
            GameSettingsView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerView()
        }

        .alert("Game Over!", isPresented: .constant(gameEngine.gameState == .gameOver)) {
            Button("New Game") {
                gameEngine.resetGame()
            }
            Button("View Scores") {
                showingScoreboard = true
            }
        } message: {
            if let winner = gameEngine.getPlayerRanking().first {
                Text("\(winner.name) wins with \(winner.totalScore) points!")
            }
        }
    }
}

struct TopBarView: View {
    @ObservedObject var gameEngine: GameEngine
    @Binding var showingScoreboard: Bool
    @Binding var showingGameHistory: Bool
    @Binding var showingRulesEditor: Bool
    @Binding var showingSettings: Bool
    @Binding var showingThemePicker: Bool

    @Binding var leaderboardExpanded: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Line 1: Farkle + History, Custom Scoring, Scoreboard, Ellipses
            HStack {
                Text("Farkle")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(FarkleTheme.textPrimary)

                Spacer()

                HStack(spacing: 15) {
                    Button(action: { showingGameHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundColor(FarkleTheme.textSecondary)
                    }

                    Button(action: { showingScoreboard = true }) {
                        Image(systemName: "list.number")
                            .font(.title2)
                            .foregroundColor(FarkleTheme.textSecondary)
                    }

                    Menu {
                        Button("Edit Rules") {
                            showingRulesEditor = true
                        }
                        Button("Game Settings") {
                            showingSettings = true
                        }
                        Button("Appearance") {
                            showingThemePicker = true
                        }
                        Divider()
                        Button("Skip Turn") {
                            gameEngine.skipPlayer()
                        }
                        Button("Previous Player") {
                            gameEngine.goToPreviousPlayer()
                        }
                        Button(gameEngine.gameState == .setup ? "New Game" : "End Game", role: gameEngine.gameState == .setup ? nil : .destructive) {
                            gameEngine.resetGame()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(FarkleTheme.textSecondary)
                    }
                }
            }

            // Line 2: Player's Turn + Playing Status
            HStack {
                if let currentPlayer = gameEngine.currentPlayer {
                    Text("\(currentPlayer.name)'s Turn")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(FarkleTheme.buttonPrimary)
                } else {
                    Text("Game Setup")
                        .font(.title3)
                        .foregroundColor(FarkleTheme.textSecondary)
                }

                Spacer()

                GameStateIndicator(gameState: gameEngine.gameState)
            }

            // Line 3: Leaderboard + Manual/Digital Toggle
            HStack {
                if gameEngine.gameState == .playing || gameEngine.gameState == .finalRound {
                    TopRightLeaderboardView(gameEngine: gameEngine, isExpanded: $leaderboardExpanded)
                } else {
                    Spacer()
                }

                Spacer()

                if gameEngine.gameState == .playing || gameEngine.gameState == .finalRound {
                    Button(action: {
                        gameEngine.toggleManualMode()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: gameEngine.isManualMode ? "gamecontroller.fill" : "die.face.6.fill")
                                .font(.caption)
                            Text(gameEngine.isManualMode ? "Digital" : "Calculator")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(FarkleTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FarkleTheme.accentBackground)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
    }
}

struct GameStateIndicator: View {
    let gameState: GameEngine.GameState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            Text(stateText)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: true, vertical: false) // Prevent line breaks
        }
    }

    private var indicatorColor: Color {
        switch gameState {
        case .setup:
            return .gray
        case .playing:
            return .green
        case .finalRound:
            return .orange
        case .gameOver:
            return .red
        }
    }

    private var stateText: String {
        switch gameState {
        case .setup:
            return "Setup"
        case .playing:
            return "Playing"
        case .finalRound:
            return "Final Round"
        case .gameOver:
            return "Game Over"
        }
    }
}

// Floating scoreboard component (positioned at bottom)
struct FloatingScoreboardView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isExpanded = false

    var body: some View {
        // Floating scoreboard container
        VStack(spacing: 8) {
            if isExpanded {
                // Expanded view - show all players
                ExpandedScoreboardContent(gameEngine: gameEngine)
            } else {
                // Collapsed view - show only top player
                CollapsedScoreboardContent(gameEngine: gameEngine)
            }
        }
        .padding(12)
        .background(FarkleTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: FarkleTheme.shadowColor, radius: 8, x: 0, y: -2)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
}

// Floating action bar for dice controls
struct FloatingActionBar: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var showingSkipConfirmation = false

    var body: some View {
        VStack(spacing: 8) {
            // Undo button (appears above main actions when available)
            if gameEngine.canUndo {
                Button(action: { gameEngine.undoLastSelection() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                        Text("Undo Last Selection")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(FarkleTheme.buttonUndo)
                    .cornerRadius(20)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Main action section
            if gameEngine.currentRoll.isEmpty {
                // Roll dice button
                Button(action: { rollDice() }) {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(gameEngine.remainingDice)×")
                                .font(.title3)
                                .fontWeight(.bold)
                            Image(systemName: "die.face.6")
                                .font(.title2)
                        }
                        Text("Roll Dice")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                                            .background(canRoll ? FarkleTheme.buttonSecondary : FarkleTheme.textSecondary.opacity(0.3))
                    .cornerRadius(25)
                }
                .disabled(!canRoll)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                // Dice selection actions
                VStack(spacing: 16) { // Increased spacing between button rows
                    // Top row: Skip Turn and Bank Score
                    HStack(spacing: 12) {
                        Button("Skip Turn") {
                            showingSkipConfirmation = true
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(FarkleTheme.dangerRed)
                        .cornerRadius(20)

                        Button("Bank Score") {
                            gameEngine.bankScore()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(canBankScore ? FarkleTheme.diceSelected : FarkleTheme.textSecondary.opacity(0.3))
                        .cornerRadius(20)
                        .disabled(!canBankScore)
                    }

                    // Bottom row: Keep Rolling (main action) with re-roll icon
                    Button(action: { gameEngine.continueRolling() }) {
                        HStack(spacing: 8) {
                            if gameEngine.remainingDice > 0 {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            Text("Keep Rolling")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(canContinueRolling ? FarkleTheme.buttonSecondary : FarkleTheme.textSecondary.opacity(0.3))
                        .cornerRadius(25)
                        .overlay(
                            // Subtle glow when all dice will be selected (hot dice situation)
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.orange, lineWidth: shouldGlowKeepRolling ? 2 : 0)
                                .shadow(color: .orange, radius: shouldGlowKeepRolling ? 8 : 0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: shouldGlowKeepRolling)
                        )
                    }
                    .disabled(!canContinueRolling)
                }
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(16)
        .background(FarkleTheme.cardBackground) // Fully opaque background
        .cornerRadius(20)
        .shadow(color: FarkleTheme.shadowColor, radius: 8, x: 0, y: -2)
        .alert("Skip Turn?", isPresented: $showingSkipConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Skip Turn", role: .destructive) {
                gameEngine.skipTurn()
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        } message: {
            Text("This will end your turn without banking any points. Are you sure?")
        }
    }

        private var canRoll: Bool {
        gameEngine.currentRoll.isEmpty && (gameEngine.gameState == .playing || gameEngine.gameState == .finalRound)
    }

    private var canBankScore: Bool {
        !gameEngine.selectedDice.isEmpty && gameEngine.canPlayerBank()
    }

    private var canContinueRolling: Bool {
        gameEngine.canPlayerContinueRolling()
    }

    private var shouldGlowKeepRolling: Bool {
        // Glow when all current dice will be selected (next roll will be 6 dice)
        let selectedCount = gameEngine.selectedDice.count
        let currentRollCount = gameEngine.currentRoll.count
        return selectedCount == currentRollCount && selectedCount > 0
    }

        private func rollDice() {
        // Play dice rolling sound effect
        SoundManager.shared.playDiceRoll()

        let _ = withAnimation(.easeInOut(duration: 0.3)) {
            gameEngine.rollDice()
        }

        // Add haptic feedback (SoundManager already includes this, but keeping for redundancy)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct CollapsedScoreboardContent: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isExpanded = false

    var body: some View {
        if isExpanded {
            // Expanded view - show top 3 players with progress toward winning
            VStack(alignment: .trailing, spacing: 8) {
                // Header with collapse caret and race text
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundColor(FarkleTheme.textSecondary)
                    }

                    Spacer()

                    Text("Race to \(gameEngine.winningScore)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(FarkleTheme.textSecondary)
                }

                ForEach(Array(gameEngine.getPlayerRanking().prefix(3).enumerated()), id: \.element.id) { index, player in
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption2)
                                .foregroundColor(FarkleTheme.textSecondary)

                            Text(player.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(FarkleTheme.textPrimary)

                            Text("\(player.totalScore)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(FarkleTheme.buttonPrimary)
                        }

                        // Progress bar toward winning
                        let progress = Double(player.totalScore) / Double(gameEngine.winningScore)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(FarkleTheme.textSecondary.opacity(0.2))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(index == 0 ? FarkleTheme.buttonPrimary : FarkleTheme.buttonSecondary)
                                    .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                            .cornerRadius(2)
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(index == 0 ? FarkleTheme.accentBackground : Color.clear)
                    .cornerRadius(6)
                }
            }
        } else {
            // Collapsed view - show only leader
            if let leader = gameEngine.getPlayerRanking().first {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundColor(FarkleTheme.buttonPrimary)

                    Text(leader.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(FarkleTheme.textPrimary)

                    Text("\(leader.totalScore)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(FarkleTheme.buttonPrimary)
                }
            }
        }
    }
}

struct ExpandedScoreboardContent: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Leaderboard")
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            // Players list
            let rankings = gameEngine.getPlayerRanking()
            ForEach(Array(rankings.enumerated()), id: \.offset) { index, player in
                HStack(spacing: 8) {
                    // Rank
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor(for: index + 1))
                        .frame(width: 16)

                    // Player name
                    Text(player.name)
                        .font(.caption)
                        .fontWeight(gameEngine.currentPlayer?.id == player.id ? .bold : .regular)
                        .lineLimit(1)

                    Spacer()

                    // Score
                    Text("\(player.totalScore)")
                        .font(.caption)
                        .fontWeight(.medium)

                    // Current player indicator
                    if gameEngine.currentPlayer?.id == player.id {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(FarkleTheme.buttonPrimary)
                                .font(.caption)
                            Text("Turn")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(FarkleTheme.buttonPrimary)
                        }
                    }
                }
                .padding(.vertical, 2)

                if index < rankings.count - 1 {
                    Divider()
                        .opacity(0.3)
                }
            }
        }
        .frame(maxWidth: 160)
    }

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}



// Game settings view moved from ScoreboardView
struct GameSettingsView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Players section - manage players during game
                Section {
                    NavigationLink(destination: PlayerManagementView(gameEngine: gameEngine, canEdit: true)) {
                        HStack {
                            Text("Manage Players")
                            Spacer()
                            Text("\(gameEngine.players.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Players")
                } footer: {
                    Text("Add, remove, rename, or reorder players")
                }
                
                Section("Current Game Rules") {
                    SettingRow("Winning Score", "\(gameEngine.winningScore)")
                    SettingRow("Opening Score Required", gameEngine.require500Opening ? "Yes (\(gameEngine.openingScoreThreshold))" : "No")
                    SettingRow("Triple Farkle Penalty", gameEngine.enableTripleFarkleRule ? "Yes (\(gameEngine.tripleFarklePenalty))" : "No")
                }

                Section("Game State") {
                    SettingRow("Current State", gameStateText)
                    SettingRow("Players", "\(gameEngine.players.count)")
                    SettingRow("Current Player", gameEngine.currentPlayer?.name ?? "None")
                }

                Section("Actions") {
                    Button(gameEngine.gameState == .setup ? "New Game" : "End Game", role: gameEngine.gameState == .setup ? nil : .destructive) {
                        gameEngine.resetGame()
                    }
                }
            }
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var gameStateText: String {
        switch gameEngine.gameState {
        case .setup: return "Setup"
        case .playing: return "Playing"
        case .finalRound: return "Final Round"
        case .gameOver: return "Game Over"
        }
    }
}

struct SettingRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
    }
}

// Old QuickScoreboardView removed - replaced with FloatingScoreboardView

struct GameHistoryView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(gameEngine.players) { player in
                        PlayerHistoryCard(player: player)
                    }
                }
                .padding()
            }
            .navigationTitle("Game History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct PlayerHistoryCard: View {
    let player: Player

    private var averageRoundScore: String {
        guard !player.gameHistory.isEmpty else { return "0" }
        // Calculate average based on successful scoring turns (non-farkles)
        let scoringTurns = player.gameHistory.filter { !$0.isFarkle && $0.score > 0 }
        guard !scoringTurns.isEmpty else { return "0" }
        let totalScore = scoringTurns.map(\.score).reduce(0, +)
        let averageScore = Double(totalScore) / Double(scoringTurns.count)
        return "\(Int(averageScore))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(player.name)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(player.totalScore) pts")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            HStack {
                StatView(title: "Rounds", value: "\(player.gameHistory.count)")
                StatView(title: "Farkles", value: "\(player.consecutiveFarkles)")
                StatView(title: "Avg/Round", value: averageRoundScore)
            }

            if !player.gameHistory.isEmpty {
                Text("Recent Rounds:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                    ForEach(Array(player.gameHistory.suffix(10).enumerated()), id: \.offset) { _, turn in
                        Text("\(turn.score)")
                            .font(.caption)
                            .padding(4)
                            .background(FarkleTheme.accentBackground)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(FarkleTheme.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GameRulesEditorView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss

    // Computed property to determine if winning score can be changed
    private var canChangeWinningScore: Bool {
        let maxPlayerScore = gameEngine.players.map { $0.totalScore }.max() ?? 0
        return gameEngine.winningScore > maxPlayerScore
    }

    // Available winning score options that are higher than the max player score
    private var availableWinningScores: [Int] {
        let maxPlayerScore = gameEngine.players.map { $0.totalScore }.max() ?? 0
        let allOptions = [5000, 10000, 15000, 20000]
        return allOptions.filter { $0 > maxPlayerScore }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("⚙️ Edit Game Rules")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Modify rules during gameplay")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    VStack(spacing: 20) {
                        // Winning Score (conditional editing)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Winning Score:")
                                .fontWeight(.medium)

                            if canChangeWinningScore {
                                Picker("Winning Score", selection: $gameEngine.winningScore) {
                                    ForEach(availableWinningScores, id: \.self) { score in
                                        Text("\(score.formatted()) points").tag(score)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack {
                                    Text("\(gameEngine.winningScore.formatted()) points")
                                        .padding()
                                        .background(FarkleTheme.accentBackground)
                                        .cornerRadius(8)

                                    Spacer()
                                }

                                Text("Cannot change winning score when players are close to winning")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }

                        Divider()

                        // Opening Score Requirement (always editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Require Opening Score", isOn: $gameEngine.require500Opening)
                                .fontWeight(.medium)

                            if gameEngine.require500Opening {
                                HStack {
                                    Text("Opening Score Threshold:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Picker("Opening Score", selection: $gameEngine.openingScoreThreshold) {
                                        Text("350").tag(350)
                                        Text("500").tag(500)
                                        Text("750").tag(750)
                                        Text("1,000").tag(1000)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.leading, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Divider()

                        // Triple Farkle Rule (always editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Triple Farkle Penalty", isOn: $gameEngine.enableTripleFarkleRule)
                                .fontWeight(.medium)

                            if gameEngine.enableTripleFarkleRule {
                                HStack {
                                    Text("Penalty Amount:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Picker("Penalty", selection: $gameEngine.tripleFarklePenalty) {
                                        Text("500").tag(500)
                                        Text("1,000").tag(1000)
                                        Text("1,500").tag(1500)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.leading, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        // Info section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(FarkleTheme.buttonPrimary)
                                Text("Rule Change Policy")
                                    .fontWeight(.medium)
                            }

                            Text("• Opening score and triple farkle rules can be changed at any time")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("• Winning score can only be increased above current player scores")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(FarkleTheme.accentBackground)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(FarkleTheme.cardBackground.opacity(0.8))
                    .cornerRadius(15)
                    .shadow(radius: 2)
                }
                .padding()
            }
            .navigationTitle("Game Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// Theme picker for light/dark mode
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var appTheme: String = "System"

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Appearance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()

                VStack(spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button(action: {
                            appTheme = theme.rawValue
                        }) {
                            HStack {
                                Image(systemName: theme.icon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(theme.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(themeDescription(theme))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if appTheme == theme.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func themeDescription(_ theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "Follow your device settings"
        case .light:
            return "Always use light appearance"
        case .dark:
            return "Always use dark appearance"
        }
    }
}

// Top-right compact leaderboard
struct TopRightLeaderboardView: View {
    @ObservedObject var gameEngine: GameEngine
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                // Expanded view - show top 3 players with progress toward winning
                VStack(alignment: .trailing, spacing: 8) {
                    // Header with collapse caret and race text
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .foregroundColor(FarkleTheme.textSecondary)
                        }

                        Spacer()

                        Text("Race to \(gameEngine.winningScore)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(FarkleTheme.textSecondary)
                    }

                    ForEach(Array(gameEngine.getPlayerRanking().prefix(3).enumerated()), id: \.element.id) { index, player in
                        VStack(spacing: 2) {
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption2)
                                    .foregroundColor(FarkleTheme.textSecondary)

                                Text(player.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(FarkleTheme.textPrimary)

                                Text("\(player.totalScore)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(FarkleTheme.buttonPrimary)
                            }

                            // Progress bar toward winning
                            let progress = Double(player.totalScore) / Double(gameEngine.winningScore)
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(FarkleTheme.textSecondary.opacity(0.2))
                                        .frame(height: 4)

                                    Rectangle()
                                        .fill(index == 0 ? FarkleTheme.buttonPrimary : FarkleTheme.buttonSecondary)
                                        .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: 4)
                                        .animation(.easeInOut(duration: 0.3), value: progress)
                                }
                                .cornerRadius(2)
                            }
                            .frame(height: 4)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(index == 0 ? FarkleTheme.accentBackground : Color.clear)
                        .cornerRadius(6)
                    }
                }
            } else {
                // Collapsed view - show only leader
                if let leader = gameEngine.getPlayerRanking().first {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(FarkleTheme.buttonPrimary)

                        Text(leader.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(FarkleTheme.textPrimary)

                        Text("\(leader.totalScore)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(FarkleTheme.buttonPrimary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FarkleTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: FarkleTheme.shadowColor, radius: 3, x: 0, y: 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
}

// Manual Mode Scoreboard View
struct ManualModeScoreboardView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isEditing = false
    @State private var editingPlayerName: String = ""
    @State private var editingPlayerID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(FarkleTheme.buttonPrimary)
                    .font(.title3)
                Text("Scoreboard")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(FarkleTheme.textPrimary)
                Spacer()

                // Edit mode toggle button (removed clear button for in-game)
                HStack(spacing: 8) {
                    // Edit/Done button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditing.toggle()
                        }
                        if !isEditing {
                            // Save any in-progress edits when exiting edit mode
                            if let editingID = editingPlayerID {
                                updatePlayerName(editingID, newName: editingPlayerName)
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isEditing ? "checkmark" : "pencil")
                            Text(isEditing ? "Done" : "Edit")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isEditing ? FarkleTheme.buttonSecondary : FarkleTheme.buttonPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((isEditing ? FarkleTheme.buttonSecondary : FarkleTheme.buttonPrimary).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            let rankings = gameEngine.getPlayerRanking()
            ForEach(Array(rankings.enumerated()), id: \.element.id) { index, player in
                HStack(spacing: 12) {
                    // Rank indicator or drag handle
                    if isEditing {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(FarkleTheme.textSecondary)
                            .font(.title2)
                            .frame(width: 30, alignment: .center)
                    } else {
                        Text("\(index + 1)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor(for: index + 1))
                            .frame(width: 30, alignment: .center)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        // Editable player name
                        if isEditing && editingPlayerID == player.id {
                            TextField("Player Name", text: $editingPlayerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.headline)
                                .onSubmit {
                                    updatePlayerName(player.id, newName: editingPlayerName)
                                }
                        } else {
                            HStack {
                                Text(player.name)
                                    .font(.headline)
                                    .fontWeight(gameEngine.currentPlayer?.id == player.id ? .bold : .semibold)
                                    .foregroundColor(gameEngine.currentPlayer?.id == player.id ? FarkleTheme.buttonPrimary : FarkleTheme.textPrimary)

                                if isEditing {
                                    Button(action: {
                                        editingPlayerID = player.id
                                        editingPlayerName = player.name
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(FarkleTheme.buttonPrimary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Text("Total: \(player.totalScore)")
                                .font(.subheadline)
                                .foregroundColor(FarkleTheme.textSecondary)

                            if player.roundScore > 0 {
                                Text("Round: +\(player.roundScore)")
                                    .font(.subheadline)
                                    .foregroundColor(FarkleTheme.buttonSecondary)
                            }
                        }
                    }

                    Spacer()

                    // Current player indicator
                    if !isEditing && gameEngine.currentPlayer?.id == player.id {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(FarkleTheme.buttonPrimary)
                                .font(.caption)
                            Text("Turn")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(FarkleTheme.buttonPrimary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    gameEngine.currentPlayer?.id == player.id ?
                    FarkleTheme.accentBackground :
                    Color.clear
                )
                .cornerRadius(10)

                if index < rankings.count - 1 {
                    Divider()
                        .opacity(0.3)
                }
            }
            .onMove(perform: isEditing ? movePlayer : nil)
        }
    }

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return FarkleTheme.textSecondary
        }
    }

    private func movePlayer(from source: IndexSet, to destination: Int) {
        gameEngine.reorderPlayers(from: source, to: destination)
    }

    private func updatePlayerName(_ playerID: UUID, newName: String) {
        if let playerIndex = gameEngine.players.firstIndex(where: { $0.id == playerID }) {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                gameEngine.players[playerIndex].name = trimmedName
            }
        }
        editingPlayerID = nil
        editingPlayerName = ""
    }
}

#Preview {
    ContentView()
}
