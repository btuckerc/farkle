import SwiftUI

/// Winning score option wrapper for chip selector
struct WinningScoreChip: Hashable, Identifiable {
    let id: Int
    let value: Int
    
    var displayName: String {
        value.formatted()
    }
    
    var icon: String {
        "target"
    }
    
    static let allOptions: [WinningScoreChip] = [
        WinningScoreChip(id: 0, value: 5000),
        WinningScoreChip(id: 1, value: 7500),
        WinningScoreChip(id: 2, value: 10000),
        WinningScoreChip(id: 3, value: 12500),
        WinningScoreChip(id: 4, value: 15000)
    ]
}

/// Opening score option wrapper
struct OpeningScoreChip: Hashable, Identifiable {
    let id: Int
    let value: Int
    
    var displayName: String {
        "\(value)"
    }
    
    var icon: String {
        "flag.fill"
    }
    
    static let allOptions: [OpeningScoreChip] = [
        OpeningScoreChip(id: 0, value: 350),
        OpeningScoreChip(id: 1, value: 500),
        OpeningScoreChip(id: 2, value: 750),
        OpeningScoreChip(id: 3, value: 1000)
    ]
}

/// Penalty option wrapper
struct PenaltyChip: Hashable, Identifiable {
    let id: Int
    let value: Int
    
    var displayName: String {
        "\(value)"
    }
    
    var icon: String {
        "exclamationmark.triangle.fill"
    }
    
    static let allOptions: [PenaltyChip] = [
        PenaltyChip(id: 0, value: 500),
        PenaltyChip(id: 1, value: 1000),
        PenaltyChip(id: 2, value: 1500)
    ]
}

