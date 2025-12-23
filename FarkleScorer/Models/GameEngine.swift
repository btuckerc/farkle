import Foundation
import Combine

class GameEngine: ObservableObject {

    // MARK: - Published Properties
    @Published var players: [Player] = []
    @Published var currentPlayerIndex: Int = 0
    @Published var gameState: GameState = .setup
    @Published var winningScore: Int = 10000
    @Published var currentRoll: [Int] = []
    @Published var selectedDice: [Int] = []
    @Published var remainingDice: Int = 6
    @Published var turnScore: Int = 0
    @Published var gameHistory: [GameHistoryEntry] = []

    // MARK: - Manual Scoring Mode
    @Published var isManualMode: Bool = false
    @Published var manualTurnScore: Int = 0
    @Published var manualScoreHistory: [Int] = []

    // MARK: - Game Configuration
    @Published var require500Opening: Bool = true
    @Published var openingScoreThreshold: Int = 500
    @Published var enableTripleFarkleRule: Bool = false
    @Published var tripleFarklePenalty: Int = 1000
    
    // MARK: - Scoring Rules (House Rules)
    @Published var scoringRulesStore: ScoringRulesStore = ScoringRulesStore.load() {
        didSet {
            // Rebuild scoring engine when rules change
            rebuildScoringEngine()
        }
    }
    
    // MARK: - Multiplayer Control (set by MultiplayerGameEngine)
    /// Whether this device can edit game rules (host-only in multiplayer)
    @Published var canEditRules: Bool = true
    /// Reason why editing is disabled (for UI display)
    @Published var editingDisabledReason: String? = nil

    // MARK: - Farkle Acknowledgment
    @Published var pendingFarkle: Bool = false
    @Published var farklePlayerName: String = ""
    @Published var farkleDice: [Int] = []

    // MARK: - Undo Functionality (bounded stack for reversible actions only)
    @Published var canUndo: Bool = false
    @Published var invalidSelectionWarning: Bool = false
    
    /// Bounded undo stack - only stores reversible action snapshots
    /// Does NOT allow undoing: dice rolls, banked scores, turn advances
    private var undoStack: [UndoSnapshot] = []
    private let maxUndoStackSize = 30
    
    /// Types of actions that can be undone (fair-play policy)
    enum UndoableAction: String {
        case diceSelection = "diceSelection"
        case continueRolling = "continueRolling"
        case manualScoreAdd = "manualScoreAdd"
        case manualScoreRemove = "manualScoreRemove"
        case manualScoreClear = "manualScoreClear"
    }
    
    /// Snapshot of game state for undo - only captures what's needed for fair-play undos
    private struct UndoSnapshot {
        let action: UndoableAction
        let timestamp: Date
        
        // Dice mode state
        let currentRoll: [Int]
        let selectedDice: [Int]
        let turnScore: Int
        let remainingDice: Int
        let playerTurnHistory: [Turn]
        let playerRoundScore: Int
        
        // Manual mode state
        let manualTurnScore: Int
        let manualScoreHistory: [Int]
        
        // Player state (for more complex undos)
        let currentPlayerIndex: Int
    }
    
    // Legacy single-state undo (kept for backward compatibility during transition)
    private var undoState: UndoState?
    private struct UndoState {
        let currentRoll: [Int]
        let selectedDice: [Int]
        let turnScore: Int
        let remainingDice: Int
        let playerTurnHistory: [Turn]
        let playerRoundScore: Int
    }

    // MARK: - Private Properties
    private var scoringEngine: ScoringEngine
    private var gameWinner: Player?
    private var finalRoundStarted: Bool = false
    private var finalRoundTriggerPlayerIndex: Int = -1
    private var playersCompletedFinalRound: Set<Int> = []

    // MARK: - Initialization
    init() {
        // Load saved scoring rules and build engine
        let savedRules = ScoringRulesStore.load()
        self.scoringEngine = ScoringEngine(rules: savedRules.toScoringRules())
        self.scoringRulesStore = savedRules
    }
    
    /// Rebuild the scoring engine with current rules (called when rules change)
    private func rebuildScoringEngine() {
        scoringEngine = ScoringEngine(rules: scoringRulesStore.toScoringRules())
    }
    
    /// Save current scoring rules to persistence
    func saveScoringRules() {
        scoringRulesStore.save()
        logGameEvent("Scoring rules updated")
    }
    
    /// Reset scoring rules to official defaults
    func resetScoringRulesToDefaults() {
        ScoringRulesStore.resetToDefaults()
        scoringRulesStore = ScoringRulesStore()
        logGameEvent("Scoring rules reset to official defaults")
    }
    
    // MARK: - State Invariants (DEBUG checks to catch bugs early)
    
    /// Verifies that the game state is consistent. Called in DEBUG builds.
    private func checkInvariants() {
        #if DEBUG
        // Invariant 1: When game is active, must have at least one player
        if gameState != .setup {
            assert(!players.isEmpty, "Game state \(gameState) requires at least one player")
        }
        
        // Invariant 2: currentPlayerIndex must be in bounds when playing
        if gameState == .playing || gameState == .finalRound {
            assert(currentPlayerIndex < players.count, 
                   "currentPlayerIndex (\(currentPlayerIndex)) out of bounds (players.count: \(players.count))")
        }
        
        // Invariant 3: In manual mode, currentRoll should be empty (we're not using digital dice)
        if isManualMode && gameState != .setup {
            // This is a soft invariant - log warning but don't crash
            if !currentRoll.isEmpty {
                print("⚠️ Warning: currentRoll should be empty in manual mode")
            }
        }
        
        // Invariant 4: When pendingFarkle is true, farkleDice should not be empty
        if pendingFarkle {
            assert(!farkleDice.isEmpty, "pendingFarkle is true but farkleDice is empty")
        }
        
        // Invariant 5: remainingDice should be 1-6
        assert(remainingDice >= 1 && remainingDice <= 6, 
               "remainingDice (\(remainingDice)) out of valid range 1-6")
        #endif
    }
    
    /// Safely advances currentPlayerIndex, ensuring it stays in bounds
    private func safeAdvancePlayerIndex() {
        guard !players.isEmpty else { return }
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }

    // MARK: - Game State Management

    enum GameState {
        case setup
        case playing
        case finalRound
        case gameOver
    }

    var currentPlayer: Player? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    var isCurrentPlayerOnBoard: Bool {
        guard let player = currentPlayer else { return false }
        return player.isOnBoard || !require500Opening
    }

    var isFinalRoundActive: Bool {
        return finalRoundStarted && gameState == .finalRound
    }

    var finalRoundDescription: String {
        guard isFinalRoundActive else { return "" }

        let remainingPlayers = players.count - playersCompletedFinalRound.count
        let triggerPlayerName = finalRoundTriggerPlayerIndex < players.count ?
            players[finalRoundTriggerPlayerIndex].name : "Unknown"

        return "\(triggerPlayerName) reached \(winningScore)! \(remainingPlayers) player\(remainingPlayers == 1 ? "" : "s") left."
    }

    // MARK: - Game Setup

    func addPlayer(name: String) {
        // Trim and enforce max length
        var trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count > 20 {
            trimmedName = String(trimmedName.prefix(20))
        }
        
        let player = Player(
            name: trimmedName,
            requiresOpeningScore: require500Opening,
            openingScoreThreshold: openingScoreThreshold
        )
        players.append(player)
    }

    func removePlayer(at index: Int) {
        guard index < players.count, players.count > 1 else { return }
        players.remove(at: index)
        if currentPlayerIndex >= players.count {
            currentPlayerIndex = 0
        }
    }

    func updatePlayerName(at index: Int, to name: String) {
        guard index < players.count else { return }
        // Trim and enforce max length
        var trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count > 20 {
            trimmedName = String(trimmedName.prefix(20))
        }
        players[index].name = trimmedName
    }

    func startGame() {
        guard players.count >= 1 else { return }

        // Ensure all players have valid names (fill empty names with defaults)
        for index in players.indices {
            let trimmedName = players[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                players[index].name = "Player \(index + 1)"
            } else if trimmedName.count > 20 {
                // Enforce max name length
                players[index].name = String(trimmedName.prefix(20))
            } else {
                players[index].name = trimmedName
            }
        }

        gameState = .playing
        currentPlayerIndex = 0
        resetTurn()
        logGameEvent("Game started with \(players.count) player\(players.count == 1 ? "" : "s")")
        
        // Verify invariants after game start
        checkInvariants()
    }

    func resetGame() {
        players.removeAll()
        currentPlayerIndex = 0
        gameState = .setup
        gameHistory.removeAll()
        finalRoundStarted = false
        finalRoundTriggerPlayerIndex = -1
        playersCompletedFinalRound.removeAll()
        gameWinner = nil
        resetTurn()
    }
    
    /// Restart the game with the same players and rules - just reset scores
    /// This is the "Play Again" flow that reduces taps between games
    func restartGame() {
        guard !players.isEmpty else {
            // Fallback to full reset if no players
            resetGame()
            return
        }
        
        // Reset each player's scores and history while keeping their name
        for index in players.indices {
            players[index].totalScore = 0
            players[index].roundScore = 0
            players[index].gameHistory.removeAll()
            players[index].consecutiveFarkles = 0
            // Reset "on board" status based on current rule setting
            players[index].isOnBoard = !require500Opening
        }
        
        // Reset game state
        currentPlayerIndex = 0
        gameState = .playing
        gameHistory.removeAll()
        finalRoundStarted = false
        finalRoundTriggerPlayerIndex = -1
        playersCompletedFinalRound.removeAll()
        gameWinner = nil
        resetTurn()
        
        logGameEvent("Game restarted with \(players.count) player\(players.count == 1 ? "" : "s")")
    }

    // MARK: - Turn Management

    func rollDice() -> [Int] {
        // Clear any pending farkle state from previous player
        if pendingFarkle {
            pendingFarkle = false
            farklePlayerName = ""
            farkleDice = []
        }

        let diceToRoll = max(1, remainingDice)
        let newRoll = (0..<diceToRoll).map { _ in Int.random(in: 1...6) }
        currentRoll = newRoll
        selectedDice = []

        // Rolling dice is irreversible - clear undo stack (fair-play policy)
        clearUndoStack()

        // Check if player farkled
        if !canScoreAnyDice(newRoll) {
            handleFarkle()
        }

        return newRoll
    }

    func selectDice(_ dice: [Int]) {
        selectedDice = dice
        turnScore = scoringEngine.calculateScore(for: dice)
    }

    func bankScore() {
        guard let player = currentPlayer else { return }
        
        // Banking is irreversible - clear undo stack (fair-play policy)
        clearUndoStack()

        if isManualMode {
            // Bank manual score
            if manualTurnScore > 0 {
                let turn = Turn(
                    diceRolled: [],
                    selectedDice: [],
                    score: manualTurnScore,
                    isFarkle: false
                )
                players[currentPlayerIndex].addTurn(turn)
                // Note: Don't add manualTurnScore to roundScore here - it's already added in addTurn()
                manualScoreHistory.append(manualTurnScore)

                logGameEvent("\(player.name) banked \(manualTurnScore) points (manual)")
                manualTurnScore = 0
            }
        } else {
            // Bank dice game score
            if turnScore > 0 {
                let turn = Turn(
                    diceRolled: currentRoll,
                    selectedDice: selectedDice,
                    score: turnScore,
                    isFarkle: false
                )
                players[currentPlayerIndex].addTurn(turn)
                // Note: Don't add turnScore to roundScore here - it's already added in addTurn()

                logGameEvent("\(player.name) banked \(turnScore) points")
            }
        }

        // Bank the round score
        players[currentPlayerIndex].bankRoundScore()
        checkForWin(player: players[currentPlayerIndex])

        nextPlayer()
    }

    func continueRolling() {
        guard turnScore > 0 else { return }

        // Validate that selected dice actually score points (official rule enforcement)
        guard selectedDice.count > 0 && scoringEngine.calculateScore(for: selectedDice) > 0 else {
            // Show invalid selection warning
            invalidSelectionWarning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.invalidSelectionWarning = false
            }
            return // Cannot continue without selecting at least one scoring die
        }

        // Save current state for undo functionality (using new stack-based system)
        saveStateForUndo(action: .continueRolling)

        // Calculate remaining dice correctly
        // Start with current roll count, subtract selected dice
        let diceUsedThisRoll = selectedDice.count
        remainingDice = currentRoll.count - diceUsedThisRoll

        // If all dice were used (hot dice), roll all 6 again
        if remainingDice == 0 {
            remainingDice = 6
        }

        // Add this roll to turn history without banking
        let turn = Turn(
            diceRolled: currentRoll,
            selectedDice: selectedDice,
            score: turnScore
        )

        if let playerIndex = getCurrentPlayerIndex() {
            players[playerIndex].addTurn(turn)
            logTurn(player: players[playerIndex], turn: turn, banked: false)
        }

        // Reset for next roll and enable undo (until they roll again)
        currentRoll = []
        selectedDice = []
        updateCanUndo()
    }

    func undoLastSelection() {
        guard canUndo, let snapshot = undoStack.popLast() else { return }

        // Restore state from snapshot
        currentRoll = snapshot.currentRoll
        selectedDice = snapshot.selectedDice
        turnScore = snapshot.turnScore
        remainingDice = snapshot.remainingDice
        manualTurnScore = snapshot.manualTurnScore
        manualScoreHistory = snapshot.manualScoreHistory

        // Restore player state
        if let playerIndex = getCurrentPlayerIndex(), playerIndex < players.count {
            players[playerIndex].gameHistory = snapshot.playerTurnHistory
            players[playerIndex].roundScore = snapshot.playerRoundScore
        }

        // Update undo availability
        updateCanUndo()
    }
    
    // MARK: - Undo Stack Helpers
    
    /// Save current state to undo stack before a reversible action
    private func saveStateForUndo(action: UndoableAction) {
        guard let playerIndex = getCurrentPlayerIndex(), playerIndex < players.count else { return }
        
        let snapshot = UndoSnapshot(
            action: action,
            timestamp: Date(),
            currentRoll: currentRoll,
            selectedDice: selectedDice,
            turnScore: turnScore,
            remainingDice: remainingDice,
            playerTurnHistory: players[playerIndex].gameHistory,
            playerRoundScore: players[playerIndex].roundScore,
            manualTurnScore: manualTurnScore,
            manualScoreHistory: manualScoreHistory,
            currentPlayerIndex: currentPlayerIndex
        )
        
        undoStack.append(snapshot)
        
        // Enforce max stack size
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }
        
        updateCanUndo()
    }
    
    /// Clear undo stack (called on irreversible actions like roll, bank, turn advance)
    private func clearUndoStack() {
        undoStack.removeAll()
        updateCanUndo()
    }
    
    /// Update the canUndo published property
    private func updateCanUndo() {
        canUndo = !undoStack.isEmpty
    }

    private func handleFarkle() {
        guard let playerIndex = getCurrentPlayerIndex() else { return }

        let turn = Turn(
            diceRolled: currentRoll,
            selectedDice: [],
            score: 0,
            isFarkle: true
        )

        players[playerIndex].addTurn(turn)
        players[playerIndex].resetRoundScore()

        // Handle triple farkle rule
        if enableTripleFarkleRule && players[playerIndex].hasTripleFarkle {
            logGameEvent("\(players[playerIndex].name) got triple farkle! Penalty: -\(tripleFarklePenalty)")
            logGameEvent("DEBUG: Player had \(players[playerIndex].consecutiveFarkles) consecutive farkles before penalty")
            players[playerIndex].applyTripleFarklePenalty(tripleFarklePenalty)
            logGameEvent("DEBUG: Player now has \(players[playerIndex].consecutiveFarkles) consecutive farkles after penalty")
        } else if enableTripleFarkleRule {
            logGameEvent("DEBUG: \(players[playerIndex].name) now has \(players[playerIndex].consecutiveFarkles) consecutive farkles")
        }

        logTurn(player: players[playerIndex], turn: turn, banked: false)

        // Set pending farkle for user acknowledgment
        pendingFarkle = true
        farklePlayerName = players[playerIndex].name
        farkleDice = currentRoll
    }

    func acknowledgeFarkle() {
        guard pendingFarkle else { return }

        pendingFarkle = false
        farklePlayerName = ""
        farkleDice = []
        nextPlayer()
    }

    private func nextPlayer() {
        // Guard against empty players array
        guard !players.isEmpty else {
            #if DEBUG
            print("⚠️ nextPlayer called with empty players array")
            #endif
            return
        }
        
        // Mark current player as having completed their final round turn (if in final round)
        if finalRoundStarted {
            playersCompletedFinalRound.insert(currentPlayerIndex)
        }

        // Safely advance to next player
        safeAdvancePlayerIndex()
        resetTurn()
        
        // Verify invariants after state transition
        checkInvariants()

        // Check if final round is complete
        if finalRoundStarted {
            // Final round is complete when:
            // 1. We've gone back to the player who triggered the final round, OR
            // 2. All players have completed their final round turn
            if currentPlayerIndex == finalRoundTriggerPlayerIndex ||
               playersCompletedFinalRound.count >= players.count {
                endGame()
                return
            }

            // If this player already completed their final round, move to next
            if playersCompletedFinalRound.contains(currentPlayerIndex) {
                nextPlayer()
            }
        }
    }

    private func resetTurn() {
        // Clear digital dice state
        currentRoll = []
        selectedDice = []
        remainingDice = 6
        turnScore = 0

        // Clear manual/calculator state
        // Since state is preserved across mode switches, we clear BOTH modes
        // at true turn boundaries (new turn = fresh state in both modes)
        manualTurnScore = 0
        manualScoreHistory = []

        // Clear undo stack on turn reset (new turn = fresh state)
        clearUndoStack()
    }

    // MARK: - Game Logic

    private func canScoreAnyDice(_ dice: [Int]) -> Bool {
        return scoringEngine.canScore(dice)
    }

    func getPossibleScorings(for dice: [Int]) -> [ScoringOption] {
        return scoringEngine.getPossibleScorings(for: dice)
    }

    private func checkForWin(player: Player) {
        if player.totalScore >= winningScore && !finalRoundStarted {
            finalRoundStarted = true
            finalRoundTriggerPlayerIndex = currentPlayerIndex
            gameWinner = player
            gameState = .finalRound
            playersCompletedFinalRound.removeAll()
            logGameEvent("\(player.name) reached \(winningScore)! Final round begins - everyone gets one more turn.")
        }
    }

    private func endGame() {
        gameState = .gameOver

        // Find the actual winner (highest score)
        if let winner = players.max(by: { $0.totalScore < $1.totalScore }) {
            gameWinner = winner
            logGameEvent("Game Over! Winner: \(winner.name) with \(winner.totalScore) points")
        }
    }

    // MARK: - Utility Functions

    private func getCurrentPlayerIndex() -> Int? {
        guard currentPlayerIndex < players.count else { return nil }
        return currentPlayerIndex
    }

    /// Skip the current player's turn (legacy alias for skipTurn)
    /// Prefer using skipTurn() directly for new code
    func skipPlayer() {
        skipTurn()
    }

    func goToPreviousPlayer() {
        currentPlayerIndex = currentPlayerIndex > 0 ? currentPlayerIndex - 1 : players.count - 1
        resetTurn()
        logGameEvent("Went back to \(currentPlayer?.name ?? "Unknown")'s turn")
    }

    func jumpToPlayer(at index: Int) {
        guard index < players.count else { return }
        currentPlayerIndex = index
        resetTurn()
        logGameEvent("Jumped to \(currentPlayer?.name ?? "Unknown")'s turn")
    }

    // MARK: - Scoring Helpers

    func calculateScore(for dice: [Int]) -> Int {
        return scoringEngine.calculateScore(for: dice)
    }

    func canScoreAnyPoints(for dice: [Int]) -> Bool {
        return scoringEngine.canScore(dice)
    }

    func canPlayerBank() -> Bool {
        guard let player = currentPlayer else { return false }

        if isManualMode {
            // In manual mode, can bank if there's a manual score
            if manualTurnScore <= 0 { return false }

            // If opening score required and player not on board
            if require500Opening && !player.isOnBoard {
                return (player.roundScore + manualTurnScore) >= openingScoreThreshold
            }

            return true
        } else {
            // Regular dice mode logic
            // If opening score required and player not on board
            if require500Opening && !player.isOnBoard {
                return (player.roundScore + turnScore) >= openingScoreThreshold
            }

            return turnScore > 0
        }
    }

    func canPlayerContinueRolling() -> Bool {
        // Must have selected dice that actually score points
        guard selectedDice.count > 0 else { return false }
        guard turnScore > 0 else { return false }

        // Validate that the selected dice are valid scoring combinations
        if scoringEngine.calculateScore(for: selectedDice) <= 0 {
            return false
        }

        // For continue rolling validation, we need to check if the selected dice
        // follow proper grouping rules within the context of the original roll
        // This is more complex since we need the original roll context
        // For now, just check that it scores points (basic validation)
        return true
    }

    func validateCurrentSelection() -> DiceSelectionValidation {
        let selectedIndices = Set(0..<selectedDice.count)
        return scoringEngine.validateDiceSelection(selectedIndices, for: selectedDice)
    }

    // MARK: - Game History

    private func logGameEvent(_ message: String) {
        let entry = GameHistoryEntry(
            type: .gameEvent,
            playerName: "",
            message: message,
            timestamp: Date()
        )
        gameHistory.append(entry)
    }

    private func logTurn(player: Player, turn: Turn, banked: Bool) {
        let message: String
        if turn.isFarkle {
            message = "Farkled! Lost round score."
        } else if banked {
            message = "Banked \(turn.score) points. Total: \(player.totalScore)"
        } else {
            message = "Scored \(turn.score) points. Round total: \(player.roundScore)"
        }

        let entry = GameHistoryEntry(
            type: .turn,
            playerName: player.name,
            message: message,
            timestamp: turn.timestamp
        )
        gameHistory.append(entry)
    }

    // MARK: - Game Statistics

    func getPlayerRanking() -> [Player] {
        return players.sorted { $0.totalScore > $1.totalScore }
    }

    func getGameStatistics() -> GameStatistics {
        let totalTurns = players.reduce(0) { $0 + $1.gameHistory.count }
        let totalFarkles = players.reduce(0) { result, player in
            result + player.gameHistory.filter { $0.isFarkle }.count
        }

        return GameStatistics(
            totalTurns: totalTurns,
            totalFarkles: totalFarkles,
            gameLength: gameHistory.isEmpty ? 0 : Date().timeIntervalSince(gameHistory.first!.timestamp),
            playerStats: players.map { PlayerStatistics(player: $0) }
        )
    }

    // MARK: - Mode Switching & In-Progress State Helpers
    
    /// Whether there is an active digital dice turn in progress (roll/selection/score)
    var hasDigitalTurnInProgress: Bool {
        !currentRoll.isEmpty || !selectedDice.isEmpty || turnScore > 0
    }
    
    /// Whether there is an active calculator/manual turn in progress (points entered)
    var hasManualTurnInProgress: Bool {
        manualTurnScore > 0 || !manualScoreHistory.isEmpty
    }
    
    /// Whether switching modes would affect in-progress state in the current mode
    var switchingModeWouldAffectProgress: Bool {
        isManualMode ? hasManualTurnInProgress : hasDigitalTurnInProgress
    }

    // MARK: - Manual Scoring Functions

    /// Toggle between digital dice mode and calculator/manual mode.
    /// State is preserved in both modes—switching does NOT clear progress.
    func toggleManualMode() {
        isManualMode.toggle()
        // State is intentionally preserved across mode switches.
        // The true turn boundaries (resetTurn, nextPlayer, bankScore, etc.)
        // handle clearing state when appropriate.
    }

    func addManualScore(_ score: Int) {
        guard isManualMode && score > 0 else { return }
        
        // Save state for undo (reversible action)
        saveStateForUndo(action: .manualScoreAdd)
        
        manualScoreHistory.append(score)
        manualTurnScore += score
    }

    func removeLastManualScore() {
        guard isManualMode && !manualScoreHistory.isEmpty else { return }
        
        // Save state for undo (reversible action)
        saveStateForUndo(action: .manualScoreRemove)
        
        let lastScore = manualScoreHistory.removeLast()
        manualTurnScore -= lastScore
    }

    func bankManualScore() {
        guard isManualMode && manualTurnScore > 0 else { return }
        guard let playerIndex = getCurrentPlayerIndex() else { return }
        
        // Banking is irreversible - clear undo stack (fair-play policy)
        clearUndoStack()

        // Create a turn record for manual scoring
        let turn = Turn(
            diceRolled: [], // No dice in manual mode
            selectedDice: [], // No dice selection in manual mode
            score: manualTurnScore
        )

        players[playerIndex].addTurn(turn)
        players[playerIndex].bankRoundScore()

        logTurn(player: players[playerIndex], turn: turn, banked: true)
        logGameEvent("Manual score of \(manualTurnScore) banked by \(players[playerIndex].name)")

        // Check for game-ending conditions
        checkForWin(player: players[playerIndex])

        // Reset manual scoring
        manualTurnScore = 0
        manualScoreHistory = []

        // Move to next player
        nextPlayer()
    }

    func farkleManualTurn() {
        guard isManualMode else { return }
        
        // Farkle is irreversible - clear undo stack
        clearUndoStack()

        // Clear all accumulated scores for this turn
        manualTurnScore = 0
        manualScoreHistory = []

        // Reset round score to 0 (farkle loses all points in the round)
        if currentPlayerIndex < players.count {
            players[currentPlayerIndex].roundScore = 0
        }

        nextPlayer()
    }

    // MARK: - Rule Management (Mid-Game Edits)
    
    /// Set all players as "on board" - used when turning off opening score requirement
    func setAllPlayersOnBoard() {
        for index in players.indices {
            players[index].isOnBoard = true
        }
        logGameEvent("Opening score requirement disabled - all players now on board")
    }
    
    /// Update a player's total score (referee action)
    /// Returns the old value for logging
    @discardableResult
    func setPlayerTotalScore(_ playerId: UUID, to newScore: Int) -> Int? {
        guard let index = players.firstIndex(where: { $0.id == playerId }) else { return nil }
        let oldScore = players[index].totalScore
        players[index].totalScore = max(0, newScore)
        
        // If they now have points, ensure they're on board
        if players[index].totalScore > 0 {
            players[index].isOnBoard = true
        }
        
        logGameEvent("Referee adjusted \(players[index].name) total score: \(oldScore) → \(players[index].totalScore)")
        return oldScore
    }
    
    /// Update a player's round score (referee action)
    /// Returns the old value for logging
    @discardableResult
    func setPlayerRoundScore(_ playerId: UUID, to newScore: Int) -> Int? {
        guard let index = players.firstIndex(where: { $0.id == playerId }) else { return nil }
        let oldScore = players[index].roundScore
        players[index].roundScore = max(0, newScore)
        
        logGameEvent("Referee adjusted \(players[index].name) round score: \(oldScore) → \(players[index].roundScore)")
        return oldScore
    }
    
    /// Get the minimum allowed winning score (must be above all player scores)
    var minimumAllowedWinningScore: Int {
        let maxPlayerScore = players.map { $0.totalScore }.max() ?? 0
        // Must be at least 1 point above the leader, with a minimum of 1000
        return max(1000, maxPlayerScore + 1)
    }
    
    /// Check if winning score can be decreased
    var canDecreaseWinningScore: Bool {
        let maxPlayerScore = players.map { $0.totalScore }.max() ?? 0
        return winningScore > maxPlayerScore + 1000 // Buffer of 1000
    }

    // MARK: - Player Management

    func reorderPlayers(from source: IndexSet, to destination: Int) {
        players.move(fromOffsets: source, toOffset: destination)

        // Update current player index if needed
        guard let sourceIndex = source.first else { return }

        if sourceIndex == currentPlayerIndex {
            // Current player was moved
            let newIndex = destination > sourceIndex ? destination - 1 : destination
            currentPlayerIndex = newIndex
        } else if sourceIndex < currentPlayerIndex && destination > currentPlayerIndex {
            // Player moved from before current to after current
            currentPlayerIndex = currentPlayerIndex - 1
        } else if sourceIndex > currentPlayerIndex && destination <= currentPlayerIndex {
            // Player moved from after current to before/at current
            currentPlayerIndex = currentPlayerIndex + 1
        }
    }

    func skipTurn() {
        guard let player = currentPlayer else { return }
        
        // Skip turn is irreversible - clear undo stack
        clearUndoStack()
        
        // Clear any pending farkle state when skipping
        if pendingFarkle {
            pendingFarkle = false
            farklePlayerName = ""
            farkleDice = []
        }

        // Skip turn without banking any points
        logGameEvent("\(player.name) skipped their turn")

        // Reset any accumulated scores for this turn
        if isManualMode {
            manualTurnScore = 0
            manualScoreHistory.removeAll()
        }

        nextPlayer()
    }
}

// MARK: - Supporting Types

struct GameHistoryEntry: Identifiable {
    let id = UUID()
    let type: EntryType
    let playerName: String
    let message: String
    let timestamp: Date

    enum EntryType {
        case gameEvent
        case turn
    }
}

struct GameStatistics {
    let totalTurns: Int
    let totalFarkles: Int
    let gameLength: TimeInterval
    let playerStats: [PlayerStatistics]
}

struct PlayerStatistics {
    let playerName: String
    let totalScore: Int
    let turnsPlayed: Int
    let farkleCount: Int
    let sixDiceFarkles: Int
    let averageScorePerTurn: Double
    let highestSingleTurn: Int

    init(player: Player) {
        self.playerName = player.name
        self.totalScore = player.totalScore
        self.turnsPlayed = player.gameHistory.count
        self.farkleCount = player.gameHistory.filter { $0.isFarkle }.count
        self.sixDiceFarkles = player.gameHistory.filter { $0.isSixDiceFarkle }.count

        let scoringTurns = player.gameHistory.filter { !$0.isFarkle }
        if !scoringTurns.isEmpty {
            self.averageScorePerTurn = Double(scoringTurns.reduce(0) { $0 + $1.score }) / Double(scoringTurns.count)
            self.highestSingleTurn = scoringTurns.max { $0.score < $1.score }?.score ?? 0
        } else {
            self.averageScorePerTurn = 0
            self.highestSingleTurn = 0
        }
    }
}
