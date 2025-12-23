//
//  GameOverOverlay.swift
//  FarkleScorer
//
//  Blocking custom overlay for game over state.
//  Shows winner info and provides New Game + Stats actions in the bottom action area.
//

import SwiftUI

struct GameOverOverlay: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isPresented = false
    @State private var showingScoreboard = false
    
    private var winner: Player? {
        gameEngine.getPlayerRanking().first
    }
    
    var body: some View {
        ZStack {
            // Dimmed backdrop - NOT dismissible (no onTapGesture)
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Winner announcement card
                VStack(spacing: 16) {
                    // Trophy icon
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    // Game Over title
                    Text("Game Over!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    // Winner message
                    if let winner = winner {
                        VStack(spacing: 4) {
                            Text("\(winner.name) Wins!")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(FarkleTheme.buttonPrimary)
                            
                            Text("\(winner.totalScore) points")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Divider
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Final Scores section
                    VStack(spacing: 8) {
                        Text("Final Scores")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        // All players ranked by score
                        ForEach(Array(gameEngine.getPlayerRanking().enumerated()), id: \.element.id) { index, player in
                            HStack(spacing: 12) {
                                // Rank badge
                                ZStack {
                                    Circle()
                                        .fill(rankColor(for: index).opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    
                                    if index == 0 {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(rankColor(for: index))
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(rankColor(for: index))
                                    }
                                }
                                
                                // Player name
                                Text(player.name)
                                    .font(.system(size: 16, weight: index == 0 ? .semibold : .regular, design: .rounded))
                                    .foregroundStyle(index == 0 ? .primary : .secondary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Score
                                Text("\(player.totalScore)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(index == 0 ? FarkleTheme.buttonPrimary : .secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                )
                .padding(.horizontal, 24)
                
                Spacer(minLength: 16)
                
                // Bottom action bar (same position as Roll Dice button)
                VStack(spacing: 12) {
                    // Play Again - keeps same players and rules
                    Button(action: {
                        HapticFeedback.success()
                        gameEngine.restartGame()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Play Again")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FarkleTheme.buttonPrimary)
                        .cornerRadius(12)
                    }
                    
                    // Secondary actions row
                    HStack(spacing: 12) {
                        // Stats button
                        Button(action: {
                            HapticFeedback.light()
                            showingScoreboard = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.number")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Stats")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(FarkleTheme.buttonPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FarkleTheme.buttonPrimary.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        // New Game button - goes to setup
                        Button(action: {
                            HapticFeedback.medium()
                            gameEngine.resetGame()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14, weight: .medium))
                                Text("New Game")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemFill))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
                .background(FarkleTheme.cardBackground)
                .cornerRadius(20)
                .shadow(color: FarkleTheme.shadowColor, radius: 8, x: 0, y: -2)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .scaleEffect(isPresented ? 1.0 : 0.95)
            .opacity(isPresented ? 1.0 : 0.0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = true
            }
        }
        .sheet(isPresented: $showingScoreboard) {
            ScoreboardView(gameEngine: gameEngine)
        }
    }
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return Color(.systemGray)
        case 2: return .orange
        default: return FarkleTheme.textSecondary
        }
    }
}

#Preview {
    GameOverOverlay(gameEngine: {
        let engine = GameEngine()
        engine.addPlayer(name: "Alice")
        engine.addPlayer(name: "Bob")
        engine.addPlayer(name: "Charlie")
        engine.addPlayer(name: "Diana")
        engine.players[0].totalScore = 10500
        engine.players[1].totalScore = 8200
        engine.players[2].totalScore = 6750
        engine.players[3].totalScore = 5100
        return engine
    }())
}

