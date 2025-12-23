import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case midnight = "Midnight"
    case sunset = "Sunset"
    case forest = "Forest"
    case ocean = "Ocean"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .sunset: return .light
        case .dark, .midnight, .forest, .ocean: return .dark
        }
    }
    
    var accentColor: Color {
        switch self {
        case .system, .light, .dark: return .blue
        case .midnight: return .indigo
        case .sunset: return .orange
        case .forest: return .green
        case .ocean: return .cyan
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .midnight: return "moon.stars.fill"
        case .sunset: return "sunset.fill"
        case .forest: return "leaf.fill"
        case .ocean: return "water.waves"
        }
    }
    
    // MARK: - Theme Colors (used by FarkleTheme)
    
    /// Primary button color (e.g., Bank Score)
    var buttonPrimary: Color {
        switch self {
        case .system, .light, .dark: return Color(red: 0.2, green: 0.6, blue: 0.2)
        case .midnight: return Color(red: 0.4, green: 0.4, blue: 0.8)
        case .sunset: return Color(red: 0.9, green: 0.5, blue: 0.2)
        case .forest: return Color(red: 0.2, green: 0.6, blue: 0.3)
        case .ocean: return Color(red: 0.1, green: 0.6, blue: 0.7)
        }
    }
    
    /// Secondary button color (e.g., Keep Rolling)
    var buttonSecondary: Color {
        buttonPrimary.opacity(0.85)
    }
    
    /// Danger/destructive button color
    var buttonDanger: Color {
        switch self {
        case .system, .light, .dark, .midnight, .forest, .ocean:
            return Color(red: 0.85, green: 0.25, blue: 0.25)
        case .sunset:
            return Color(red: 0.75, green: 0.2, blue: 0.2)
        }
    }
    
    /// Selected dice highlight color
    var diceSelected: Color {
        switch self {
        case .system, .light, .dark: return Color(red: 0.0, green: 0.5, blue: 0.9)
        case .midnight: return Color(red: 0.5, green: 0.5, blue: 1.0)
        case .sunset: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .forest: return Color(red: 0.2, green: 0.7, blue: 0.4)
        case .ocean: return Color(red: 0.2, green: 0.7, blue: 0.9)
        }
    }
    
    /// Scoring dice highlight color
    var diceScoring: Color {
        switch self {
        case .system, .light, .dark: return Color(red: 0.1, green: 0.7, blue: 0.1)
        case .midnight: return Color(red: 0.4, green: 0.6, blue: 0.9)
        case .sunset: return Color(red: 0.9, green: 0.6, blue: 0.1)
        case .forest: return Color(red: 0.1, green: 0.8, blue: 0.3)
        case .ocean: return Color(red: 0.1, green: 0.8, blue: 0.7)
        }
    }
    
    /// Invalid dice highlight color
    var diceInvalid: Color {
        Color(red: 0.9, green: 0.6, blue: 0.1)
    }
}

@main
struct FarkleScorerApp: App {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    
    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedTheme.colorScheme)
                .tint(selectedTheme.accentColor)
        }
    }
}
