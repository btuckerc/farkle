import Foundation

/// Centralized store for scoring rules with persistence and defaults
/// Single source of truth for dice combination point values
struct ScoringRulesStore: Codable, Equatable {
    
    // MARK: - Single Dice Points
    var single1Points: Int
    var single5Points: Int
    
    // MARK: - Three of a Kind Points
    var three1sPoints: Int
    var three2sPoints: Int
    var three3sPoints: Int
    var three4sPoints: Int
    var three5sPoints: Int
    var three6sPoints: Int
    
    // MARK: - Special Combinations
    var threePairPoints: Int
    var straightPoints: Int
    var twoTripletsPoints: Int
    
    // MARK: - Multipliers for 4+, 5+, 6 of a kind
    var fourOfAKindMultiplier: Double
    var fiveOfAKindMultiplier: Double
    var sixOfAKindMultiplier: Double
    
    // MARK: - Official Defaults (Farkle standard rules)
    
    static let officialDefaults = ScoringRulesStore(
        single1Points: 100,
        single5Points: 50,
        three1sPoints: 1000,
        three2sPoints: 200,
        three3sPoints: 300,
        three4sPoints: 400,
        three5sPoints: 500,
        three6sPoints: 600,
        threePairPoints: 750,
        straightPoints: 1500,
        twoTripletsPoints: 2500,
        fourOfAKindMultiplier: 2.0,
        fiveOfAKindMultiplier: 3.0,
        sixOfAKindMultiplier: 4.0
    )
    
    /// Initialize with official defaults
    init() {
        self = Self.officialDefaults
    }
    
    /// Full initializer
    init(
        single1Points: Int,
        single5Points: Int,
        three1sPoints: Int,
        three2sPoints: Int,
        three3sPoints: Int,
        three4sPoints: Int,
        three5sPoints: Int,
        three6sPoints: Int,
        threePairPoints: Int,
        straightPoints: Int,
        twoTripletsPoints: Int,
        fourOfAKindMultiplier: Double,
        fiveOfAKindMultiplier: Double,
        sixOfAKindMultiplier: Double
    ) {
        self.single1Points = single1Points
        self.single5Points = single5Points
        self.three1sPoints = three1sPoints
        self.three2sPoints = three2sPoints
        self.three3sPoints = three3sPoints
        self.three4sPoints = three4sPoints
        self.three5sPoints = three5sPoints
        self.three6sPoints = three6sPoints
        self.threePairPoints = threePairPoints
        self.straightPoints = straightPoints
        self.twoTripletsPoints = twoTripletsPoints
        self.fourOfAKindMultiplier = fourOfAKindMultiplier
        self.fiveOfAKindMultiplier = fiveOfAKindMultiplier
        self.sixOfAKindMultiplier = sixOfAKindMultiplier
    }
    
    // MARK: - Computed Properties
    
    /// Check if any value differs from official defaults
    var isCustomized: Bool {
        self != Self.officialDefaults
    }
    
    /// Get three-of-a-kind base score for a die value
    func threeOfAKindBase(for value: Int) -> Int {
        switch value {
        case 1: return three1sPoints
        case 2: return three2sPoints
        case 3: return three3sPoints
        case 4: return three4sPoints
        case 5: return three5sPoints
        case 6: return three6sPoints
        default: return value * 100
        }
    }
    
    /// Dictionary representation for ScoringEngine compatibility
    var threeOfAKindBaseDict: [Int: Int] {
        [
            1: three1sPoints,
            2: three2sPoints,
            3: three3sPoints,
            4: three4sPoints,
            5: three5sPoints,
            6: three6sPoints
        ]
    }
    
    /// Convert to ScoringEngine.ScoringRules for use in calculations
    func toScoringRules() -> ScoringEngine.ScoringRules {
        ScoringEngine.ScoringRules(
            single1Points: single1Points,
            single5Points: single5Points,
            threePairPoints: threePairPoints,
            straightPoints: straightPoints,
            twoTripletsPoints: twoTripletsPoints,
            three1sPoints: three1sPoints,
            enableTripleFarkleRule: true, // Controlled separately by GameEngine
            tripleFarklePenalty: 1000,    // Controlled separately by GameEngine
            threeOfAKindBase: threeOfAKindBaseDict,
            fourOfAKindMultiplier: fourOfAKindMultiplier,
            fiveOfAKindMultiplier: fiveOfAKindMultiplier,
            sixOfAKindMultiplier: sixOfAKindMultiplier
        )
    }
    
    // MARK: - Persistence
    
    private static let storageKey = "farkle_scoring_rules"
    
    /// Load saved rules from UserDefaults, or return defaults
    static func load() -> ScoringRulesStore {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(ScoringRulesStore.self, from: data) else {
            return ScoringRulesStore()
        }
        return stored
    }
    
    /// Save current rules to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
    
    /// Reset to official defaults and clear storage
    static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    // MARK: - Field Metadata for UI
    
    struct FieldInfo {
        let key: WritableKeyPath<ScoringRulesStore, Int>
        let label: String
        let range: ClosedRange<Int>
        let defaultValue: Int
        let step: Int
    }
    
    static let singleDiceFields: [FieldInfo] = [
        FieldInfo(key: \.single1Points, label: "Single 1", range: 25...500, defaultValue: 100, step: 25),
        FieldInfo(key: \.single5Points, label: "Single 5", range: 10...250, defaultValue: 50, step: 10)
    ]
    
    static let threeOfAKindFields: [FieldInfo] = [
        FieldInfo(key: \.three1sPoints, label: "Three 1s", range: 300...3000, defaultValue: 1000, step: 100),
        FieldInfo(key: \.three2sPoints, label: "Three 2s", range: 50...1000, defaultValue: 200, step: 50),
        FieldInfo(key: \.three3sPoints, label: "Three 3s", range: 100...1500, defaultValue: 300, step: 50),
        FieldInfo(key: \.three4sPoints, label: "Three 4s", range: 100...2000, defaultValue: 400, step: 50),
        FieldInfo(key: \.three5sPoints, label: "Three 5s", range: 150...2500, defaultValue: 500, step: 50),
        FieldInfo(key: \.three6sPoints, label: "Three 6s", range: 200...3000, defaultValue: 600, step: 50)
    ]
    
    static let specialCombinationFields: [FieldInfo] = [
        FieldInfo(key: \.threePairPoints, label: "Three Pairs", range: 250...2500, defaultValue: 750, step: 50),
        FieldInfo(key: \.straightPoints, label: "Straight (1-6)", range: 500...5000, defaultValue: 1500, step: 100),
        FieldInfo(key: \.twoTripletsPoints, label: "Two Triplets", range: 1000...6000, defaultValue: 2500, step: 100)
    ]
}

