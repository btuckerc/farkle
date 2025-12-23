//
//  SettingsView.swift
//  FarkleScorer
//
//  Unified settings screen modeled after Flip 7's structure.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme // Track system appearance changes
    
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    @AppStorage("playerPalette") private var playerPaletteRaw: String = PlayerPalette.vibrant.rawValue
    @AppStorage("hapticFeedback") private var hapticFeedbackEnabled: Bool = true
    @AppStorage("requireHoldToConfirm") private var requireHoldToConfirm: Bool = true
    
    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }
    
    private var selectedPalette: PlayerPalette {
        PlayerPalette(rawValue: playerPaletteRaw) ?? .vibrant
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    OptionChips(
                        options: Array(AppTheme.allCases),
                        selectedOption: selectedTheme,
                        onSelect: { theme in
                            appTheme = theme.rawValue
                        },
                        labelForOption: { $0.rawValue },
                        iconForOption: { $0.icon },
                        colorForOption: { $0.accentColor }
                    )
                    .padding(.vertical, 4)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose a color scheme for the app")
                }
                
                // Player Palette Section
                Section {
                    OptionChips(
                        options: Array(PlayerPalette.allCases),
                        selectedOption: selectedPalette,
                        onSelect: { palette in
                            playerPaletteRaw = palette.rawValue
                        },
                        labelForOption: { $0.displayName },
                        iconForOption: { $0.icon },
                        previewColorsForOption: { palette in
                            PlayerColorResolver.previewColors(palette: palette)
                        }
                    )
                    .padding(.vertical, 4)
                } header: {
                    Text("Player Colors")
                } footer: {
                    Text("Choose a color palette for player tiles")
                }
                
                // Feedback Section
                Section {
                    Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                } header: {
                    Text("Feedback")
                }
                
                // Accessibility Section
                Section {
                    Toggle("Require Hold to Confirm", isOn: $requireHoldToConfirm)
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text(requireHoldToConfirm 
                        ? "Bank, Skip, and Farkle require a press-and-hold gesture to prevent accidents"
                        : "Bank, Skip, and Farkle use a single tap with confirmation dialog")
                }
                
                // Players Section
                Section {
                    NavigationLink(destination: PlayerManagementView(gameEngine: gameEngine, canEdit: true)) {
                        HStack {
                            Text("Manage Players")
                            Spacer()
                            if let roster = PersistedRoster.load(), !roster.names.isEmpty {
                                Text("\(roster.names.count)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(gameEngine.players.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Players")
                } footer: {
                    Text("Edit and reorder your saved player roster")
                }
                
                // Scoring Section
                Section {
                    NavigationLink(destination: ScoringCustomizationView(gameEngine: gameEngine)) {
                        HStack {
                            Text("Customize Scoring")
                            Spacer()
                            Text("House Rules")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Scoring")
                } footer: {
                    Text("Adjust point values for dice combinations")
                }
                
                // Current Game Section (only show when game is active)
                if gameEngine.gameState != .setup {
                    Section {
                        // Winning Score
                        HStack {
                            Text("Winning Score")
                            Spacer()
                            Text("\(gameEngine.winningScore.formatted())")
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                        
                        // Opening Score Requirement
                        HStack {
                            Text("Opening Score Required")
                            Spacer()
                            Text(gameEngine.require500Opening ? "\(gameEngine.openingScoreThreshold)" : "No")
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                        
                        // Triple Farkle Penalty
                        HStack {
                            Text("Triple Farkle Penalty")
                            Spacer()
                            Text(gameEngine.enableTripleFarkleRule ? "\(gameEngine.tripleFarklePenalty)" : "No")
                                .foregroundStyle(.blue)
                                .fontWeight(.medium)
                        }
                        
                        // Game State
                        HStack {
                            Text("Game State")
                            Spacer()
                            Text(gameStateText)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Current Player
                        if let currentPlayer = gameEngine.currentPlayer {
                            HStack {
                                Text("Current Turn")
                                Spacer()
                                Text(currentPlayer.name)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Edit Rules Link
                        NavigationLink(destination: GameRulesEditorView(gameEngine: gameEngine)) {
                            Text("Edit Game Rules")
                        }
                    } header: {
                        Text("Current Game")
                    } footer: {
                        Text("Rules can be modified mid-game with some restrictions")
                    }
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Force List refresh when system color scheme changes (fixes Light→Dark not updating)
            .id(systemColorScheme)
        }
        .tint(selectedTheme.accentColor)
        // Apply theme policy at sheet level so it tracks system changes when theme is "System"
        .preferredColorScheme(selectedTheme.colorScheme)
    }
    
    private var gameStateText: String {
        switch gameEngine.gameState {
        case .setup: return "Setup"
        case .playing: return "Playing"
        case .finalRound: return "Final Round"
        case .gameOver: return "Game Over"
        }
    }
}

#Preview {
    SettingsView(gameEngine: GameEngine())
}

