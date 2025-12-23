import SwiftUI

/// Helper for generating distinct player colors using the Flip7-style palette system.
/// Reads the user's selected palette from UserDefaults and uses golden-ratio hue stepping.
struct PlayerColorHelper {
    /// Returns the currently selected palette from UserDefaults
    private static var currentPalette: PlayerPalette {
        let rawValue = UserDefaults.standard.string(forKey: "playerPalette") ?? PlayerPalette.vibrant.rawValue
        return PlayerPalette(rawValue: rawValue) ?? .vibrant
    }
    
    /// Returns a color for the given player index using the user's selected palette
    static func color(for index: Int) -> Color {
        PlayerColorResolver.color(for: index, palette: currentPalette)
    }
    
    /// Returns colors for an array of players
    static func colors(for count: Int) -> [Color] {
        PlayerColorResolver.colors(count: count, palette: currentPalette)
    }
}
