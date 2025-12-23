import Foundation

struct Player: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var totalScore: Int = 0
    var roundScore: Int = 0
    var isOnBoard: Bool = false // Has achieved minimum opening score
    var consecutiveFarkles: Int = 0
    var gameHistory: [Turn] = []

    // Rule configuration
    var requiresOpeningScore: Bool = true
    var openingScoreThreshold: Int = 500

    mutating func addTurn(_ turn: Turn) {
        gameHistory.append(turn)

        if turn.isFarkle {
            consecutiveFarkles += 1
            roundScore = 0
        } else {
            // Don't reset consecutive farkles here - only reset when banking
            roundScore += turn.score

            // Check if player gets on board
            if !isOnBoard && requiresOpeningScore {
                if roundScore >= openingScoreThreshold {
                    isOnBoard = true
                }
            } else if !requiresOpeningScore {
                isOnBoard = true
            }
        }
    }

    mutating func bankRoundScore() {
        if isOnBoard || !requiresOpeningScore {
            totalScore += roundScore
        }

        // Reset consecutive farkles only when successfully banking points
        if roundScore > 0 {
            consecutiveFarkles = 0
        }

        roundScore = 0
    }

    mutating func resetRoundScore() {
        roundScore = 0
    }

    mutating func applyTripleFarklePenalty(_ penalty: Int = 1000) {
        totalScore = max(0, totalScore - penalty)
        consecutiveFarkles = 0
    }

    var hasTripleFarkle: Bool {
        consecutiveFarkles >= 3
    }

    var totalFarkles: Int {
        gameHistory.filter { $0.isFarkle }.count
    }

    var sixDiceFarkles: Int {
        gameHistory.filter { $0.isSixDiceFarkle }.count
    }

    var displayScore: Int {
        isOnBoard || !requiresOpeningScore ? totalScore : 0
    }
}

struct Turn: Identifiable, Equatable {
    let id = UUID()
    let diceRolled: [Int]
    let selectedDice: [Int]
    let score: Int
    let isFarkle: Bool
    let isSixDiceFarkle: Bool // Track if this farkle was on a 6-dice roll
    let timestamp: Date = Date()

    init(diceRolled: [Int], selectedDice: [Int], score: Int, isFarkle: Bool = false) {
        self.diceRolled = diceRolled
        self.selectedDice = selectedDice
        self.score = score
        self.isFarkle = isFarkle || score == 0
        self.isSixDiceFarkle = (isFarkle || score == 0) && diceRolled.count == 6
    }
}
