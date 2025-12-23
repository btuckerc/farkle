import Foundation

struct ScoringEngine {

    // MARK: - Scoring Configuration
    struct ScoringRules: Codable, Equatable {
        var single1Points: Int
        var single5Points: Int
        var threePairPoints: Int
        var straightPoints: Int // 1-2-3-4-5-6
        var twoTripletsPoints: Int
        var three1sPoints: Int
        var enableTripleFarkleRule: Bool
        var tripleFarklePenalty: Int

        // Three of a kind base scores
        var threeOfAKindBase: [Int: Int]

        // Four, five, six of a kind multipliers
        var fourOfAKindMultiplier: Double
        var fiveOfAKindMultiplier: Double
        var sixOfAKindMultiplier: Double
        
        /// Default initializer with official Farkle rules
        init() {
            self.single1Points = 100
            self.single5Points = 50
            self.threePairPoints = 750
            self.straightPoints = 1500
            self.twoTripletsPoints = 2500
            self.three1sPoints = 1000
            self.enableTripleFarkleRule = true
            self.tripleFarklePenalty = 1000
            self.threeOfAKindBase = [1: 1000, 2: 200, 3: 300, 4: 400, 5: 500, 6: 600]
            self.fourOfAKindMultiplier = 2.0
            self.fiveOfAKindMultiplier = 3.0
            self.sixOfAKindMultiplier = 4.0
        }
        
        /// Full initializer for custom rules
        init(
            single1Points: Int,
            single5Points: Int,
            threePairPoints: Int,
            straightPoints: Int,
            twoTripletsPoints: Int,
            three1sPoints: Int,
            enableTripleFarkleRule: Bool,
            tripleFarklePenalty: Int,
            threeOfAKindBase: [Int: Int],
            fourOfAKindMultiplier: Double,
            fiveOfAKindMultiplier: Double,
            sixOfAKindMultiplier: Double
        ) {
            self.single1Points = single1Points
            self.single5Points = single5Points
            self.threePairPoints = threePairPoints
            self.straightPoints = straightPoints
            self.twoTripletsPoints = twoTripletsPoints
            self.three1sPoints = three1sPoints
            self.enableTripleFarkleRule = enableTripleFarkleRule
            self.tripleFarklePenalty = tripleFarklePenalty
            self.threeOfAKindBase = threeOfAKindBase
            self.fourOfAKindMultiplier = fourOfAKindMultiplier
            self.fiveOfAKindMultiplier = fiveOfAKindMultiplier
            self.sixOfAKindMultiplier = sixOfAKindMultiplier
        }
    }

    let rules: ScoringRules

    init(rules: ScoringRules = ScoringRules()) {
        self.rules = rules
    }

    // MARK: - Main Scoring Function

    /// Calculate score for selected dice
    func calculateScore(for selectedDice: [Int]) -> Int {
        guard !selectedDice.isEmpty else { return 0 }

        let diceCount = countDice(selectedDice)
        var score = 0
        var usedDice = Array(repeating: 0, count: 7) // Index 0 unused, 1-6 for dice values

        // Check for special combinations first (highest priority)

        // Six of a kind
        for (value, count) in diceCount {
            if count == 6 {
                let baseScore = rules.threeOfAKindBase[value] ?? (value * 100)
                score += Int(Double(baseScore) * rules.sixOfAKindMultiplier)
                usedDice[value] = 6
                break
            }
        }

        // If no six of a kind, check five of a kind
        if score == 0 {
            for (value, count) in diceCount {
                if count == 5 {
                    let baseScore = rules.threeOfAKindBase[value] ?? (value * 100)
                    score += Int(Double(baseScore) * rules.fiveOfAKindMultiplier)
                    usedDice[value] = 5
                    break
                }
            }
        }

        // If no five of a kind, check four of a kind
        if score == 0 {
            for (value, count) in diceCount {
                if count == 4 {
                    let baseScore = rules.threeOfAKindBase[value] ?? (value * 100)
                    score += Int(Double(baseScore) * rules.fourOfAKindMultiplier)
                    usedDice[value] = 4
                    break
                }
            }
        }

        // Check for straight (1-2-3-4-5-6)
        if score == 0 && isStraight(selectedDice) {
            return rules.straightPoints
        }

        // Check for two triplets
        if score == 0 {
            let triplets = getTriplets(diceCount)
            if triplets.count == 2 {
                return rules.twoTripletsPoints
            }
        }

        // Check for three pairs
        if score == 0 && isThreePairs(diceCount) {
            return rules.threePairPoints
        }

        // If no special combinations found, score individual combinations
        if score == 0 {
            score = scoreRegularCombinations(diceCount: diceCount, usedDice: &usedDice)
        }

        return score
    }

    // MARK: - Helper Functions

    /// Count occurrences of each die value
    private func countDice(_ dice: [Int]) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for die in dice {
            counts[die, default: 0] += 1
        }
        return counts
    }

    /// Check if dice form a straight (1-2-3-4-5-6)
    private func isStraight(_ dice: [Int]) -> Bool {
        guard dice.count == 6 else { return false }
        let sortedDice = dice.sorted()
        return sortedDice == [1, 2, 3, 4, 5, 6]
    }

    /// Get all triplets from dice counts
    private func getTriplets(_ diceCount: [Int: Int]) -> [Int] {
        return diceCount.compactMap { (value, count) in
            count >= 3 ? value : nil
        }
    }

    /// Check if dice form three pairs
    private func isThreePairs(_ diceCount: [Int: Int]) -> Bool {
        let pairs = diceCount.values.filter { $0 >= 2 }

        // Exactly three pairs
        if pairs.count == 3 && pairs.allSatisfy({ $0 == 2 }) {
            return true
        }

        // Four of a kind plus a pair
        if pairs.count == 2 {
            let sortedCounts = pairs.sorted()
            return sortedCounts == [2, 4]
        }

        return false
    }

    /// Score regular combinations (three of a kind, singles)
    private func scoreRegularCombinations(diceCount: [Int: Int], usedDice: inout [Int]) -> Int {
        var score = 0

        // Score three of a kind first
        for (value, count) in diceCount {
            if count >= 3 && usedDice[value] == 0 {
                score += rules.threeOfAKindBase[value] ?? (value * 100)
                usedDice[value] = 3
            }
        }

        // Score remaining single 1s and 5s
        for (value, count) in diceCount {
            let remainingCount = count - usedDice[value]

            if value == 1 && remainingCount > 0 {
                score += remainingCount * rules.single1Points
            } else if value == 5 && remainingCount > 0 {
                score += remainingCount * rules.single5Points
            }
        }

        return score
    }

    // MARK: - Validation Functions

    /// Check if selected dice can score any points
    func canScore(_ dice: [Int]) -> Bool {
        return calculateScore(for: dice) > 0
    }

    /// Determine which dice indices can contribute to scoring combinations
    /// This enforces the official Farkle rule that only scoring dice can be selected
    func getScoringDiceIndices(for dice: [Int]) -> Set<Int> {
        guard !dice.isEmpty else { return Set<Int>() }

        var scoringIndices = Set<Int>()
        let diceCount = countDice(dice)

        // Check for special combinations first (all dice score)
        if dice.count == 6 && (isStraight(dice) || isThreePairs(diceCount) || getTriplets(diceCount).count == 2) {
            return Set(0..<dice.count) // All dice can be selected
        }

        // Check for multiple of same value (3+, 4+, 5+, 6 of a kind)
        for (value, count) in diceCount {
            if count >= 3 {
                // Find all indices of this value and mark them as scoring
                let indices = dice.enumerated().compactMap { index, die in
                    die == value ? index : nil
                }
                scoringIndices.formUnion(indices)
            }
        }

        // Check for individual 1s and 5s (only if not already part of a three+ of a kind)
        for (index, die) in dice.enumerated() {
            if (die == 1 || die == 5) && !scoringIndices.contains(index) {
                // This die is a scoring single 1 or 5
                scoringIndices.insert(index)
            }
        }

        return scoringIndices
    }

    /// Check if a specific die at an index can be part of a scoring combination
    func canDieScore(at index: Int, in dice: [Int]) -> Bool {
        guard index < dice.count else { return false }
        return getScoringDiceIndices(for: dice).contains(index)
    }

    /// Get all possible scoring combinations for given dice
    func getPossibleScorings(for dice: [Int]) -> [ScoringOption] {
        // Safety guards against invalid input
        guard !dice.isEmpty,
              dice.count <= 6,
              dice.allSatisfy({ $0 >= 1 && $0 <= 6 }) else {
            return []
        }

        var options: Set<ScoringOption> = []
        let diceCount = countDice(dice)

        // Generate meaningful scoring combinations based on actual dice counts
        let validCombinations = generateValidCombinations(dice: dice, diceCount: diceCount)

        for combination in validCombinations {
            // Skip empty combinations
            guard !combination.isEmpty else { continue }
            
            let score = calculateScore(for: combination)
            if score > 0 {
                let option = ScoringOption(
                    selectedDice: combination.sorted(),
                    score: score,
                    description: describeCombination(combination)
                )
                options.insert(option)
            }
        }

        // Sort by score (descending) and limit to top suggestions
        return Array(options).sorted { $0.score > $1.score }.prefix(6).map { $0 }
    }

    /// Generate valid combinations based on actual dice counts and scoring rules
    private func generateValidCombinations(dice: [Int], diceCount: [Int: Int]) -> [[Int]] {
        var combinations: [[Int]] = []

        // Add individual 1s and 5s
        for (value, count) in diceCount {
            if value == 1 || value == 5 {
                for i in 1...count {
                    combinations.append(Array(repeating: value, count: i))
                }
            }
        }

        // Add three or more of a kind
        for (value, count) in diceCount {
            if count >= 3 {
                for i in 3...count {
                    combinations.append(Array(repeating: value, count: i))
                }
            }
        }

        // Add combinations that mix singles with three of a kind
        for (threeValue, threeCount) in diceCount where threeCount >= 3 {
            let baseThreeOfKind = Array(repeating: threeValue, count: 3)

            // Add remaining 1s and 5s to three of a kind
            for (singleValue, singleCount) in diceCount {
                if (singleValue == 1 || singleValue == 5) && singleValue != threeValue {
                    for i in 1...singleCount {
                        let combination = baseThreeOfKind + Array(repeating: singleValue, count: i)
                        if combination.count <= dice.count {
                            combinations.append(combination)
                        }
                    }
                }
            }

            // If the three of a kind is 1s or 5s, add remaining singles of the same value
            if threeValue == 1 || threeValue == 5 {
                for i in 4...threeCount {
                    combinations.append(Array(repeating: threeValue, count: i))
                }
            }
        }

        // Add special combinations
        if dice.count == 6 {
            // Check for straight
            if isStraight(dice) {
                combinations.append(dice.sorted())
            }

            // Check for three pairs
            if isThreePairs(diceCount) {
                combinations.append(dice.sorted())
            }

            // Check for two triplets
            let triplets = getTriplets(diceCount)
            if triplets.count == 2 {
                combinations.append(dice.sorted())
            }
        }

        // Remove duplicates and ensure all combinations are valid subsets of the original dice
        var validCombinations: [[Int]] = []
        for combination in combinations {
            if isValidSubset(combination: combination, availableDice: dice) {
                validCombinations.append(combination.sorted())
            }
        }

        return Array(Set(validCombinations.map { $0 }))
    }

    /// Check if a combination is a valid subset of available dice
    private func isValidSubset(combination: [Int], availableDice: [Int]) -> Bool {
        let combinationCounts = countDice(combination)
        let availableCounts = countDice(availableDice)

        for (value, neededCount) in combinationCounts {
            if (availableCounts[value] ?? 0) < neededCount {
                return false
            }
        }
        return true
    }

    /// Validate if a selection is valid according to Farkle rules
    /// This enforces that you cannot break up scoring combinations (like three of a kind)
    func validateDiceSelection(_ selectedIndices: Set<Int>, for dice: [Int]) -> DiceSelectionValidation {
        guard !selectedIndices.isEmpty else {
            return DiceSelectionValidation(isValid: true, reason: nil, invalidIndices: [])
        }

        let selectedDice = selectedIndices.compactMap { (index: Int) -> Int? in
            guard index < dice.count else { return nil }
            return dice[index]
        }

        // If the selection scores points, check if it violates grouping rules
        if calculateScore(for: selectedDice) > 0 {
            return validateGroupingRules(selectedIndices: selectedIndices, dice: dice)
        }

        return DiceSelectionValidation(
            isValid: false,
            reason: "Selected dice do not form a valid scoring combination",
            invalidIndices: Array(selectedIndices)
        )
    }

        /// Check if selection violates grouping rules (e.g., breaking up three of a kind)
    private func validateGroupingRules(selectedIndices: Set<Int>, dice: [Int]) -> DiceSelectionValidation {
        let diceCount = countDice(dice)

        // Check each die value that has 3 or more occurrences
        for (value, totalCount) in diceCount where totalCount >= 3 {
            let allIndicesForValue = dice.enumerated().compactMap { index, die in
                die == value ? index : nil
            }

            let selectedIndicesForValue = allIndicesForValue.filter { selectedIndices.contains($0) }
            let notSelectedIndicesForValue = allIndicesForValue.filter { !selectedIndices.contains($0) }

            // If we have 3+ of this value, and some are selected but not all,
            // we need to check if this breaks the three-of-a-kind rule
            if selectedIndicesForValue.count > 0 && notSelectedIndicesForValue.count > 0 {
                // For non-scoring individual dice (2,3,4,6), you must take at least 3 together
                if value != 1 && value != 5 {
                    if selectedIndicesForValue.count < 3 {
                        let reason = "You have \(totalCount) \(value)s. You must select at least 3 together for \(rules.threeOfAKindBase[value] ?? value * 100) points, or deselect them all."
                        return DiceSelectionValidation(
                            isValid: false,
                            reason: reason,
                            invalidIndices: selectedIndicesForValue
                        )
                    }
                } else {
                    // For 1s and 5s, warn about suboptimal choices but don't prevent them
                    if totalCount == 3 && selectedIndicesForValue.count == 1 {
                        let threeOfKindPoints = rules.threeOfAKindBase[value] ?? (value * 100)
                        let singlePoints = value == 1 ? rules.single1Points : rules.single5Points
                        let reason = "Tip: You have three \(value)s. Taking all three gives \(threeOfKindPoints) points vs \(singlePoints) for one."
                        // This is just a tip, not an error - return as valid
                        return DiceSelectionValidation(isValid: true, reason: reason, invalidIndices: [])
                    }
                }
            }
        }

        return DiceSelectionValidation(isValid: true, reason: nil, invalidIndices: [])
    }

    /// Describe a scoring combination in human-readable form
    private func describeCombination(_ dice: [Int]) -> String {
        let diceCount = countDice(dice)
        var descriptions: [String] = []

        // Check for special combinations
        if isStraight(dice) {
            return "Straight (1-2-3-4-5-6)"
        }

        let triplets = getTriplets(diceCount)
        if triplets.count == 2 {
            return "Two Triplets"
        }

        if isThreePairs(diceCount) {
            return "Three Pairs"
        }

        // Check for multiple of a kind
        for (value, count) in diceCount.sorted(by: { $0.key < $1.key }) {
            if count >= 6 {
                descriptions.append("Six \(value)s")
            } else if count >= 5 {
                descriptions.append("Five \(value)s")
            } else if count >= 4 {
                descriptions.append("Four \(value)s")
            } else if count >= 3 {
                descriptions.append("Three \(value)s")
            } else if (value == 1 || value == 5) && count > 0 {
                let plural = count > 1 ? "s" : ""
                descriptions.append("\(count) \(value)\(plural)")
            }
        }

        return descriptions.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

struct DiceSelectionValidation {
    let isValid: Bool
    let reason: String?
    let invalidIndices: [Int]
}

struct ScoringOption: Identifiable, Hashable, Equatable {
    let id = UUID()
    let selectedDice: [Int]
    let score: Int
    let description: String
    
    /// Stable identifier based on content (for SwiftUI ForEach stability)
    var stableId: String {
        "\(selectedDice.sorted().map(String.init).joined())-\(score)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(selectedDice.sorted())
        hasher.combine(score)
    }

    static func == (lhs: ScoringOption, rhs: ScoringOption) -> Bool {
        return lhs.selectedDice.sorted() == rhs.selectedDice.sorted() && lhs.score == rhs.score
    }
}
