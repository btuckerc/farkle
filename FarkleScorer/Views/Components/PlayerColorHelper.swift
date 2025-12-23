import SwiftUI

/// Helper for generating distinct player colors (simplified version of Flip7's golden ratio approach)
struct PlayerColorHelper {
    // Simple color palette for players
    private static let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint
    ]
    
    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}

