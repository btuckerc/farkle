import SwiftUI

struct GameSetupView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var newPlayerName = ""
    @State private var showingRules = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Streamlined Header (context-focused, no redundant app name)
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("New Game")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    Text("Configure your game")
                                        .farkleSection()
                                }

                                Spacer()
                            }
                            .padding(.top, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .background(Color(.systemBackground))

                        VStack(spacing: 24) {
                            // Players Section (Flip7-style card)
                            PlayersCard(gameEngine: gameEngine, canEdit: true)

                            // Scoring Customization Section (new)
                            ScoringCustomizationSection(gameEngine: gameEngine)

                            // Game Rules Configuration (moved to bottom)
                            GameRulesSection(gameEngine: gameEngine)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for start button
                    }
                }

                // Fixed Start Game Button
                VStack(spacing: 0) {
                    Divider()

                    StartGameSection(gameEngine: gameEngine)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRules = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingRules) {
            FarkleRulesView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(gameEngine: gameEngine)
        }
    }
}

struct ScoringCustomizationSection: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isExpanded = false
    @State private var showingScoringCustomization = false

    var body: some View {
        FarkleCard {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(spacing: 12) {
                        Text("Customize point values for different dice combinations to create house rules or balance gameplay.")
                            .farkleCaption()
                            .padding(.top, 8)

                        Button(action: { showingScoringCustomization = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                Text("Open Scoring Editor")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.top, 12)
                },
                label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scoring Customization")
                                .farkleSection()

                            Text(isExpanded ? "Tap to hide options" : "Tap to customize point values")
                                .farkleCaption()
                        }

                        Spacer()
                    }
                }
            )
        }
        .sheet(isPresented: $showingScoringCustomization) {
            ScoringCustomizationView(gameEngine: gameEngine)
        }
    }
}

struct GameRulesSection: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isExpanded = false
    
    private var selectedWinningScore: WinningScoreChip? {
        WinningScoreChip.allOptions.first { $0.value == gameEngine.winningScore }
    }
    
    private var selectedOpeningScore: OpeningScoreChip? {
        OpeningScoreChip.allOptions.first { $0.value == gameEngine.openingScoreThreshold }
    }
    
    private var selectedPenalty: PenaltyChip? {
        PenaltyChip.allOptions.first { $0.value == gameEngine.tripleFarklePenalty }
    }

    var body: some View {
        FarkleCard {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(spacing: 20) {
                        // Winning Score
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Winning Score")
                                .farkleSection()
                            
                            SimpleChips(
                                options: WinningScoreChip.allOptions,
                                selectedOption: selectedWinningScore,
                                onSelect: { chip in
                                    gameEngine.winningScore = chip.value
                                },
                                labelForOption: { $0.displayName },
                                iconForOption: { $0.icon }
                            )
                        }

                        Divider()

                        // Opening Score Requirement
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Require Opening Score", isOn: $gameEngine.require500Opening)
                                .font(.system(size: 17, weight: .medium, design: .rounded))

                            if gameEngine.require500Opening {
                                SimpleChips(
                                    options: OpeningScoreChip.allOptions,
                                    selectedOption: selectedOpeningScore,
                                    onSelect: { chip in
                                        gameEngine.openingScoreThreshold = chip.value
                                    },
                                    labelForOption: { $0.displayName },
                                    iconForOption: { $0.icon }
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Divider()

                        // Triple Farkle Rule
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Triple Farkle Penalty", isOn: $gameEngine.enableTripleFarkleRule)
                                .font(.system(size: 17, weight: .medium, design: .rounded))

                            if gameEngine.enableTripleFarkleRule {
                                SimpleChips(
                                    options: PenaltyChip.allOptions,
                                    selectedOption: selectedPenalty,
                                    onSelect: { chip in
                                        gameEngine.tripleFarklePenalty = chip.value
                                    },
                                    labelForOption: { $0.displayName },
                                    iconForOption: { $0.icon }
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.top, 12)
                },
                label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Game Rules")
                                .farkleSection()

                            Text(isExpanded ? "Tap to hide options" : "Tap to customize game settings")
                                .farkleCaption()
                        }

                        Spacer()
                    }
                }
            )
        }
    }
}

struct QuickRulesSection: View {
    @Binding var showingRules: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Reference")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                RuleItem(icon: "1.circle.fill", text: "1 = 100 points")
                RuleItem(icon: "5.circle.fill", text: "5 = 50 points")
                RuleItem(icon: "3.circle", text: "Three of a kind = value × 100")
                RuleItem(icon: "arrow.right.circle", text: "Three 1s = 1,000 points")
                RuleItem(icon: "exclamationmark.triangle", text: "No scoring dice = Farkle!")
            }

            Button(action: { showingRules = true }) {
                HStack {
                    Image(systemName: "book.circle")
                    Text("View Complete Rules")
                }
                .foregroundColor(.accentColor)
                .farkleBody()
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(15)
    }
}

struct RuleItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
        }
    }
}

struct StartGameSection: View {
    @ObservedObject var gameEngine: GameEngine

    var canStartGame: Bool {
        gameEngine.players.count >= 1
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                gameEngine.startGame()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Game")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canStartGame)
            .opacity(canStartGame ? 1.0 : 0.6)

            if !canStartGame {
                Text("Add at least 1 player to start")
                    .farkleCaption()
                    .foregroundColor(.red)
            }
        }
    }
}

struct FarkleRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Scoring
                    RulesSection(title: "Basic Scoring") {
                        ScoringRule("Single 1", "100 points")
                        ScoringRule("Single 5", "50 points")
                        ScoringRule("Three 1s", "1,000 points")
                        ScoringRule("Three 2s", "200 points")
                        ScoringRule("Three 3s", "300 points")
                        ScoringRule("Three 4s", "400 points")
                        ScoringRule("Three 5s", "500 points")
                        ScoringRule("Three 6s", "600 points")
                    }

                    // Advanced Scoring
                    RulesSection(title: "Advanced Scoring") {
                        ScoringRule("Four of a kind", "2× three of a kind")
                        ScoringRule("Five of a kind", "3× three of a kind")
                        ScoringRule("Six of a kind", "4× three of a kind")
                        ScoringRule("Straight (1-2-3-4-5-6)", "1,500 points")
                                                    ScoringRule("Three pairs", "750 points")
                        ScoringRule("Two triplets", "2,500 points")
                    }

                    // Game Rules
                    RulesSection(title: "Game Rules") {
                        RuleDescription("Players take turns rolling 6 dice to score points")
                        RuleDescription("Must select at least one scoring die each roll")
                        RuleDescription("Can bank points or continue rolling for more")
                        RuleDescription("If no scoring dice are rolled, you 'Farkle' and lose your turn")
                        RuleDescription("First player to reach the winning score starts the final round")
                        RuleDescription("All other players get one final turn to beat the high score")
                    }

                    // Optional Rules
                    RulesSection(title: "Optional Rules") {
                        RuleDescription("Opening Score: Must score minimum points to get 'on the board'")
                        RuleDescription("Triple Farkle: Three farkles in a row incurs a penalty")
                        RuleDescription("Hot Dice: When all 6 dice score, roll all 6 again")
                    }
                }
                .padding()
            }
            .navigationTitle("Farkle Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RulesSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        FarkleCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .farkleSection()

                content
            }
        }
    }
}

struct ScoringRule: View {
    let combination: String
    let points: String

    init(_ combination: String, _ points: String) {
        self.combination = combination
        self.points = points
    }

    var body: some View {
        HStack {
            Text(combination)
                .fontWeight(.medium)

            Spacer()

            Text(points)
                .foregroundColor(.accentColor)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }
}

struct RuleDescription: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.accentColor)
                .fontWeight(.bold)

            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    GameSetupView(gameEngine: GameEngine())
}
