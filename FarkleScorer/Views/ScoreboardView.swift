import SwiftUI

struct ScoreboardView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Current Scores Tab
                CurrentScoresTab(gameEngine: gameEngine)
                    .tabItem {
                        Image(systemName: "list.number")
                        Text("Scores")
                    }
                    .tag(0)

                // Statistics Tab
                StatisticsTab(gameEngine: gameEngine)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Stats")
                    }
                    .tag(1)
            }
            .navigationTitle("Scoreboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
    }
}

struct CurrentScoresTab: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isEditMode = false
    @State private var editingPlayerID: UUID? = nil
    @State private var editingPlayerName = ""
    @State private var newPlayerName = ""

    private var sortedPlayers: [Player] {
        gameEngine.getPlayerRanking()
    }

    var body: some View {
        List {
            // Game Progress Section
            Section {
                GameProgressCard(gameEngine: gameEngine)
            }

            // Players Standings with edit functionality
            Section {
                HStack {
                    Text("Standings")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    // Edit mode toggle button with sliding clear button
                    HStack(spacing: 8) {
                        // Edit/Done button (removed Clear button for in-game)
                        Button(isEditMode ? "Done" : "Edit") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditMode.toggle()
                            }
                            if !isEditMode {
                                // Save any in-progress edits when exiting edit mode
                                if let editingID = editingPlayerID {
                                    updatePlayerName(editingID, newName: editingPlayerName)
                                }
                            }
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isEditMode ? .green : .blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((isEditMode ? Color.green : Color.blue).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditMode)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if isEditMode {
                    // Add player field in edit mode
                    HStack {
                        TextField("Enter new player name", text: $newPlayerName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("Add") {
                            addPlayer()
                        }
                        .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(6)
                    }
                    .padding(.vertical, 4)

                    ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                        EditablePlayerScoreRow(
                            player: player,
                            rank: index + 1,
                            isCurrentPlayer: gameEngine.currentPlayerIndex == gameEngine.players.firstIndex(of: player),
                            gameEngine: gameEngine,
                            editingPlayerID: $editingPlayerID,
                            editingPlayerName: $editingPlayerName,
                            canDelete: gameEngine.players.count > 1,
                            onEdit: { newName in
                                updatePlayerName(player.id, newName: newName)
                            },
                            onDelete: {
                                if let playerIndex = gameEngine.players.firstIndex(of: player) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        gameEngine.removePlayer(at: playerIndex)
                                        savePlayerNames()
                                    }
                                }
                            }
                        )
                    }
                    .onMove(perform: movePlayer)
                } else {
                    ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                        PlayerScoreRow(
                            player: player,
                            rank: index + 1,
                            isCurrentPlayer: gameEngine.currentPlayerIndex == gameEngine.players.firstIndex(of: player),
                            gameEngine: gameEngine
                        )
                    }
                }
            }

            // Round History for Current Player
            if let currentPlayer = gameEngine.currentPlayer, !currentPlayer.gameHistory.isEmpty {
                Section("\(currentPlayer.name)'s Recent Turns") {
                    ForEach(currentPlayer.gameHistory.suffix(5).reversed(), id: \.id) { turn in
                        TurnHistoryRow(turn: turn)
                    }
                }
            }
        }
    }

    private func movePlayer(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            gameEngine.reorderPlayers(from: source, to: destination)
            savePlayerNames()
        }
    }

    private func updatePlayerName(_ playerID: UUID, newName: String) {
        if let playerIndex = gameEngine.players.firstIndex(where: { $0.id == playerID }) {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    gameEngine.players[playerIndex].name = trimmedName
                }
                // Only clear editing state if we're editing this specific player
                if editingPlayerID == playerID {
                    editingPlayerID = nil
                    editingPlayerName = ""
                }
                savePlayerNames()
            }
        } else {
            // Player not found, clear editing state only if it matches this player
            if editingPlayerID == playerID {
                editingPlayerID = nil
                editingPlayerName = ""
            }
        }
    }

    private func savePlayerNames() {
        let playerNames = gameEngine.players.map { $0.name }
        UserDefaults.standard.set(playerNames, forKey: "savedPlayerNames")
    }

    private func addPlayer() {
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) {
                gameEngine.addPlayer(name: trimmedName)
            }
            newPlayerName = ""
            savePlayerNames()
        }
    }


}

struct GameProgressCard: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Score")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(gameEngine.winningScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Leader")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let leader = gameEngine.getPlayerRanking().first {
                        Text(leader.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("\(leader.totalScore) pts")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            // Progress Bar
            if let leader = gameEngine.getPlayerRanking().first {
                ProgressView(value: Double(leader.totalScore), total: Double(gameEngine.winningScore))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))

                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(Double(leader.totalScore) / Double(gameEngine.winningScore) * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PlayerScoreRow: View {
    let player: Player
    let rank: Int
    let isCurrentPlayer: Bool
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(player.name)
                        .font(.headline)
                        .fontWeight(isCurrentPlayer ? .bold : .semibold)

                    if isCurrentPlayer {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    // On board status
                    if gameEngine.require500Opening {
                        StatusChip(
                            text: player.isOnBoard ? "On Board" : "Not On Board",
                            color: player.isOnBoard ? .green : .orange
                        )
                    }

                    // Farkle count
                    if player.consecutiveFarkles > 0 {
                        StatusChip(
                            text: "\(player.consecutiveFarkles) Farkle\(player.consecutiveFarkles > 1 ? "s" : "")",
                            color: player.consecutiveFarkles >= 2 ? .red : .orange
                        )
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(player.displayScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrentPlayer ? .blue : .primary)

                if player.roundScore > 0 {
                    Text("+\(player.roundScore)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                if player.gameHistory.count > 0 {
                    Text("\(player.gameHistory.count) turns")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isCurrentPlayer ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .gold
        case 2: return .gray
        case 3: return Color.orange
        default: return .blue
        }
    }
}

struct StatusChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct TurnHistoryRow: View {
    let turn: Turn

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if turn.isFarkle {
                    Text("Farkle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)

                    Text("Lost round score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Scored \(turn.score) points")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Selected: \(turn.selectedDice.map(String.init).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(turn.isFarkle ? "0" : "\(turn.score)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(turn.isFarkle ? .red : .green)

                Text(turn.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct StatisticsTab: View {
    @ObservedObject var gameEngine: GameEngine

    private var gameStats: GameStatistics {
        gameEngine.getGameStatistics()
    }

    var body: some View {
        List {
            // Overall Game Stats
            Section("Game Statistics") {
                StatRow(label: "Total Turns", value: "\(gameStats.totalTurns)")
                StatRow(label: "Total Farkles", value: "\(gameStats.totalFarkles)")
                StatRow(label: "Game Duration", value: formatGameDuration(gameStats.gameLength))
                StatRow(label: "Average Score", value: "\(Int(gameStats.playerStats.map { $0.totalScore }.reduce(0, +) / gameStats.playerStats.count))")
            }

            // Player Statistics
            Section("Player Statistics") {
                ForEach(gameStats.playerStats, id: \.playerName) { playerStat in
                    PlayerStatCard(playerStat: playerStat)
                }
            }

            // Scoring Distribution
            Section("Scoring Patterns") {
                ScoringPatternsView(gameEngine: gameEngine)
            }
        }
    }

    private func formatGameDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }
}

struct PlayerStatCard: View {
    let playerStat: PlayerStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(playerStat.playerName)
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                StatPair("Score", "\(playerStat.totalScore)")
                StatPair("Turns", "\(playerStat.turnsPlayed)")
                StatPair("Total Farkles", "\(playerStat.farkleCount)")
                StatPair("6-Dice Farkles", "\(playerStat.sixDiceFarkles)")
                StatPair("Avg/Turn", String(format: "%.0f", playerStat.averageScorePerTurn))
                StatPair("Best Turn", "\(playerStat.highestSingleTurn)")
                StatPair("Success Rate", successRateText)
                StatPair("Farkle Rate", farkleRateText)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }

    private var successRateText: String {
        let totalTurns = max(1, playerStat.turnsPlayed)
        let successfulTurns = totalTurns - playerStat.farkleCount
        let successRate = Double(successfulTurns) / Double(totalTurns)
        let percentage = Int(successRate * 100)
        return "\(percentage)%"
    }

    private var farkleRateText: String {
        let totalTurns = max(1, playerStat.turnsPlayed)
        let farkleRate = Double(playerStat.farkleCount) / Double(totalTurns)
        let percentage = Int(farkleRate * 100)
        return "\(percentage)%"
    }
}

struct StatPair: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct ScoringPatternsView: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most common scoring combinations")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // This would be expanded with actual pattern analysis
            VStack(alignment: .leading, spacing: 4) {
                PatternRow("Single 1s & 5s", "45%")
                PatternRow("Three of a kind", "25%")
                PatternRow("Mixed combinations", "20%")
                PatternRow("Special combinations", "10%")
            }
        }
    }
}

struct PatternRow: View {
    let pattern: String
    let percentage: String

    init(_ pattern: String, _ percentage: String) {
        self.pattern = pattern
        self.percentage = percentage
    }

    var body: some View {
        HStack {
            Text(pattern)
                .font(.caption)

            Spacer()

            Text(percentage)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
    }
}

struct EditablePlayerScoreRow: View {
    let player: Player
    let rank: Int
    let isCurrentPlayer: Bool
    @ObservedObject var gameEngine: GameEngine
    @Binding var editingPlayerID: UUID?
    @Binding var editingPlayerName: String
    let canDelete: Bool
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    var isEditing: Bool {
        editingPlayerID == player.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.horizontal.3")
                .foregroundColor(.gray)
                .font(.title3)
                .frame(width: 20)

            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if isEditing {
                        // Editing mode - show text field and buttons
                        TextField("Player name", text: $editingPlayerName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.headline)
                            .onSubmit {
                                saveEdit()
                            }

                        Button("Save") {
                            saveEdit()
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)

                        Button("Cancel") {
                            cancelEdit()
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray))
                        .cornerRadius(6)
                    } else {
                        // Normal mode - show player name and edit/delete buttons
                        Text(player.name)
                            .font(.headline)
                            .fontWeight(isCurrentPlayer ? .bold : .semibold)

                        if isCurrentPlayer {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: startEdit) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }

                            if canDelete {
                                Button(action: onDelete) {
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                            }
                        }
                    }
                }

                if !isEditing {
                    HStack(spacing: 8) {
                        // On board status
                        if gameEngine.require500Opening {
                            StatusChip(
                                text: player.isOnBoard ? "On Board" : "Not On Board",
                                color: player.isOnBoard ? .green : .orange
                            )
                        }

                        // Farkle count
                        if player.consecutiveFarkles > 0 {
                            StatusChip(
                                text: "\(player.consecutiveFarkles) Farkle\(player.consecutiveFarkles > 1 ? "s" : "")",
                                color: player.consecutiveFarkles >= 2 ? .red : .orange
                            )
                        }
                    }
                }
            }

            if !isEditing {
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(player.displayScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isCurrentPlayer ? .blue : .primary)

                    if player.roundScore > 0 {
                        Text("+\(player.roundScore)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    if player.gameHistory.count > 0 {
                        Text("\(player.gameHistory.count) turns")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minHeight: 60) // Ensure consistent row height
        .padding(.vertical, 4)
        .background(isCurrentPlayer ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .gold
        case 2: return .gray
        case 3: return Color.orange
        default: return .blue
        }
    }

    private func startEdit() {
        editingPlayerID = player.id
        editingPlayerName = player.name
    }

    private func saveEdit() {
        onEdit(editingPlayerName)
        editingPlayerID = nil
        editingPlayerName = ""
    }

    private func cancelEdit() {
        editingPlayerID = nil
        editingPlayerName = ""
    }
}

// GameSettingsTab moved to ContentView.swift as GameSettingsView

#Preview {
    ScoreboardView(gameEngine: {
        let engine = GameEngine()
        engine.addPlayer(name: "Alice")
        engine.addPlayer(name: "Bob")
        engine.startGame()
        return engine
    }())
}
