//
//  PlayersCard.swift
//  FarkleScorer
//
//  Flip7-style players card for game setup - fast name entry with smooth keyboard behavior.
//

import SwiftUI

/// Flip7-style players card with fast name entry and persistence
struct PlayersCard: View {
    @ObservedObject var gameEngine: GameEngine
    let canEdit: Bool // For multiplayer clients that can't edit
    
    @State private var playerRows: [PlayerNameRow] = []
    @StateObject private var focusCoordinator = FocusCoordinator()
    @State private var hasLoadedRoster = false
    @State private var showingClearConfirmation = false
    @State private var showingPlayerManagement = false
    
    var body: some View {
        FarkleCard {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Players")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // Manage players button
                    Button(action: { showingPlayerManagement = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12))
                            Text("Manage")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(playerRows.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                .padding(.bottom, 8)
                
                // Preview grid (when we have players)
                if !playerRows.isEmpty {
                    PlayerPreviewGrid(
                        playerRows: playerRows,
                        playerColors: playerRows.enumerated().map { PlayerColorHelper.color(for: $0.offset) }
                    )
                    .padding(.bottom, 12)
                }
                
                // Player rows
                VStack(spacing: 0) {
                    ForEach($playerRows) { $row in
                        let index = indexOfRow(row.id)
                        
                        PlayerInputRow(
                            index: index,
                            row: $row,
                            isLast: index == playerRows.count - 1,
                            canDelete: canEdit && playerRows.count > 1,
                            canEdit: canEdit,
                            focusCoordinator: focusCoordinator,
                            onDelete: { removePlayer(rowId: row.id) },
                            onNameChanged: { saveChanges() }
                        )
                        
                        if index < playerRows.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: playerRows.count)
                    
                    // Add player row
                    if canEdit {
                        Divider()
                            .padding(.leading, 52)
                        
                        Button(action: addPlayer) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                
                                Text("Add Player")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(.blue)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Reset link
                if canEdit && (playerRows.count > 1 || playerRows.contains(where: { !$0.name.isEmpty })) {
                    Button(action: { showingClearConfirmation = true }) {
                        Text("Reset to Default")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .onChange(of: playerRows.map { $0.id }) { _, newIds in
            focusCoordinator.setOrder(newIds)
        }
        .onAppear {
            if !hasLoadedRoster {
                loadPersistedRoster()
                hasLoadedRoster = true
            }
            focusCoordinator.setOrder(playerRows.map { $0.id })
        }
        .fullScreenCover(isPresented: $showingClearConfirmation) {
            ConfirmationOverlay(
                title: "Clear All Players",
                message: "This will remove all players and reset to default. This action cannot be undone.",
                primaryActionTitle: "Clear All",
                primaryActionRole: .destructive,
                onPrimary: {
                    clearPlayers()
                },
                onDismiss: {
                    showingClearConfirmation = false
                }
            )
            .background(ClearBackgroundView())
        }
        .sheet(isPresented: $showingPlayerManagement) {
            NavigationView {
                PlayerManagementView(gameEngine: gameEngine, canEdit: canEdit)
            }
            .onDisappear {
                // Reload roster after management view closes
                loadPersistedRoster()
            }
        }
    }
    
    // MARK: - Roster Management
    
    private func loadPersistedRoster() {
        // First check if game engine already has players
        if !gameEngine.players.isEmpty {
            playerRows = gameEngine.players.map { PlayerNameRow(name: $0.name) }
        } else if let roster = PersistedRoster.load(), !roster.names.isEmpty {
            playerRows = roster.names.map { PlayerNameRow(name: $0) }
            syncToGameEngine()
        } else {
            // Start with 2 empty player slots
            playerRows = [PlayerNameRow(), PlayerNameRow()]
            syncToGameEngine()
        }
        focusCoordinator.setOrder(playerRows.map { $0.id })
    }
    
    private func indexOfRow(_ id: UUID) -> Int {
        playerRows.firstIndex(where: { $0.id == id }) ?? 0
    }
    
    private func addPlayer() {
        guard canEdit else { return }
        
        let newRow = PlayerNameRow()
        playerRows.append(newRow)
        focusCoordinator.setOrder(playerRows.map { $0.id })
        focusCoordinator.clearFocus()
        saveChanges()
    }
    
    private func removePlayer(rowId: UUID) {
        guard canEdit, playerRows.count > 1 else { return }
        
        guard let indexToRemove = playerRows.firstIndex(where: { $0.id == rowId }) else { return }
        
        let newFocusId: UUID?
        if focusCoordinator.focusedId == rowId {
            if indexToRemove > 0 {
                newFocusId = playerRows[indexToRemove - 1].id
            } else if playerRows.count > 1 {
                newFocusId = playerRows[1].id
            } else {
                newFocusId = nil
            }
        } else {
            newFocusId = focusCoordinator.focusedId
        }
        
        playerRows.remove(at: indexToRemove)
        focusCoordinator.setOrder(playerRows.map { $0.id })
        
        if let newFocusId = newFocusId {
            DispatchQueue.main.async {
                focusCoordinator.focus(newFocusId)
            }
        }
        
        saveChanges()
    }
    
    private func clearPlayers() {
        guard canEdit else { return }
        
        playerRows = [PlayerNameRow(), PlayerNameRow()]
        focusCoordinator.setOrder(playerRows.map { $0.id })
        focusCoordinator.clearFocus()
        PersistedRoster.clear()
        syncToGameEngine()
    }
    
    private func saveChanges() {
        let names = playerRows.map { $0.name.trimmingCharacters(in: .whitespaces) }
        PersistedRoster(names: names).save()
        syncToGameEngine()
    }
    
    private func syncToGameEngine() {
        // Smart sync: preserve player scores when possible
        // Only reset scores for truly new players
        
        let targetCount = playerRows.count
        let currentCount = gameEngine.players.count
        
        // First, adjust the number of players
        if targetCount > currentCount {
            // Add new players
            for i in currentCount..<targetCount {
                let row = playerRows[i]
                let name = row.name.trimmingCharacters(in: .whitespaces)
                let finalName = name.isEmpty ? "Player \(i + 1)" : name
                gameEngine.addPlayer(name: finalName)
            }
        } else if targetCount < currentCount {
            // Remove excess players from the end
            for _ in targetCount..<currentCount {
                if gameEngine.players.count > 1 {
                    gameEngine.players.removeLast()
                }
            }
        }
        
        // Now update names for existing players
        for (index, row) in playerRows.enumerated() {
            if index < gameEngine.players.count {
                let name = row.name.trimmingCharacters(in: .whitespaces)
                let finalName = name.isEmpty ? "Player \(index + 1)" : name
                gameEngine.players[index].name = finalName
            }
        }
        
        // Ensure current player index is valid
        if gameEngine.currentPlayerIndex >= gameEngine.players.count {
            gameEngine.currentPlayerIndex = 0
        }
    }
}

// MARK: - Player Input Row

struct PlayerInputRow: View {
    let index: Int
    @Binding var row: PlayerNameRow
    let isLast: Bool
    let canDelete: Bool
    let canEdit: Bool
    let focusCoordinator: FocusCoordinator
    let onDelete: () -> Void
    let onNameChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Player number badge
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            // Text field
            if canEdit {
                FocusableTextFieldRepresentable(
                    id: row.id,
                    placeholder: "Player \(index + 1)",
                    text: Binding(
                        get: { row.name },
                        set: { newValue in
                            row.name = newValue
                            onNameChanged()
                        }
                    ),
                    isLast: isLast,
                    coordinator: focusCoordinator
                )
                .frame(height: 44)
            } else {
                Text(row.name.isEmpty ? "Player \(index + 1)" : row.name)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(height: 44, alignment: .leading)
                
                Spacer()
            }
            
            // Delete button (only when > 1 player and can edit)
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(.systemGray3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Player Preview Grid

struct PlayerPreviewGrid: View {
    let playerRows: [PlayerNameRow]
    let playerColors: [Color]
    
    private var columns: [GridItem] {
        let count = playerRows.count <= 4 ? 2 : (playerRows.count <= 6 ? 3 : 4)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(playerRows.enumerated()), id: \.element.id) { index, row in
                PlayerPreviewTile(
                    name: row.name.isEmpty ? "Player \(index + 1)" : row.name,
                    color: playerColors[safe: index] ?? .blue
                )
            }
        }
    }
}

struct PlayerPreviewTile: View {
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            // Player name
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

