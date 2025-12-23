//
//  PlayerPalette.swift
//  FarkleScorer
//
//  Player color palette system ported from Flip7.
//  Provides golden-ratio hue stepping for distinct, visually appealing player colors.
//

import SwiftUI

enum PlayerPalette: String, CaseIterable {
    case vibrant = "Vibrant"
    case pastel = "Pastel"
    case deep = "Deep"
    case neon = "Neon"
    case earth = "Earth"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .vibrant: return "paintpalette.fill"
        case .pastel: return "paintbrush.fill"
        case .deep: return "moon.stars.fill"
        case .neon: return "bolt.fill"
        case .earth: return "mountain.2.fill"
        case .ocean: return "water.waves"
        case .sunset: return "sunset.fill"
        case .forest: return "leaf.fill"
        }
    }
}

struct PlayerColorResolver {
    // Golden ratio for even hue distribution
    private static let goldenRatio: Double = 0.618033988749895
    
    /// Generates distinct colors for any number of players
    /// Uses golden ratio hue stepping to ensure maximum color separation
    static func colors(count: Int, palette: PlayerPalette) -> [Color] {
        guard count > 0 else { return [] }
        
        var colors: [Color] = []
        for i in 0..<count {
            let hue = (Double(i) * goldenRatio).truncatingRemainder(dividingBy: 1.0)
            let color = colorForHue(hue, palette: palette)
            colors.append(color)
        }
        
        return colors
    }
    
    /// Returns preview colors for a palette (4-6 colors)
    static func previewColors(palette: PlayerPalette) -> [Color] {
        return colors(count: 6, palette: palette)
    }
    
    /// Returns a single color for a player index
    static func color(for index: Int, palette: PlayerPalette) -> Color {
        let hue = (Double(index) * goldenRatio).truncatingRemainder(dividingBy: 1.0)
        return colorForHue(hue, palette: palette)
    }
    
    /// Converts hue (0-1) to a Color based on palette settings
    private static func colorForHue(_ hue: Double, palette: PlayerPalette) -> Color {
        let (saturation, brightness): (Double, Double) = paletteSettings(for: palette)
        
        // Convert HSV to RGB
        let h = hue * 360.0
        let s = saturation
        let v = brightness
        
        let c = v * s
        let x = c * (1 - abs((h / 60.0).truncatingRemainder(dividingBy: 2.0) - 1))
        let m = v - c
        
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        
        if h < 60 {
            r = c; g = x; b = 0
        } else if h < 120 {
            r = x; g = c; b = 0
        } else if h < 180 {
            r = 0; g = c; b = x
        } else if h < 240 {
            r = 0; g = x; b = c
        } else if h < 300 {
            r = x; g = 0; b = c
        } else {
            r = c; g = 0; b = x
        }
        
        return Color(
            red: (r + m),
            green: (g + m),
            blue: (b + m)
        )
    }
    
    /// Returns saturation and brightness settings for each palette
    private static func paletteSettings(for palette: PlayerPalette) -> (saturation: Double, brightness: Double) {
        switch palette {
        case .vibrant:
            return (0.8, 0.9)  // High saturation, bright
        case .pastel:
            return (0.4, 0.95)  // Low saturation, very bright
        case .deep:
            return (0.9, 0.6)   // High saturation, darker
        case .neon:
            return (1.0, 0.9)   // Maximum saturation, bright
        case .earth:
            return (0.5, 0.7)   // Moderate saturation, medium brightness
        case .ocean:
            return (0.6, 0.8)   // Moderate-high saturation, bright
        case .sunset:
            return (0.7, 0.85)  // High saturation, bright
        case .forest:
            return (0.65, 0.65) // Moderate-high saturation, medium-dark
        }
    }
}

