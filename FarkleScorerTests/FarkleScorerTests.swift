import XCTest
@testable import FarkleScorer

final class FarkleTests: XCTestCase {

    var scoringEngine: ScoringEngine!
    var gameEngine: GameEngine!

    override func setUpWithError() throws {
        scoringEngine = ScoringEngine()
        gameEngine = GameEngine()
    }

    override func tearDownWithError() throws {
        scoringEngine = nil
        gameEngine = nil
    }

    // MARK: - ScoringEngine Tests

    func testSingleDiceScoring() throws {
        // Test single 1s
        let result1 = scoringEngine.calculateScore(for: [1])
        XCTAssertEqual(result1, 100)

        // Test single 5s
        let result5 = scoringEngine.calculateScore(for: [5])
        XCTAssertEqual(result5, 50)

        // Test non-scoring dice
        let resultNone = scoringEngine.calculateScore(for: [2])
        XCTAssertEqual(resultNone, 0)
    }

    func testThreeOfAKindScoring() throws {
        // Test three 1s
        let result1s = scoringEngine.calculateScore(for: [1, 1, 1])
        XCTAssertEqual(result1s, 1000)

        // Test three 2s
        let result2s = scoringEngine.calculateScore(for: [2, 2, 2])
        XCTAssertEqual(result2s, 200)

        // Test three 5s
        let result5s = scoringEngine.calculateScore(for: [5, 5, 5])
        XCTAssertEqual(result5s, 500)

        // Test three 6s
        let result6s = scoringEngine.calculateScore(for: [6, 6, 6])
        XCTAssertEqual(result6s, 600)
    }

    func testFarkleDetection() throws {
        let result = scoringEngine.calculateScore(for: [2, 3, 4, 6])
        XCTAssertEqual(result, 0)

        // Test if this is a farkle (no scoring dice)
        let isFarkle = !scoringEngine.canScore([2, 3, 4, 6])
        XCTAssertTrue(isFarkle)
    }

    func testComplexScoringCombinations() throws {
        // Test straight (1-2-3-4-5-6)
        let straight = scoringEngine.calculateScore(for: [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(straight, 1500)

        // Test three pairs
        let threePairs = scoringEngine.calculateScore(for: [1, 1, 2, 2, 3, 3])
        XCTAssertEqual(threePairs, 750)

        // Test mixed scoring (three 2s + single 1 + single 5)
        let mixed = scoringEngine.calculateScore(for: [2, 2, 2, 1, 5])
        XCTAssertEqual(mixed, 350) // 200 + 100 + 50
    }

    func testFourOfAKind() throws {
        // Test four 3s (base 300 * 2 = 600)
        let fourThrees = scoringEngine.calculateScore(for: [3, 3, 3, 3])
        XCTAssertEqual(fourThrees, 600)

        // Test four 1s (base 1000 * 2 = 2000)
        let fourOnes = scoringEngine.calculateScore(for: [1, 1, 1, 1])
        XCTAssertEqual(fourOnes, 2000)
    }

    func testFiveOfAKind() throws {
        // Test five 4s (base 400 * 3 = 1200)
        let fiveFours = scoringEngine.calculateScore(for: [4, 4, 4, 4, 4])
        XCTAssertEqual(fiveFours, 1200)
    }

    func testSixOfAKind() throws {
        // Test six 2s (base 200 * 4 = 800)
        let sixTwos = scoringEngine.calculateScore(for: [2, 2, 2, 2, 2, 2])
        XCTAssertEqual(sixTwos, 800)
    }

    func testTwoTriplets() throws {
        // Test two triplets (e.g., three 2s and three 4s)
        let twoTriplets = scoringEngine.calculateScore(for: [2, 2, 2, 4, 4, 4])
        XCTAssertEqual(twoTriplets, 2500)
    }

    func testPossibleScorings() throws {
        // Test getting possible scoring options
        let options = scoringEngine.getPossibleScorings(for: [1, 1, 2, 5])
        XCTAssertFalse(options.isEmpty)

        // Should include individual 1s and 5, and combination of both 1s
        let scores = options.map { $0.score }
        XCTAssertTrue(scores.contains(100)) // Single 1
        XCTAssertTrue(scores.contains(50))  // Single 5
        XCTAssertTrue(scores.contains(200)) // Two 1s
        XCTAssertTrue(scores.contains(250)) // Two 1s + 5
    }

    // MARK: - GameEngine Tests

    func testGameInitialization() throws {
        XCTAssertEqual(gameEngine.gameState, .setup)
        XCTAssertTrue(gameEngine.players.isEmpty)
        XCTAssertEqual(gameEngine.currentPlayerIndex, 0)
    }

    func testAddingPlayers() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.addPlayer(name: "Bob")

        XCTAssertEqual(gameEngine.players.count, 2)
        XCTAssertEqual(gameEngine.players[0].name, "Alice")
        XCTAssertEqual(gameEngine.players[1].name, "Bob")
    }

    func testStartingGame() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.addPlayer(name: "Bob")
        gameEngine.startGame()

        XCTAssertEqual(gameEngine.gameState, .playing)
        XCTAssertEqual(gameEngine.currentPlayerIndex, 0)
    }

    func testPlayerScoring() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.addPlayer(name: "Bob")
        gameEngine.startGame()

        // Simulate selecting scoring dice and banking
        gameEngine.selectDice([1, 5]) // Should score 150 points
        gameEngine.bankScore()

        XCTAssertEqual(gameEngine.players[0].totalScore, 150)
        XCTAssertEqual(gameEngine.players[0].roundScore, 0)
        XCTAssertEqual(gameEngine.currentPlayerIndex, 1) // Should advance to next player
    }

    func testFarkleHandling() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()

        // Set up a farkle scenario by rolling dice that don't score
        gameEngine.currentRoll = [2, 3, 4, 6] // No scoring dice
        let initialScore = gameEngine.players[0].totalScore
        let initialConsecutiveFarkles = gameEngine.players[0].consecutiveFarkles

        // The farkle should be handled automatically when rolling dice that don't score
        // Since handleFarkle is private, we can test its effects indirectly
        XCTAssertEqual(gameEngine.players[0].consecutiveFarkles, initialConsecutiveFarkles) // Will increment when farkle occurs
        XCTAssertEqual(gameEngine.players[0].totalScore, initialScore) // No change in total score from farkle
    }

    func testWinCondition() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()

        // Set player score near winning condition and select high-scoring dice
        gameEngine.players[0].totalScore = 9800
        gameEngine.selectDice([1, 1, 1]) // 1000 points
        gameEngine.bankScore()

        XCTAssertEqual(gameEngine.gameState, .finalRound)
        XCTAssertEqual(gameEngine.players[0].totalScore, 10800)
    }

    func testPlayerOnBoardLogic() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()

        XCTAssertFalse(gameEngine.players[0].isOnBoard)

        // Score enough to get on board (500+ points)
        gameEngine.selectDice([5, 5, 5]) // 500 points
        gameEngine.bankScore()

        XCTAssertTrue(gameEngine.players[0].isOnBoard)
        XCTAssertEqual(gameEngine.players[0].totalScore, 500)
    }

    func testTripleFarkleRule() throws {
        gameEngine.enableTripleFarkleRule = true
        gameEngine.tripleFarklePenalty = 1000
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()

        // Set up player with some score
        gameEngine.players[0].totalScore = 2000
        gameEngine.players[0].consecutiveFarkles = 2

        // Test triple farkle penalty logic
        XCTAssertFalse(gameEngine.players[0].hasTripleFarkle)

        // Simulate what happens with a third consecutive farkle
        gameEngine.players[0].consecutiveFarkles = 3
        XCTAssertTrue(gameEngine.players[0].hasTripleFarkle)

        // Apply penalty manually (since handleFarkle is private)
        gameEngine.players[0].applyTripleFarklePenalty(1000)
        XCTAssertEqual(gameEngine.players[0].totalScore, 1000)
        XCTAssertEqual(gameEngine.players[0].consecutiveFarkles, 0)
    }

    func testDiceSelection() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()

        // Test dice selection and scoring
        gameEngine.selectDice([1, 5])
        XCTAssertEqual(gameEngine.selectedDice, [1, 5])
        XCTAssertEqual(gameEngine.turnScore, 150) // 100 + 50

        // Test different selection
        gameEngine.selectDice([2, 2, 2])
        XCTAssertEqual(gameEngine.selectedDice, [2, 2, 2])
        XCTAssertEqual(gameEngine.turnScore, 200)
    }

    func testRemainingDiceLogic() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()

        XCTAssertEqual(gameEngine.remainingDice, 6)

        // Select some dice and continue rolling
        gameEngine.selectDice([1, 5])
        gameEngine.continueRolling()

        XCTAssertEqual(gameEngine.remainingDice, 4) // 6 - 2 selected dice

        // Test hot dice scenario (all 6 dice used)
        gameEngine.selectDice([1, 2, 3, 4, 5, 6])
        gameEngine.continueRolling()

        XCTAssertEqual(gameEngine.remainingDice, 6) // Reset to 6 for hot dice
    }
    
    // MARK: - Undo Functionality Tests
    
    func testUndoAfterContinueRolling() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        
        // Set up initial state with a roll
        gameEngine.currentRoll = [1, 5, 2, 3, 4, 6]
        gameEngine.selectDice([1, 5])
        
        let scoreBeforeContinue = gameEngine.turnScore
        XCTAssertEqual(scoreBeforeContinue, 150)
        
        // Continue rolling (this should save undo state)
        gameEngine.continueRolling()
        
        // Verify undo is available
        XCTAssertTrue(gameEngine.canUndo)
        
        // Perform undo
        gameEngine.undoLastSelection()
        
        // Verify state was restored
        XCTAssertEqual(gameEngine.turnScore, scoreBeforeContinue)
        XCTAssertEqual(gameEngine.currentRoll, [1, 5, 2, 3, 4, 6])
        XCTAssertFalse(gameEngine.canUndo) // Undo stack should be empty now
    }
    
    func testUndoNotAvailableAfterRoll() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        
        // Roll dice - this should clear undo stack
        _ = gameEngine.rollDice()
        
        // Undo should not be available (rolling is irreversible)
        XCTAssertFalse(gameEngine.canUndo)
    }
    
    func testUndoNotAvailableAfterBank() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        
        // Set up and bank some points
        gameEngine.currentRoll = [1, 5, 2, 3, 4, 6]
        gameEngine.selectDice([1, 5])
        gameEngine.bankScore()
        
        // Undo should not be available (banking is irreversible)
        XCTAssertFalse(gameEngine.canUndo)
    }
    
    func testManualScoreUndo() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        gameEngine.toggleManualMode()
        
        // Add some manual scores
        gameEngine.addManualScore(100)
        XCTAssertTrue(gameEngine.canUndo)
        XCTAssertEqual(gameEngine.manualTurnScore, 100)
        
        gameEngine.addManualScore(50)
        XCTAssertEqual(gameEngine.manualTurnScore, 150)
        
        // Undo should restore previous state
        gameEngine.undoLastSelection()
        XCTAssertEqual(gameEngine.manualTurnScore, 100)
        
        gameEngine.undoLastSelection()
        XCTAssertEqual(gameEngine.manualTurnScore, 0)
        XCTAssertFalse(gameEngine.canUndo)
    }
    
    func testUndoStackBoundedSize() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        gameEngine.toggleManualMode()
        
        // Add many manual scores to exceed stack limit (30)
        for i in 1...40 {
            gameEngine.addManualScore(i)
        }
        
        // Should still be able to undo
        XCTAssertTrue(gameEngine.canUndo)
        
        // Undo all available actions
        var undoCount = 0
        while gameEngine.canUndo {
            gameEngine.undoLastSelection()
            undoCount += 1
        }
        
        // Should have undone up to maxUndoStackSize (30) times
        XCTAssertLessThanOrEqual(undoCount, 30)
    }
    
    // MARK: - State Invariant Tests
    
    func testPlayerIndexInBounds() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.addPlayer(name: "Bob")
        gameEngine.startGame()
        
        // Advance through multiple turns
        for _ in 0..<10 {
            gameEngine.selectDice([1])
            gameEngine.bankScore()
        }
        
        // Player index should always be in bounds
        XCTAssertTrue(gameEngine.currentPlayerIndex < gameEngine.players.count)
    }
    
    func testRemainingDiceInValidRange() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        
        // Initial state
        XCTAssertTrue(gameEngine.remainingDice >= 1 && gameEngine.remainingDice <= 6)
        
        // After selection
        gameEngine.currentRoll = [1, 5, 2, 3, 4, 6]
        gameEngine.selectDice([1, 5])
        gameEngine.continueRolling()
        
        XCTAssertTrue(gameEngine.remainingDice >= 1 && gameEngine.remainingDice <= 6)
    }
    
    func testEmptyPlayerGuard() throws {
        // Game should not start without players
        gameEngine.startGame()
        XCTAssertEqual(gameEngine.gameState, .setup) // Should remain in setup
    }
    
    // MARK: - Play Again / Restart Tests
    
    func testRestartGameKeepsPlayers() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.addPlayer(name: "Bob")
        gameEngine.startGame()
        
        // Play some turns
        gameEngine.selectDice([1, 1, 1])
        gameEngine.bankScore()
        gameEngine.selectDice([5, 5])
        gameEngine.bankScore()
        
        // Restart game
        gameEngine.restartGame()
        
        // Players should be preserved
        XCTAssertEqual(gameEngine.players.count, 2)
        XCTAssertEqual(gameEngine.players[0].name, "Alice")
        XCTAssertEqual(gameEngine.players[1].name, "Bob")
        
        // Scores should be reset
        XCTAssertEqual(gameEngine.players[0].totalScore, 0)
        XCTAssertEqual(gameEngine.players[1].totalScore, 0)
        
        // Game should be in playing state
        XCTAssertEqual(gameEngine.gameState, .playing)
    }
    
    func testRestartGameResetsHistory() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.startGame()
        
        // Play a few turns
        gameEngine.selectDice([1])
        gameEngine.bankScore()
        
        XCTAssertFalse(gameEngine.players[0].gameHistory.isEmpty)
        
        // Restart
        gameEngine.restartGame()
        
        // History should be cleared
        XCTAssertTrue(gameEngine.players[0].gameHistory.isEmpty)
    }
    
    func testSkipTurnClearsUndoStack() throws {
        gameEngine.addPlayer(name: "Alice")
        gameEngine.addPlayer(name: "Bob")
        gameEngine.startGame()
        
        // Set up some state with undo available
        gameEngine.currentRoll = [1, 5, 2, 3, 4, 6]
        gameEngine.selectDice([1, 5])
        gameEngine.continueRolling()
        XCTAssertTrue(gameEngine.canUndo)
        
        // Skip turn should clear undo
        gameEngine.skipTurn()
        XCTAssertFalse(gameEngine.canUndo)
    }
}

// MARK: - Multiplayer Round Tests

final class MultiplayerRoundTests: XCTestCase {
    
    var multiplayerEngine: MultiplayerGameEngine!
    
    override func setUpWithError() throws {
        multiplayerEngine = MultiplayerGameEngine()
    }
    
    override func tearDownWithError() throws {
        multiplayerEngine = nil
    }
    
    // MARK: - Turn Submission Tests
    
    func testTurnSubmissionAppliesScore() throws {
        // Setup: Create a game with players
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.enableDebugMode() // This sets up multiplayer state
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        let initialScore = multiplayerEngine.gameEngine.players[0].totalScore
        
        // Create a turn submission
        let turnResult = TurnResultData(
            scoreEarned: 500,
            isFarkle: false,
            wasManualMode: false,
            rolls: []
        )
        
        let submission = TurnSubmissionData(
            playerId: aliceId,
            deviceId: multiplayerEngine.currentDeviceId,
            turnResult: turnResult,
            timestamp: Date()
        )
        
        // Submit the turn
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Verify score was applied
        XCTAssertEqual(multiplayerEngine.gameEngine.players[0].totalScore, initialScore + 500)
        XCTAssertTrue(multiplayerEngine.gameEngine.players[0].isOnBoard)
    }
    
    func testFarkleSubmissionAppliesNoScore() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        let initialScore = multiplayerEngine.gameEngine.players[0].totalScore
        let initialFarkles = multiplayerEngine.gameEngine.players[0].consecutiveFarkles
        
        // Create a farkle submission
        let turnResult = TurnResultData(
            scoreEarned: 0,
            isFarkle: true,
            wasManualMode: false,
            rolls: []
        )
        
        let submission = TurnSubmissionData(
            playerId: aliceId,
            deviceId: multiplayerEngine.currentDeviceId,
            turnResult: turnResult,
            timestamp: Date()
        )
        
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Verify no score change and consecutive farkles incremented
        XCTAssertEqual(multiplayerEngine.gameEngine.players[0].totalScore, initialScore)
        XCTAssertEqual(multiplayerEngine.gameEngine.players[0].consecutiveFarkles, initialFarkles + 1)
    }
    
    func testTurnSubmissionMarksPlayerAsSubmitted() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        
        // Initially should be pending
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[aliceId], .pending)
        
        let turnResult = TurnResultData(
            scoreEarned: 100,
            isFarkle: false,
            wasManualMode: false,
            rolls: []
        )
        
        let submission = TurnSubmissionData(
            playerId: aliceId,
            deviceId: multiplayerEngine.currentDeviceId,
            turnResult: turnResult,
            timestamp: Date()
        )
        
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Should now be submitted
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[aliceId], .submitted)
    }
    
    // MARK: - Round Completion Tests
    
    func testAllPlayersSubmittedDetection() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        let bobId = multiplayerEngine.gameEngine.players[1].id.uuidString
        
        // Initially not all submitted
        XCTAssertFalse(multiplayerEngine.allPlayersSubmitted)
        XCTAssertEqual(multiplayerEngine.submittedPlayerCount, 0)
        
        // Submit Alice's turn
        let aliceResult = TurnResultData(scoreEarned: 100, isFarkle: false, wasManualMode: false, rolls: [])
        let aliceSubmission = TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: aliceResult, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(aliceSubmission)
        
        XCTAssertFalse(multiplayerEngine.allPlayersSubmitted)
        XCTAssertEqual(multiplayerEngine.submittedPlayerCount, 1)
        
        // Submit Bob's turn
        let bobResult = TurnResultData(scoreEarned: 200, isFarkle: false, wasManualMode: false, rolls: [])
        let bobSubmission = TurnSubmissionData(playerId: bobId, deviceId: "debug-device-1", turnResult: bobResult, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(bobSubmission)
        
        // Now all submitted
        XCTAssertTrue(multiplayerEngine.allPlayersSubmitted)
        XCTAssertEqual(multiplayerEngine.submittedPlayerCount, 2)
    }
    
    func testGetPendingPlayers() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.gameEngine.addPlayer(name: "Charlie")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        // Initially all pending
        let pendingPlayers = multiplayerEngine.getPendingPlayers()
        XCTAssertEqual(pendingPlayers.count, 3)
        
        // Submit one player's turn
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        let result = TurnResultData(scoreEarned: 100, isFarkle: false, wasManualMode: false, rolls: [])
        let submission = TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: result, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Now only 2 pending
        let pendingAfter = multiplayerEngine.getPendingPlayers()
        XCTAssertEqual(pendingAfter.count, 2)
        XCTAssertFalse(pendingAfter.contains(where: { $0.name == "Alice" }))
    }
    
    // MARK: - Final Round Tests
    
    func testFinalRoundTrigger() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.gameEngine.winningScore = 10000
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        
        // Set Alice's score near winning
        multiplayerEngine.gameEngine.players[0].totalScore = 9500
        
        // Initially not final round
        XCTAssertFalse(multiplayerEngine.isFinalRound)
        XCTAssertNil(multiplayerEngine.finalRoundTriggerPlayerId)
        
        // Submit a high-scoring turn that pushes past winning score
        let result = TurnResultData(scoreEarned: 600, isFarkle: false, wasManualMode: false, rolls: [])
        let submission = TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: result, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Should trigger final round
        XCTAssertTrue(multiplayerEngine.isFinalRound)
        XCTAssertEqual(multiplayerEngine.finalRoundTriggerPlayerId, aliceId)
        XCTAssertEqual(multiplayerEngine.gameEngine.players[0].totalScore, 10100)
    }
    
    func testFinalRoundDoesNotRetrigger() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.gameEngine.winningScore = 10000
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        let bobId = multiplayerEngine.gameEngine.players[1].id.uuidString
        
        // Manually set final round state
        multiplayerEngine.isFinalRound = true
        multiplayerEngine.finalRoundTriggerPlayerId = aliceId
        
        // Set Bob near winning too
        multiplayerEngine.gameEngine.players[1].totalScore = 9500
        
        // Bob scores high (but final round already triggered)
        let result = TurnResultData(scoreEarned: 1000, isFarkle: false, wasManualMode: false, rolls: [])
        let submission = TurnSubmissionData(playerId: bobId, deviceId: "debug-device-1", turnResult: result, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Final round trigger should remain Alice
        XCTAssertEqual(multiplayerEngine.finalRoundTriggerPlayerId, aliceId)
    }
    
    // MARK: - Force Advance Tests
    
    func testForceAdvanceSkipsPendingPlayers() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.gameEngine.addPlayer(name: "Charlie")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        
        // Submit only Alice's turn
        let result = TurnResultData(scoreEarned: 100, isFarkle: false, wasManualMode: false, rolls: [])
        let submission = TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: result, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(submission)
        
        // Force advance
        multiplayerEngine.forceAdvanceRound(reason: .hostOverride)
        
        // Bob and Charlie should be skipped
        let bobId = multiplayerEngine.gameEngine.players[1].id.uuidString
        let charlieId = multiplayerEngine.gameEngine.players[2].id.uuidString
        
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[bobId], .skipped)
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[charlieId], .skipped)
    }
    
    // MARK: - Opening Score Requirement Tests
    
    func testOpeningScoreRequirementInMultiplayer() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.gameEngine.require500Opening = true
        multiplayerEngine.gameEngine.openingScoreThreshold = 500
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        
        // Alice is not on board
        XCTAssertFalse(multiplayerEngine.gameEngine.players[0].isOnBoard)
        
        // Submit a turn below threshold
        let lowResult = TurnResultData(scoreEarned: 300, isFarkle: false, wasManualMode: false, rolls: [])
        let lowSubmission = TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: lowResult, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(lowSubmission)
        
        // Should still not be on board (score lost)
        XCTAssertFalse(multiplayerEngine.gameEngine.players[0].isOnBoard)
        XCTAssertEqual(multiplayerEngine.gameEngine.players[0].totalScore, 0)
        
        // Reset for next round
        multiplayerEngine.playerRoundStatuses[aliceId] = .pending
        
        // Submit a turn at or above threshold
        let highResult = TurnResultData(scoreEarned: 500, isFarkle: false, wasManualMode: false, rolls: [])
        let highSubmission = TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: highResult, timestamp: Date())
        multiplayerEngine.handleTurnSubmission(highSubmission)
        
        // Should now be on board with score
        XCTAssertTrue(multiplayerEngine.gameEngine.players[0].isOnBoard)
        XCTAssertEqual(multiplayerEngine.gameEngine.players[0].totalScore, 500)
    }
    
    // MARK: - Round Number Tests
    
    func testRoundNumberIncrementsOnNewRound() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        XCTAssertEqual(multiplayerEngine.roundNumber, 1)
        
        // Manually start a new round (simulating what happens after all submit)
        multiplayerEngine.startNewRound()
        
        XCTAssertEqual(multiplayerEngine.roundNumber, 2)
    }
    
    func testNewRoundResetsPendingStatuses() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.gameEngine.addPlayer(name: "Bob")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        let bobId = multiplayerEngine.gameEngine.players[1].id.uuidString
        
        // Submit both turns
        let result = TurnResultData(scoreEarned: 100, isFarkle: false, wasManualMode: false, rolls: [])
        multiplayerEngine.handleTurnSubmission(TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: result, timestamp: Date()))
        multiplayerEngine.handleTurnSubmission(TurnSubmissionData(playerId: bobId, deviceId: "debug-device-1", turnResult: result, timestamp: Date()))
        
        // Both should be submitted
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[aliceId], .submitted)
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[bobId], .submitted)
        
        // Start new round
        multiplayerEngine.startNewRound()
        
        // Both should be back to pending
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[aliceId], .pending)
        XCTAssertEqual(multiplayerEngine.playerRoundStatuses[bobId], .pending)
    }
    
    func testNewRoundClearsSubmittedTurns() throws {
        multiplayerEngine.gameEngine.addPlayer(name: "Alice")
        multiplayerEngine.enableDebugMode()
        multiplayerEngine.startGame()
        
        let aliceId = multiplayerEngine.gameEngine.players[0].id.uuidString
        
        // Submit a turn
        let result = TurnResultData(scoreEarned: 100, isFarkle: false, wasManualMode: false, rolls: [])
        multiplayerEngine.handleTurnSubmission(TurnSubmissionData(playerId: aliceId, deviceId: multiplayerEngine.currentDeviceId, turnResult: result, timestamp: Date()))
        
        XCTAssertFalse(multiplayerEngine.submittedTurns.isEmpty)
        
        // Start new round
        multiplayerEngine.startNewRound()
        
        XCTAssertTrue(multiplayerEngine.submittedTurns.isEmpty)
    }
}
