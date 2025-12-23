import SwiftUI
import AVFoundation
import AudioToolbox

// Dynamic theme system that adapts to light/dark mode and user-selected theme
struct FarkleTheme {
    // MARK: - Current Theme Helper
    
    /// Returns the currently selected theme from UserDefaults
    private static var currentTheme: AppTheme {
        let rawValue = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        return AppTheme(rawValue: rawValue) ?? .system
    }
    
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
    
    // MARK: - Theme-Aware Accent Colors
    
    /// Primary action color (green for positive actions like banking) - theme-aware
    static var buttonPrimary: Color { currentTheme.buttonPrimary }
    static var buttonSecondary: Color { currentTheme.buttonSecondary }
    
    /// Danger/destructive actions - theme-aware
    static var buttonDanger: Color { currentTheme.buttonDanger }
    static var dangerRed: Color { currentTheme.buttonDanger }
    
    /// Undo/neutral actions
    static var buttonUndo: Color { Color(.systemGray) }
    
    /// Accent background for highlights - theme-aware
    static var accentBackground: Color { currentTheme.accentColor.opacity(0.1) }
    
    // MARK: - Theme-Aware Dice Colors
    
    /// Dice dot color - adapts to color scheme
    static var diceDots: Color { .primary }
    
    /// Selected dice highlight - theme-aware
    static var diceSelected: Color { currentTheme.diceSelected }
    
    /// Scoring dice highlight - theme-aware
    static var diceScoring: Color { currentTheme.diceScoring }
    
    /// Invalid/warning dice highlight - theme-aware
    static var diceInvalid: Color { currentTheme.diceInvalid }
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
                    // Route to multiplayer view if in multiplayer mode with simultaneous rounds
                    if multiplayerGameEngine.isMultiplayerMode {
                        MultiplayerRoundPlayView(multiplayerEngine: multiplayerGameEngine)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    } else {
                        ActiveGameView(gameEngine: gameEngine, multiplayerGameEngine: multiplayerGameEngine)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: gameEngine.gameState)
            .animation(.easeInOut(duration: 0.3), value: multiplayerGameEngine.isMultiplayerMode)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ActiveGameView: View {
    @ObservedObject var gameEngine: GameEngine
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @State private var showingScoreboard = false
    @State private var showingGameHistory = false
    @State private var showingSettings = false
    @State private var activeConfirmation: ActiveConfirmation? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Player Strip at top - Flip7-style grid showing all players
                PlayerStrip(
                    players: gameEngine.players,
                    currentPlayerIndex: gameEngine.currentPlayerIndex,
                    winningScore: gameEngine.winningScore,
                    require500Opening: gameEngine.require500Opening,
                    openingScoreThreshold: gameEngine.openingScoreThreshold,
                    onSelectPlayer: { index in
                        // Require confirmation for jumping to a different player (referee action)
                        if index != gameEngine.currentPlayerIndex {
                            let playerName = gameEngine.players[index].name
                            activeConfirmation = .jumpToPlayer(playerName: playerName, playerIndex: index)
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Compact status bar: mode toggle + game state
                GameStatusBar(gameEngine: gameEngine)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                Divider()

                // Main game area - tight coupling with action bar below
                ScrollView {
                    VStack(spacing: 12) {
                        // Dice selection area at the top (priority content)
                        if gameEngine.isManualMode {
                            ManualScoringView(gameEngine: gameEngine)
                                .padding()
                                .background(FarkleTheme.cardBackground)
                                .cornerRadius(20)
                                .shadow(color: FarkleTheme.shadowColor, radius: 4, x: 0, y: 2)

                            // Manual Mode Scoreboard
                            ManualModeScoreboardView(gameEngine: gameEngine)
                                .padding()
                                .background(FarkleTheme.cardBackground)
                                .cornerRadius(20)
                                .shadow(color: FarkleTheme.shadowColor, radius: 4, x: 0, y: 2)
                        } else if !gameEngine.currentRoll.isEmpty || gameEngine.pendingFarkle {
                            // Dice area - no extra card wrapping for cleaner look
                            DiceSelectionView(gameEngine: gameEngine)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8) // Reduced bottom padding - action bar is close
                }
            }
            // Anchored action bar at bottom using safeAreaInset (stable, no layout jumps)
            .safeAreaInset(edge: .bottom) {
                if !gameEngine.isManualMode {
                    FloatingActionBar(gameEngine: gameEngine)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: Settings gear
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                // Trailing: History, Scoreboard, Actions menu
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingGameHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    
                    Button(action: { showingScoreboard = true }) {
                        Image(systemName: "list.number")
                    }
                    
                    Menu {
                        // Referee tools - only show for host in multiplayer or always in single player
                        if !multiplayerGameEngine.isMultiplayerMode || multiplayerGameEngine.isNetworkHost {
                            Section("Referee Tools") {
                                Button {
                                    activeConfirmation = .skipTurn
                                } label: {
                                    Label("Skip Turn", systemImage: "forward.fill")
                                }
                                
                                Button {
                                    activeConfirmation = .previousPlayer
                                } label: {
                                    Label("Previous Player", systemImage: "backward.fill")
                                }
                            }
                            
                            Divider()
                        }
                        
                        // End game - always show but with different text
                        Button(role: .destructive) {
                            if multiplayerGameEngine.isMultiplayerMode && !multiplayerGameEngine.isNetworkHost {
                                // Clients leave the game
                                multiplayerGameEngine.leaveMultiplayerGame()
                                gameEngine.resetGame()
                            } else {
                                activeConfirmation = .endGame
                            }
                        } label: {
                            Label(
                                multiplayerGameEngine.isMultiplayerMode && !multiplayerGameEngine.isNetworkHost 
                                    ? "Leave Game" 
                                    : "End Game",
                                systemImage: "xmark.circle"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingScoreboard) {
            ScoreboardView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingGameHistory) {
            GameHistoryView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(gameEngine: gameEngine)
        }
        // Confirmation overlay for admin/destructive actions
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
        // Custom blocking game over overlay (replaces system alert)
        .fullScreenCover(isPresented: .constant(gameEngine.gameState == .gameOver && activeConfirmation == nil)) {
            GameOverOverlay(gameEngine: gameEngine)
                .background(ClearBackgroundView())
        }
    }
    
    private func performConfirmation(_ confirmation: ActiveConfirmation) {
        switch confirmation {
        case .skipTurn:
            gameEngine.skipTurn()
        case .bankScore:
            gameEngine.bankScore()
        case .endGame:
            gameEngine.resetGame()
        case .newGame:
            gameEngine.resetGame()
        case .playAgain:
            gameEngine.restartGame()
        case .previousPlayer:
            gameEngine.goToPreviousPlayer()
        case .jumpToPlayer(_, let index):
            gameEngine.jumpToPlayer(at: index)
        case .farkleManual:
            gameEngine.farkleManualTurn()
        case .switchMode:
            // Mode switching is handled directly in GameStatusBar/GameHeaderView
            gameEngine.toggleManualMode()
        }
    }
}

// Compact status bar with mode toggle and game state (replaces old GameHeaderView)
struct GameStatusBar: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var modeSwitchConfirmation: ActiveConfirmation? = nil
    
    var body: some View {
        HStack {
            // Game state indicator
            GameStateIndicator(gameState: gameEngine.gameState)
            
            Spacer()
            
            // "Need points" indicator (compact)
            if let currentPlayer = gameEngine.currentPlayer,
               gameEngine.require500Opening && !currentPlayer.isOnBoard {
                let pointsNeeded = gameEngine.openingScoreThreshold - currentPlayer.roundScore
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 11))
                    Text("Need \(pointsNeeded) pts")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(FarkleTheme.buttonPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FarkleTheme.accentBackground)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Mode toggle (Digital/Calculator)
            if gameEngine.gameState == .playing || gameEngine.gameState == .finalRound {
                Button(action: {
                    handleModeToggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: gameEngine.isManualMode ? "gamecontroller.fill" : "die.face.6.fill")
                            .font(.system(size: 12))
                        Text(gameEngine.isManualMode ? "Digital" : "Calculator")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(FarkleTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(FarkleTheme.accentBackground)
                    .cornerRadius(8)
                }
            }
        }
        // Mode switch confirmation overlay
        .fullScreenCover(item: $modeSwitchConfirmation) { confirmation in
            ConfirmationOverlay(
                title: confirmation.title,
                message: confirmation.message,
                primaryActionTitle: confirmation.primaryActionTitle,
                primaryActionRole: confirmation.isDestructive ? .destructive : nil,
                onPrimary: {
                    gameEngine.toggleManualMode()
                },
                onDismiss: {
                    modeSwitchConfirmation = nil
                }
            )
            .background(ClearBackgroundView())
        }
    }
    
    /// Handle mode toggle with confirmation when there's in-progress state
    private func handleModeToggle() {
        // Check if there's in-progress state in the current mode
        if gameEngine.switchingModeWouldAffectProgress {
            // Show confirmation - toManual is the DESTINATION mode (opposite of current)
            modeSwitchConfirmation = .switchMode(toManual: !gameEngine.isManualMode)
        } else {
            // No in-progress state, switch immediately
            gameEngine.toggleManualMode()
        }
    }
}

// Legacy GameHeaderView (kept for compatibility, but no longer used in main loop)
struct GameHeaderView: View {
    @ObservedObject var gameEngine: GameEngine
    @Binding var leaderboardExpanded: Bool
    @State private var modeSwitchConfirmation: ActiveConfirmation? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Line 1: Player's Turn + Playing Status
            HStack {
                if let currentPlayer = gameEngine.currentPlayer {
                    Text("\(currentPlayer.name)'s Turn")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(FarkleTheme.buttonPrimary)
                } else {
                    Text("Game Setup")
                        .font(.title3)
                        .foregroundColor(FarkleTheme.textSecondary)
                }

                Spacer()

                GameStateIndicator(gameState: gameEngine.gameState)
            }

            // Line 2: Leaderboard + Manual/Digital Toggle
            HStack {
                if gameEngine.gameState == .playing || gameEngine.gameState == .finalRound {
                    TopRightLeaderboardView(gameEngine: gameEngine, isExpanded: $leaderboardExpanded)
                } else {
                    Spacer()
                }

                Spacer()

                if gameEngine.gameState == .playing || gameEngine.gameState == .finalRound {
                    Button(action: {
                        handleModeToggle()
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
        // Mode switch confirmation overlay
        .fullScreenCover(item: $modeSwitchConfirmation) { confirmation in
            ConfirmationOverlay(
                title: confirmation.title,
                message: confirmation.message,
                primaryActionTitle: confirmation.primaryActionTitle,
                primaryActionRole: confirmation.isDestructive ? .destructive : nil,
                onPrimary: {
                    gameEngine.toggleManualMode()
                },
                onDismiss: {
                    modeSwitchConfirmation = nil
                }
            )
            .background(ClearBackgroundView())
        }
    }
    
    private func handleModeToggle() {
        if gameEngine.switchingModeWouldAffectProgress {
            modeSwitchConfirmation = .switchMode(toManual: !gameEngine.isManualMode)
        } else {
            gameEngine.toggleManualMode()
        }
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
    @State private var activeConfirmation: ActiveConfirmation? = nil
    @AppStorage("requireHoldToConfirm") private var requireHoldToConfirm: Bool = true

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                // Main action section
                if gameEngine.pendingFarkle {
                    // Farkle state: show only "Next Player" button
                    Button(action: {
                        HapticFeedback.medium()
                        // Announce farkle before acknowledging
                        let nextPlayerIndex = (gameEngine.currentPlayerIndex + 1) % gameEngine.players.count
                        let nextPlayerName = gameEngine.players.indices.contains(nextPlayerIndex) ? gameEngine.players[nextPlayerIndex].name : nil
                        AccessibilityAnnouncer.announceFarkle(
                            playerName: gameEngine.farklePlayerName,
                            diceValues: gameEngine.farkleDice,
                            nextPlayerName: nextPlayerName
                        )
                        gameEngine.acknowledgeFarkle()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                            Text("Next Player")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(FarkleTheme.diceSelected)
                        .cornerRadius(16)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
                } else if gameEngine.currentRoll.isEmpty {
                    // Pre-roll state: show Undo (if available) and Roll button
                    HStack(spacing: 12) {
                        // Prominent Undo button (Flip7 style)
                        if gameEngine.canUndo {
                            Button(action: {
                                HapticFeedback.light()
                                gameEngine.undoLastSelection()
                            }) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Roll dice button
                        Button(action: { rollDice() }) {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("\(gameEngine.remainingDice)×")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .monospacedDigit()
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
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    // Dice selection actions - reorganized with hold-to-confirm
                    VStack(spacing: 12) {
                        // Selection summary strip
                        SelectionSummaryStrip(gameEngine: gameEngine)
                        
                        // Top row: Undo (prominent) + Keep Rolling (main action)
                        HStack(spacing: 12) {
                            // Prominent Undo button (always visible in thumb zone)
                            Button(action: {
                                HapticFeedback.light()
                                gameEngine.undoLastSelection()
                            }) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(gameEngine.canUndo ? .blue : .gray.opacity(0.4))
                            }
                            .disabled(!gameEngine.canUndo)
                            
                            // Keep Rolling (main action, tap OK)
                            Button(action: {
                                HapticFeedback.medium()
                                gameEngine.continueRolling()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("Keep Rolling")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canContinueRolling ? FarkleTheme.buttonSecondary : FarkleTheme.textSecondary.opacity(0.3))
                                .cornerRadius(14)
                                .overlay(
                                    // Subtle glow when hot dice (all dice selected)
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.orange, lineWidth: shouldGlowKeepRolling ? 2 : 0)
                                        .shadow(color: .orange, radius: shouldGlowKeepRolling ? 8 : 0)
                                )
                            }
                            .disabled(!canContinueRolling)
                        }

                        // Bottom row: Skip Turn + Bank Score (hold or tap based on setting)
                        HStack(spacing: 12) {
                            if requireHoldToConfirm {
                                // Hold-to-confirm mode (default)
                                CompactHoldButton(
                                    title: "Skip",
                                    icon: "forward.fill",
                                    holdDuration: 0.5,
                                    backgroundColor: FarkleTheme.dangerRed,
                                    action: {
                                        announceAndSkip()
                                    }
                                )
                                
                                HoldToConfirmButton(
                                    holdDuration: 0.6,
                                    backgroundColor: canBankScore ? FarkleTheme.diceSelected : FarkleTheme.textSecondary.opacity(0.3),
                                    isEnabled: canBankScore,
                                    action: {
                                        announceAndBank()
                                    }
                                ) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        VStack(spacing: 1) {
                                            Text("Bank Score")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            if canBankScore {
                                                Text("Hold to confirm")
                                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                                    .opacity(0.7)
                                            }
                                        }
                                    }
                                }
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
                                    .background(FarkleTheme.dangerRed)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    HapticFeedback.light()
                                    activeConfirmation = .bankScore
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Bank Score")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(canBankScore ? FarkleTheme.diceSelected : FarkleTheme.textSecondary.opacity(0.3))
                                    .cornerRadius(12)
                                }
                                .disabled(!canBankScore)
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
            .padding(16)
            .background(FarkleTheme.cardBackground)
            .cornerRadius(20)
            .shadow(color: FarkleTheme.shadowColor, radius: 8, x: 0, y: -2)
            .animation(.easeInOut(duration: 0.2), value: gameEngine.canUndo)
            .animation(.easeInOut(duration: 0.3), value: gameEngine.pendingFarkle)
        }
        // Confirmation overlay (in-app, not system alert)
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
        let selectedCount = gameEngine.selectedDice.count
        let currentRollCount = gameEngine.currentRoll.count
        return selectedCount == currentRollCount && selectedCount > 0
    }

    private func rollDice() {
        SoundManager.shared.playDiceRoll()
        HapticFeedback.medium()
        let diceCount = gameEngine.remainingDice
        let result = withAnimation(.easeInOut(duration: 0.3)) {
            gameEngine.rollDice()
        }
        // Announce the roll for VoiceOver users
        AccessibilityAnnouncer.announceRoll(diceCount: diceCount, values: result)
    }
    
    private func performConfirmation(_ confirmation: ActiveConfirmation) {
        switch confirmation {
        case .skipTurn:
            announceAndSkip()
        case .bankScore:
            announceAndBank()
        case .endGame, .newGame:
            gameEngine.resetGame()
        case .playAgain:
            gameEngine.restartGame()
        case .previousPlayer:
            gameEngine.goToPreviousPlayer()
        case .jumpToPlayer(_, let index):
            gameEngine.jumpToPlayer(at: index)
        case .farkleManual:
            gameEngine.farkleManualTurn()
        case .switchMode:
            // Mode switching is handled directly in GameStatusBar/GameHeaderView
            gameEngine.toggleManualMode()
        }
    }
    
    private func announceAndBank() {
        guard let player = gameEngine.currentPlayer else {
            gameEngine.bankScore()
            return
        }
        
        let playerName = player.name
        let pointsBanking = gameEngine.turnScore
        let projectedTotal = player.totalScore + player.roundScore + gameEngine.turnScore
        
        // Calculate next player
        let nextPlayerIndex = (gameEngine.currentPlayerIndex + 1) % gameEngine.players.count
        let nextPlayerName = gameEngine.players.indices.contains(nextPlayerIndex) ? gameEngine.players[nextPlayerIndex].name : nil
        
        gameEngine.bankScore()
        
        // Announce after banking
        AccessibilityAnnouncer.announceBank(
            playerName: playerName,
            pointsBanked: pointsBanking,
            newTotal: projectedTotal,
            nextPlayerName: nextPlayerName
        )
    }
    
    private func announceAndSkip() {
        guard let player = gameEngine.currentPlayer else {
            gameEngine.skipTurn()
            return
        }
        
        let playerName = player.name
        let nextPlayerIndex = (gameEngine.currentPlayerIndex + 1) % gameEngine.players.count
        let nextPlayerName = gameEngine.players.indices.contains(nextPlayerIndex) ? gameEngine.players[nextPlayerIndex].name : nil
        
        gameEngine.skipTurn()
        
        AccessibilityAnnouncer.announceSkip(playerName: playerName, nextPlayerName: nextPlayerName)
    }
}

// Compact selection summary strip for the action bar
struct SelectionSummaryStrip: View {
    @ObservedObject var gameEngine: GameEngine
    
    private var hasSelection: Bool {
        !gameEngine.selectedDice.isEmpty
    }
    
    private var projectedRoundTotal: Int {
        (gameEngine.currentPlayer?.roundScore ?? 0) + gameEngine.turnScore
    }
    
    /// Sort dice by scoring value descending: sets of 3+ by value, then 1s, then 5s
    private var sortedSelectedDice: [Int] {
        let dice = gameEngine.selectedDice
        var counts: [Int: Int] = [:]
        for die in dice {
            counts[die, default: 0] += 1
        }
        
        // Build sorted array: groups of 3+ first (by count desc, then value desc), then 1s, then 5s, then others
        var result: [Int] = []
        
        // First: triplets+ sorted by count desc, then by value desc (higher sets = higher score)
        let tripletsOrMore = counts.filter { $0.value >= 3 }.sorted { 
            if $0.value != $1.value { return $0.value > $1.value }
            // For same count, 1s score highest (1000 for 3), then 6s (600), etc.
            if $0.key == 1 { return true }
            if $1.key == 1 { return false }
            return $0.key > $1.key
        }
        for (value, count) in tripletsOrMore {
            result.append(contentsOf: Array(repeating: value, count: count))
            counts[value] = 0
        }
        
        // Then: remaining 1s (100 each)
        if let onesCount = counts[1], onesCount > 0 {
            result.append(contentsOf: Array(repeating: 1, count: onesCount))
            counts[1] = 0
        }
        
        // Then: remaining 5s (50 each)
        if let fivesCount = counts[5], fivesCount > 0 {
            result.append(contentsOf: Array(repeating: 5, count: fivesCount))
            counts[5] = 0
        }
        
        // Any remaining dice (shouldn't score but include for completeness)
        for (value, count) in counts.sorted(by: { $0.key > $1.key }) where count > 0 {
            result.append(contentsOf: Array(repeating: value, count: count))
        }
        
        return result
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if hasSelection {
                // Selected dice chips - sorted by scoring value
                HStack(spacing: 4) {
                    ForEach(Array(sortedSelectedDice.enumerated()), id: \.offset) { _, die in
                        Text("\(die)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(FarkleTheme.diceSelected)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Points summary
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(gameEngine.turnScore)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(FarkleTheme.diceSelected)
                        Text("pts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FarkleTheme.textSecondary)
                    }
                    
                    Text("Round: \(projectedRoundTotal)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(FarkleTheme.buttonSecondary)
                }
            } else {
                // Hint when nothing selected
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 14))
                        .foregroundColor(FarkleTheme.textSecondary)
                    Text("Select scoring dice to continue")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FarkleTheme.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FarkleTheme.tertiaryBackground)
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasSelection ? "Selected \(gameEngine.selectedDice.count) dice for \(gameEngine.turnScore) points. Round total will be \(projectedRoundTotal)." : "Select scoring dice to continue")
    }
}

// Helper view for transparent fullScreenCover background
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
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
    
    // Track if opening score was just toggled off (to set players on board)
    @State private var previousOpeningRequirement: Bool = true

    // Computed properties for winning score constraints
    private var maxPlayerScore: Int {
        gameEngine.players.map { $0.totalScore }.max() ?? 0
    }
    
    private var winningScoreRange: ClosedRange<Int> {
        let minScore = max(1000, maxPlayerScore + 1)
        return minScore...100000
    }
    
    private var canEditWinningScore: Bool {
        // Must be host (in multiplayer) and not in final round
        guard gameEngine.canEditRules else { return false }
        return gameEngine.gameState != .finalRound
    }
    
    private var winningScoreDisabledReason: String? {
        if !gameEngine.canEditRules {
            return gameEngine.editingDisabledReason
        }
        if gameEngine.gameState == .finalRound {
            return "Cannot change during final round"
        }
        return nil
    }
    
    private var canEditRules: Bool {
        gameEngine.canEditRules
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        
                        Text("Edit Game Rules")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        Text("Modify rules during gameplay")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    VStack(spacing: 20) {
                        // MARK: - Winning Score
                        InlineNumberStepperRow(
                            label: "Winning Score",
                            value: $gameEngine.winningScore,
                            range: winningScoreRange,
                            step: 1000,
                            defaultValue: 10000,
                            subtitle: "First to reach this score triggers final round",
                            isEnabled: canEditWinningScore,
                            disabledReason: winningScoreDisabledReason
                        )

                        Divider()

                        // MARK: - Opening Score Requirement
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $gameEngine.require500Opening) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Require Opening Score")
                                        .font(.system(size: 17, weight: .regular, design: .rounded))
                                        .foregroundStyle(canEditRules ? .primary : .secondary)
                                    Text("Players must score this in one turn to get on the board")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .disabled(!canEditRules)
                            .onChange(of: gameEngine.require500Opening) { oldValue, newValue in
                                // When turning OFF, set all players on board
                                if oldValue && !newValue {
                                    gameEngine.setAllPlayersOnBoard()
                                }
                            }

                            if gameEngine.require500Opening {
                                InlineNumberStepperRow(
                                    label: "Threshold",
                                    value: $gameEngine.openingScoreThreshold,
                                    range: 100...2000,
                                    step: 50,
                                    defaultValue: 500,
                                    isEnabled: canEditRules,
                                    disabledReason: gameEngine.editingDisabledReason
                                )
                                .padding(.leading, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: gameEngine.require500Opening)

                        Divider()

                        // MARK: - Triple Farkle Penalty
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $gameEngine.enableTripleFarkleRule) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Triple Farkle Penalty")
                                        .font(.system(size: 17, weight: .regular, design: .rounded))
                                        .foregroundStyle(canEditRules ? .primary : .secondary)
                                    Text("Three farkles in a row deducts points")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .disabled(!canEditRules)

                            if gameEngine.enableTripleFarkleRule {
                                InlineNumberStepperRow(
                                    label: "Penalty Amount",
                                    value: $gameEngine.tripleFarklePenalty,
                                    range: 100...5000,
                                    step: 100,
                                    defaultValue: 1000,
                                    isEnabled: canEditRules,
                                    disabledReason: gameEngine.editingDisabledReason
                                )
                                .padding(.leading, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: gameEngine.enableTripleFarkleRule)

                        // Host-only banner (in multiplayer)
                        if !canEditRules, let reason = gameEngine.editingDisabledReason {
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
                        
                        // MARK: - Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(FarkleTheme.buttonPrimary)
                                Text("Rule Change Policy")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                RulePolicyRow(
                                    icon: "checkmark.circle",
                                    text: "Opening score and triple farkle can be changed anytime"
                                )
                                RulePolicyRow(
                                    icon: "arrow.up.circle",
                                    text: "Winning score must stay above the leader's score"
                                )
                                RulePolicyRow(
                                    icon: "person.2.circle",
                                    text: "Turning off opening requirement puts all players on board"
                                )
                                RulePolicyRow(
                                    icon: "network",
                                    text: "In multiplayer, only the host can edit rules"
                                )
                            }
                        }
                        .padding()
                        .background(FarkleTheme.accentBackground)
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(FarkleTheme.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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

/// Small helper for rule policy bullet points
private struct RulePolicyRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// Theme picker for light/dark mode
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

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
        case .midnight:
            return "Deep indigo dark theme"
        case .sunset:
            return "Warm orange light theme"
        case .forest:
            return "Nature-inspired dark theme"
        case .ocean:
            return "Cool cyan dark theme"
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
    @State private var scoreEditingPlayer: Player? = nil

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
                                    // Edit name button
                                    Button(action: {
                                        editingPlayerID = player.id
                                        editingPlayerName = player.name
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(FarkleTheme.buttonPrimary)
                                            .font(.caption)
                                    }
                                    
                                    // Edit score button (host-only in multiplayer)
                                    if gameEngine.canEditRules {
                                        Button {
                                            scoreEditingPlayer = player
                                        } label: {
                                            Image(systemName: "number.circle")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }

                        // Tappable score area in edit mode (host-only in multiplayer)
                        if isEditing && gameEngine.canEditRules {
                            Button {
                                scoreEditingPlayer = player
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Total: \(player.totalScore)")
                                        .font(.subheadline)
                                        .foregroundColor(FarkleTheme.textSecondary)

                                    if player.roundScore > 0 {
                                        Text("Round: +\(player.roundScore)")
                                            .font(.subheadline)
                                            .foregroundColor(FarkleTheme.buttonSecondary)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
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
        .sheet(item: $scoreEditingPlayer) { player in
            ScoreEditingSheet(player: player) { newTotal, newRound in
                if newTotal != player.totalScore {
                    gameEngine.setPlayerTotalScore(player.id, to: newTotal)
                }
                if newRound != player.roundScore {
                    gameEngine.setPlayerRoundScore(player.id, to: newRound)
                }
            }
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
