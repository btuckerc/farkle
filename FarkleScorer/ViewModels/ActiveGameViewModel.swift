//
//  ActiveGameViewModel.swift
//  FarkleScorer
//
//  iOS 17+ Observation-based view model for the main game loop.
//  Provides fine-grained state updates to minimize SwiftUI re-renders.
//

import SwiftUI
import Combine

/// Fine-grained observable view model for the active game loop.
/// Uses iOS 17's Observation framework for efficient SwiftUI updates.
@Observable
final class ActiveGameViewModel {
    // MARK: - Current Player State (changes on turn change)
    var currentPlayerName: String = ""
    var currentPlayerIndex: Int = 0
    var currentPlayerTotalScore: Int = 0
    var currentPlayerRoundScore: Int = 0
    var currentPlayerIsOnBoard: Bool = false
    var currentPlayerConsecutiveFarkles: Int = 0
    
    // MARK: - All Players (for PlayerStrip)
    var players: [Player] = []
    
    // MARK: - Dice State (changes on roll/selection)
    var currentRoll: [Int] = []
    var selectedDice: [Int] = []
    var remainingDice: Int = 6
    var turnScore: Int = 0
    
    // MARK: - Game Flow State
    var gameState: GameEngine.GameState = .setup
    var isManualMode: Bool = false
    var winningScore: Int = 10000
    var require500Opening: Bool = true
    var openingScoreThreshold: Int = 500
    
    // MARK: - Farkle/Warning State
    var pendingFarkle: Bool = false
    var farklePlayerName: String = ""
    var farkleDice: [Int] = []
    var canUndo: Bool = false
    var invalidSelectionWarning: Bool = false
    
    // MARK: - Manual Mode State
    var manualTurnScore: Int = 0
    var manualScoreHistory: [Int] = []
    
    // MARK: - Underlying Engine Reference
    private weak var gameEngine: GameEngine?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    /// Bind to a GameEngine instance. Call this once when the view appears.
    func bind(to engine: GameEngine) {
        self.gameEngine = engine
        
        // Subscribe to all relevant publishers
        setupBindings(engine)
    }
    
    // MARK: - Private Binding Setup
    
    private func setupBindings(_ engine: GameEngine) {
        // Cancel any existing subscriptions
        cancellables.removeAll()
        
        // Players array
        engine.$players
            .receive(on: RunLoop.main)
            .sink { [weak self] players in
                self?.players = players
                self?.updateCurrentPlayerState(from: engine)
            }
            .store(in: &cancellables)
        
        // Current player index
        engine.$currentPlayerIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateCurrentPlayerState(from: engine)
            }
            .store(in: &cancellables)
        
        // Dice state
        engine.$currentRoll
            .receive(on: RunLoop.main)
            .assign(to: \.currentRoll, on: self)
            .store(in: &cancellables)
        
        engine.$selectedDice
            .receive(on: RunLoop.main)
            .assign(to: \.selectedDice, on: self)
            .store(in: &cancellables)
        
        engine.$remainingDice
            .receive(on: RunLoop.main)
            .assign(to: \.remainingDice, on: self)
            .store(in: &cancellables)
        
        engine.$turnScore
            .receive(on: RunLoop.main)
            .assign(to: \.turnScore, on: self)
            .store(in: &cancellables)
        
        // Game state
        engine.$gameState
            .receive(on: RunLoop.main)
            .assign(to: \.gameState, on: self)
            .store(in: &cancellables)
        
        engine.$isManualMode
            .receive(on: RunLoop.main)
            .assign(to: \.isManualMode, on: self)
            .store(in: &cancellables)
        
        engine.$winningScore
            .receive(on: RunLoop.main)
            .assign(to: \.winningScore, on: self)
            .store(in: &cancellables)
        
        engine.$require500Opening
            .receive(on: RunLoop.main)
            .assign(to: \.require500Opening, on: self)
            .store(in: &cancellables)
        
        engine.$openingScoreThreshold
            .receive(on: RunLoop.main)
            .assign(to: \.openingScoreThreshold, on: self)
            .store(in: &cancellables)
        
        // Farkle/warning state
        engine.$pendingFarkle
            .receive(on: RunLoop.main)
            .assign(to: \.pendingFarkle, on: self)
            .store(in: &cancellables)
        
        engine.$farklePlayerName
            .receive(on: RunLoop.main)
            .assign(to: \.farklePlayerName, on: self)
            .store(in: &cancellables)
        
        engine.$farkleDice
            .receive(on: RunLoop.main)
            .assign(to: \.farkleDice, on: self)
            .store(in: &cancellables)
        
        engine.$canUndo
            .receive(on: RunLoop.main)
            .assign(to: \.canUndo, on: self)
            .store(in: &cancellables)
        
        engine.$invalidSelectionWarning
            .receive(on: RunLoop.main)
            .assign(to: \.invalidSelectionWarning, on: self)
            .store(in: &cancellables)
        
        // Manual mode state
        engine.$manualTurnScore
            .receive(on: RunLoop.main)
            .assign(to: \.manualTurnScore, on: self)
            .store(in: &cancellables)
        
        engine.$manualScoreHistory
            .receive(on: RunLoop.main)
            .assign(to: \.manualScoreHistory, on: self)
            .store(in: &cancellables)
        
        // Initial sync
        updateCurrentPlayerState(from: engine)
    }
    
    private func updateCurrentPlayerState(from engine: GameEngine) {
        currentPlayerIndex = engine.currentPlayerIndex
        
        if let player = engine.currentPlayer {
            currentPlayerName = player.name
            currentPlayerTotalScore = player.totalScore
            currentPlayerRoundScore = player.roundScore
            currentPlayerIsOnBoard = player.isOnBoard
            currentPlayerConsecutiveFarkles = player.consecutiveFarkles
        } else {
            currentPlayerName = ""
            currentPlayerTotalScore = 0
            currentPlayerRoundScore = 0
            currentPlayerIsOnBoard = false
            currentPlayerConsecutiveFarkles = 0
        }
    }
    
    // MARK: - Computed Helpers
    
    var isPlaying: Bool {
        gameState == .playing || gameState == .finalRound
    }
    
    var needsPointsToGetOnBoard: Bool {
        require500Opening && !currentPlayerIsOnBoard
    }
    
    var pointsNeededToGetOnBoard: Int {
        max(0, openingScoreThreshold - currentPlayerRoundScore)
    }
    
    var canRoll: Bool {
        currentRoll.isEmpty && isPlaying
    }
    
    // MARK: - Actions (passthrough to engine)
    
    func rollDice() {
        guard let engine = gameEngine else { return }
        _ = engine.rollDice()
    }
    
    func selectDice(_ dice: [Int]) {
        gameEngine?.selectDice(dice)
    }
    
    func bankScore() {
        gameEngine?.bankScore()
    }
    
    func continueRolling() {
        gameEngine?.continueRolling()
    }
    
    func undoLastSelection() {
        gameEngine?.undoLastSelection()
    }
    
    func acknowledgeFarkle() {
        gameEngine?.acknowledgeFarkle()
    }
    
    func skipTurn() {
        gameEngine?.skipTurn()
    }
    
    func skipPlayer() {
        gameEngine?.skipPlayer()
    }
    
    func goToPreviousPlayer() {
        gameEngine?.goToPreviousPlayer()
    }
    
    func jumpToPlayer(at index: Int) {
        gameEngine?.jumpToPlayer(at: index)
    }
    
    func toggleManualMode() {
        gameEngine?.toggleManualMode()
    }
    
    func resetGame() {
        gameEngine?.resetGame()
    }
    
    func canPlayerBank() -> Bool {
        gameEngine?.canPlayerBank() ?? false
    }
    
    func canPlayerContinueRolling() -> Bool {
        gameEngine?.canPlayerContinueRolling() ?? false
    }
    
    // Manual mode actions
    func addManualScore(_ score: Int) {
        gameEngine?.addManualScore(score)
    }
    
    func bankManualScore() {
        gameEngine?.bankManualScore()
    }
    
    func farkleManualTurn() {
        gameEngine?.farkleManualTurn()
    }
}

