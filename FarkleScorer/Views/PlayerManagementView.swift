//
//  PlayerManagementView.swift
//  FarkleScorer
//
//  Dedicated player roster management screen (like Flip7's Settings → Manage Players).
//

import SwiftUI

struct PlayerManagementView: View {
    @ObservedObject var gameEngine: GameEngine
    let canEdit: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var playerRows: [PlayerNameRow] = []
    @StateObject private var focusCoordinator = FocusCoordinator()
    @State private var hasLoadedRoster = false
    
    var body: some View {
        List {
            // Preview section
            if !playerRows.isEmpty {
                Section {
                    PlayerManagementPreviewGrid(
                        playerRows: playerRows,
                        playerColors: playerRows.enumerated().map { PlayerColorHelper.color(for: $0.offset) }
                    )
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                } footer: {
                    Text("This is how players will appear in the game")
                }
            }
            
            // Edit section
            Section {
                ForEach($playerRows) { $row in
                    let index = indexOfRow(row.id)
                    HStack {
                        // Player number badge
                        ZStack {
                            Circle()
                                .fill(PlayerColorHelper.color(for: index).opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(PlayerColorHelper.color(for: index))
                        }
                        
                        if canEdit {
                            TextField("Player \(index + 1)", text: $row.name)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .onChange(of: row.name) { oldValue, newValue in
                                    // Enforce character limit
                                    if newValue.count > 20 {
                                        row.name = String(newValue.prefix(20))
                                    }
                                    saveChanges()
                                }
                        } else {
                            Text(row.name.isEmpty ? "Player \(index + 1)" : row.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text("Read-only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { source, destination in
                    guard canEdit else { return }
                    // Reorder both our local rows and the game engine players (preserving scores)
                    playerRows.move(fromOffsets: source, toOffset: destination)
                    gameEngine.players.move(fromOffsets: source, toOffset: destination)
                    focusCoordinator.setOrder(playerRows.map { $0.id })
                    
                    // Adjust current player index if needed
                    if let sourceIndex = source.first {
                        let destIndex = destination > sourceIndex ? destination - 1 : destination
                        if gameEngine.currentPlayerIndex == sourceIndex {
                            gameEngine.currentPlayerIndex = destIndex
                        } else if sourceIndex < gameEngine.currentPlayerIndex && destIndex >= gameEngine.currentPlayerIndex {
                            gameEngine.currentPlayerIndex -= 1
                        } else if sourceIndex > gameEngine.currentPlayerIndex && destIndex <= gameEngine.currentPlayerIndex {
                            gameEngine.currentPlayerIndex += 1
                        }
                    }
                    
                    // Save roster (names only)
                    let names = playerRows.map { $0.name.trimmingCharacters(in: .whitespaces) }
                    PersistedRoster(names: names).save()
                }
                .onDelete { indexSet in
                    guard canEdit, playerRows.count > 1 else { return }
                    
                    // Track current player before deletion
                    let currentPlayerBeforeDelete = gameEngine.currentPlayerIndex
                    let deletingCurrentPlayer = indexSet.contains(currentPlayerBeforeDelete)
                    
                    playerRows.remove(atOffsets: indexSet)
                    gameEngine.players.remove(atOffsets: indexSet)
                    focusCoordinator.setOrder(playerRows.map { $0.id })
                    
                    // Adjust current player index
                    if deletingCurrentPlayer {
                        gameEngine.currentPlayerIndex = min(currentPlayerBeforeDelete, gameEngine.players.count - 1)
                    } else if let deletedIndex = indexSet.first, deletedIndex < currentPlayerBeforeDelete {
                        gameEngine.currentPlayerIndex = max(0, currentPlayerBeforeDelete - indexSet.count)
                    }
                    
                    // Save roster (names only)
                    let names = playerRows.map { $0.name.trimmingCharacters(in: .whitespaces) }
                    PersistedRoster(names: names).save()
                }
                
                if canEdit {
                    Button(action: addPlayer) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Add Player")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            } header: {
                Text("Players")
            } footer: {
                if canEdit {
                    Text("Tap and hold to reorder. Minimum 1 player required.")
                } else {
                    Text("You cannot edit the roster as a client.")
                }
            }
            
            if canEdit {
                Section {
                    Button(role: .destructive, action: clearRoster) {
                        HStack {
                            Spacer()
                            Text("Clear Saved Roster")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Players")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .onAppear {
            if !hasLoadedRoster {
                loadRoster()
                hasLoadedRoster = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func indexOfRow(_ id: UUID) -> Int {
        playerRows.firstIndex(where: { $0.id == id }) ?? 0
    }
    
    private func loadRoster() {
        // If game engine already has players, load from there
        if !gameEngine.players.isEmpty {
            playerRows = gameEngine.players.map { PlayerNameRow(name: $0.name) }
        } else if let roster = PersistedRoster.load(), !roster.names.isEmpty {
            playerRows = roster.names.map { PlayerNameRow(name: $0) }
        } else {
            playerRows = [PlayerNameRow(), PlayerNameRow()]
        }
        focusCoordinator.setOrder(playerRows.map { $0.id })
    }
    
    private func addPlayer() {
        guard canEdit else { return }
        let newRow = PlayerNameRow()
        playerRows.append(newRow)
        focusCoordinator.setOrder(playerRows.map { $0.id })
        
        // Add new player to game engine
        let index = playerRows.count - 1
        let name = newRow.name.trimmingCharacters(in: .whitespaces)
        let finalName = name.isEmpty ? "Player \(index + 1)" : name
        gameEngine.addPlayer(name: finalName)
        
        // Save roster
        let names = playerRows.map { $0.name.trimmingCharacters(in: .whitespaces) }
        PersistedRoster(names: names).save()
    }
    
    private func clearRoster() {
        guard canEdit else { return }
        playerRows = [PlayerNameRow(), PlayerNameRow()]
        focusCoordinator.setOrder(playerRows.map { $0.id })
        PersistedRoster.clear()
        
        // Reset game engine players completely (including scores)
        gameEngine.players.removeAll()
        gameEngine.addPlayer(name: "Player 1")
        gameEngine.addPlayer(name: "Player 2")
        gameEngine.currentPlayerIndex = 0
    }
    
    private func saveChanges() {
        // Save names to persistent roster
        let names = playerRows.map { $0.name.trimmingCharacters(in: .whitespaces) }
        PersistedRoster(names: names).save()
        
        // Update names in game engine (preserving scores)
        for (index, row) in playerRows.enumerated() {
            if index < gameEngine.players.count {
                let name = row.name.trimmingCharacters(in: .whitespaces)
                let finalName = name.isEmpty ? "Player \(index + 1)" : name
                gameEngine.players[index].name = finalName
            }
        }
    }
}

// MARK: - Preview Grid for Management View

struct PlayerManagementPreviewGrid: View {
    let playerRows: [PlayerNameRow]
    let playerColors: [Color]
    
    private var columns: [GridItem] {
        let count = playerRows.count <= 4 ? 2 : (playerRows.count <= 6 ? 3 : 4)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(playerRows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 6) {
                    // Status icon (always show circle for preview)
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    
                    // Player name
                    Text(row.name.isEmpty ? "Player \(index + 1)" : row.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Placeholder score
                    Text("0")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((playerColors[safe: index] ?? .blue).opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((playerColors[safe: index] ?? .blue).opacity(0.3), lineWidth: 2)
                )
            }
        }
    }
}

