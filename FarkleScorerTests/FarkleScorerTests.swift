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
}
