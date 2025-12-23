//
//  PlayerStrip.swift
//  FarkleScorer
//
//  Flip7-inspired player grid for the main game loop.
//  Shows all players at a glance with large names, scores, and clear turn indication.
//  For >8 players, provides collapsible/scrollable behavior to preserve screen space.
//

import SwiftUI

/// Flip7-style player grid for the active game screen.
/// Features a collapsible design with a compact quick-jump row (collapsed) or full grid (expanded).
struct PlayerStrip: View {
    let players: [Player]
    let currentPlayerIndex: Int
    let winningScore: Int
    let require500Opening: Bool
    let openingScoreThreshold: Int
    let onSelectPlayer: ((Int) -> Void)?
    
    /// State for expand/collapse
    @State private var isExpanded = false
    
    init(
        players: [Player],
        currentPlayerIndex: Int,
        winningScore: Int,
        require500Opening: Bool = false,
        openingScoreThreshold: Int = 500,
        onSelectPlayer: ((Int) -> Void)? = nil
    ) {
        self.players = players
        self.currentPlayerIndex = currentPlayerIndex
        self.winningScore = winningScore
        self.require500Opening = require500Opening
        self.openingScoreThreshold = openingScoreThreshold
        self.onSelectPlayer = onSelectPlayer
    }
    
    private var columns: [GridItem] {
        // 2 columns for 2-4 players, 3 for 5-6, 4 for 7+
        let count = players.count <= 4 ? 2 : (players.count <= 6 ? 3 : 4)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }
    
    /// Max height for the expanded grid when in collapsible mode (~2 rows of tiles)
    private var expandedMaxHeight: CGFloat {
        // Each tile is roughly 100pt tall (padding + content), plus spacing
        // Allow ~2.5 rows to be visible before scrolling kicks in
        return 260
    }
    
    var body: some View {
        collapsiblePlayerStrip
    }
    
    // MARK: - Collapsible Player Strip
    
    private var collapsiblePlayerStrip: some View {
        VStack(spacing: 8) {
            // Header with expand/collapse control
            collapsibleHeader
            
            if isExpanded {
                // Expanded: vertically scrollable grid with capped height
                expandedGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Collapsed: horizontal quick-jump row
                collapsedQuickJumpRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
    
    private var collapsibleHeader: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text("Players")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text("(\(players.count))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(isExpanded ? "Collapse" : "Expand")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse player list" : "Expand player list")
        .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") the player grid")
    }
    
    private var expandedGrid: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    PlayerStripTile(
                        player: player,
                        color: PlayerColorHelper.color(for: index),
                        isCurrentPlayer: index == currentPlayerIndex,
                        winningScore: winningScore,
                        require500Opening: require500Opening,
                        openingScoreThreshold: openingScoreThreshold,
                        onTap: {
                            onSelectPlayer?(index)
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: expandedMaxHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
    }
    
    private var collapsedQuickJumpRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        PlayerStripMiniTile(
                            player: player,
                            color: PlayerColorHelper.color(for: index),
                            isCurrentPlayer: index == currentPlayerIndex,
                            onTap: {
                                onSelectPlayer?(index)
                            }
                        )
                        .id(index)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .onAppear {
                // Scroll to current player on appear
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(currentPlayerIndex, anchor: .center)
                }
            }
            .onChange(of: currentPlayerIndex) { _, newIndex in
                // Auto-scroll when turn changes
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
    }
}

// MARK: - Mini Tile for Collapsed Quick-Jump Row

/// Compact player tile for the collapsed horizontal quick-jump row
struct PlayerStripMiniTile: View {
    let player: Player
    let color: Color
    let isCurrentPlayer: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Player name (compact)
                Text(player.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isCurrentPlayer ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                // Score (compact, single line)
                Text(player.displayScore, format: .number)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCurrentPlayer ? .white : .primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 70)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentPlayer ? color : color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrentPlayer ? color : color.opacity(0.25), lineWidth: isCurrentPlayer ? 0 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isCurrentPlayer {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 6, height: 6)
                        .padding(4)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCurrentPlayer)
        .accessibilityLabel("Jump to \(player.name), score \(player.displayScore)")
        .accessibilityHint("Double tap to select this player")
    }
}

// MARK: - Full-Size Tile

/// Individual player tile in the strip - Flip7-inspired with large name and score
struct PlayerStripTile: View {
    let player: Player
    let color: Color
    let isCurrentPlayer: Bool
    let winningScore: Int
    let require500Opening: Bool
    let openingScoreThreshold: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var statusIcon: String {
        if player.consecutiveFarkles >= 2 {
            return "exclamationmark.triangle.fill"
        } else if !player.isOnBoard && require500Opening {
            return "arrow.up.circle"
        } else if player.totalScore >= winningScore * 8 / 10 {
            return "flag.checkered"
        }
        return ""
    }
    
    private var statusColor: Color {
        if player.consecutiveFarkles >= 2 {
            return .red
        } else if !player.isOnBoard && require500Opening {
            return .orange
        } else {
            return .green
        }
    }
    
    private var roundScoreText: String? {
        if player.roundScore > 0 {
            return "+\(player.roundScore)"
        }
        return nil
    }
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: 6) {
                // Player name - LARGE and readable
                Text(player.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isCurrentPlayer ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                // Total score - prominent, single line with scaling
                Text(player.displayScore, format: .number)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCurrentPlayer ? .white : .primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                
                // Round score preview (if any) or status indicator
                HStack(spacing: 4) {
                    if let roundScore = roundScoreText {
                        Text(roundScore)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(isCurrentPlayer ? .white.opacity(0.85) : FarkleTheme.buttonSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else if !statusIcon.isEmpty {
                        Image(systemName: statusIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(isCurrentPlayer ? .white.opacity(0.8) : statusColor)
                    } else {
                        // Reserve space even when empty to prevent layout shifts
                        Text(" ")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .opacity(0)
                    }
                }
                .frame(height: 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isCurrentPlayer ? color : color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCurrentPlayer ? color : color.opacity(0.25), lineWidth: isCurrentPlayer ? 0 : 2)
            )
            .overlay(alignment: .topTrailing) {
                // Current turn indicator
                if isCurrentPlayer {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(6)
                }
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrentPlayer)
    }
}

// MARK: - Previews

#Preview("4 Players") {
    VStack {
        PlayerStrip(
            players: [
                Player(name: "Alice", requiresOpeningScore: true, openingScoreThreshold: 500),
                Player(name: "Bob", requiresOpeningScore: true, openingScoreThreshold: 500),
                Player(name: "Charlie", requiresOpeningScore: true, openingScoreThreshold: 500),
                Player(name: "Diana", requiresOpeningScore: true, openingScoreThreshold: 500)
            ],
            currentPlayerIndex: 1,
            winningScore: 10000,
            require500Opening: true
        )
        .padding()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("12 Players") {
    VStack {
        PlayerStrip(
            players: (1...12).map { i in
                var p = Player(name: "Player \(i)", requiresOpeningScore: true, openingScoreThreshold: 500)
                p.totalScore = Int.random(in: 0...5000)
                p.isOnBoard = p.totalScore >= 500
                return p
            },
            currentPlayerIndex: 5,
            winningScore: 10000,
            require500Opening: true
        )
        .padding()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
