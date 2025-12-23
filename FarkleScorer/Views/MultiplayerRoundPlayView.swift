import SwiftUI

/// Main view for multiplayer simultaneous-round gameplay
struct MultiplayerRoundPlayView: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    @State private var showingForceAdvanceConfirmation = false
    @State private var showingEndGameConfirmation = false
    @State private var showingScoreboard = false
    @State private var showingSettings = false
    @State private var selectedPlayerForTurn: Player?
    
    var gameEngine: GameEngine {
        multiplayerEngine.gameEngine
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FarkleTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Round header with progress
                    RoundProgressHeader(multiplayerEngine: multiplayerEngine)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    Divider()
                        .padding(.top, 8)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Your players section
                            MyPlayersSection(
                                multiplayerEngine: multiplayerEngine,
                                onStartTurn: { player in
                                    selectedPlayerForTurn = player
                                }
                            )
                            
                            // Active turns on other devices (spectating for host)
                            if multiplayerEngine.isNetworkHost {
                                SpectatingSection(multiplayerEngine: multiplayerEngine)
                            }
                            
                            // Round status section
                            RoundStatusSection(multiplayerEngine: multiplayerEngine)
                            
                            // Waiting players list
                            WaitingPlayersSection(multiplayerEngine: multiplayerEngine)
                            
                            // Submitted turns this round
                            SubmittedTurnsSection(multiplayerEngine: multiplayerEngine)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    
                    // Host controls (if applicable)
                    if multiplayerEngine.isNetworkHost {
                        HostControlsBar(
                            multiplayerEngine: multiplayerEngine,
                            onForceAdvance: {
                                showingForceAdvanceConfirmation = true
                            }
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Round \(multiplayerEngine.roundNumber)")
                            .font(.headline)
                        if multiplayerEngine.isFinalRound {
                            Text("FINAL ROUND")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingScoreboard = true }) {
                            Image(systemName: "list.number")
                        }
                        
                        // Menu for additional options
                        Menu {
                            if multiplayerEngine.isNetworkHost {
                                Section("Host Controls") {
                                    Button {
                                        showingForceAdvanceConfirmation = true
                                    } label: {
                                        Label("Skip Remaining Players", systemImage: "forward.fill")
                                    }
                                    .disabled(multiplayerEngine.allPlayersSubmitted)
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    showingEndGameConfirmation = true
                                } label: {
                                    Label("End Game", systemImage: "xmark.circle")
                                }
                            } else {
                                Button(role: .destructive) {
                                    multiplayerEngine.leaveMultiplayerGame()
                                    multiplayerEngine.gameEngine.resetGame()
                                } label: {
                                    Label("Leave Game", systemImage: "xmark.circle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingScoreboard) {
            ScoreboardView(gameEngine: gameEngine)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(gameEngine: gameEngine)
        }
        .sheet(item: $selectedPlayerForTurn) { player in
            MultiplayerTurnSheet(
                multiplayerEngine: multiplayerEngine,
                player: player
            )
        }
        .fullScreenCover(isPresented: $showingForceAdvanceConfirmation) {
            ForceAdvanceConfirmation(
                multiplayerEngine: multiplayerEngine,
                onConfirm: {
                    multiplayerEngine.forceAdvanceRound(reason: .hostOverride)
                },
                onDismiss: {
                    showingForceAdvanceConfirmation = false
                }
            )
            .background(ClearBackgroundView())
        }
        .fullScreenCover(isPresented: $showingEndGameConfirmation) {
            EndGameConfirmation(
                multiplayerEngine: multiplayerEngine,
                onConfirm: {
                    multiplayerEngine.roundPhase = .gameOver
                    multiplayerEngine.gameEngine.gameState = .gameOver
                    showingEndGameConfirmation = false
                },
                onDismiss: {
                    showingEndGameConfirmation = false
                }
            )
            .background(ClearBackgroundView())
        }
        .fullScreenCover(isPresented: .constant(multiplayerEngine.roundPhase == .gameOver)) {
            MultiplayerGameOverOverlay(multiplayerEngine: multiplayerEngine)
                .background(ClearBackgroundView())
        }
    }
}

// MARK: - Round Progress Header

struct RoundProgressHeader: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    
    private var totalPlayers: Int {
        multiplayerEngine.gameEngine.players.count
    }
    
    private var submittedCount: Int {
        multiplayerEngine.submittedPlayerCount
    }
    
    private var progressPercent: Double {
        guard totalPlayers > 0 else { return 0 }
        return Double(submittedCount) / Double(totalPlayers)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Connection status
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(multiplayerEngine.connectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if multiplayerEngine.isNetworkHost {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.router.fill")
                            .font(.caption)
                        Text("HOST")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
                }
            }
            
            // Progress bar
            VStack(spacing: 6) {
                HStack {
                    Text("Round Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(submittedCount)/\(totalPlayers) submitted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressGradient)
                            .frame(width: geometry.size.width * progressPercent)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressPercent)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(FarkleTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var connectionColor: Color {
        switch multiplayerEngine.networkManager.connectionState {
        case .connected: return .green
        case .connecting, .browsing, .hosting: return .orange
        case .disconnected: return .gray
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .green],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - My Players Section

struct MyPlayersSection: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    let onStartTurn: (Player) -> Void
    
    private var myPlayers: [Player] {
        multiplayerEngine.getMyPlayers()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                Text("Your Players")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(myPlayers.count) player\(myPlayers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if myPlayers.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No players assigned to you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                ForEach(myPlayers) { player in
                    MyPlayerCard(
                        player: player,
                        status: multiplayerEngine.playerRoundStatuses[player.id.uuidString] ?? .pending,
                        onStartTurn: { onStartTurn(player) }
                    )
                }
            }
        }
        .padding()
        .background(FarkleTheme.cardBackground)
        .cornerRadius(16)
    }
}

struct MyPlayerCard: View {
    let player: Player
    let status: PlayerRoundStatus.TurnStatus
    let onStartTurn: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                    HStack(spacing: 8) {
                        Text("\(player.totalScore) pts")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        RoundStatusBadge(status: status)
                    }
            }
            
            Spacer()
            
            // Action button
            if status == .pending {
                Button(action: onStartTurn) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Play Turn")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            } else if status == .submitted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else if status == .inProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct RoundStatusBadge: View {
    let status: PlayerRoundStatus.TurnStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(6)
    }
    
    private var iconName: String {
        switch status {
        case .pending: return "clock"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .submitted: return "checkmark"
        case .skipped: return "forward.fill"
        }
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Waiting"
        case .inProgress: return "Playing"
        case .submitted: return "Done"
        case .skipped: return "Skipped"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .submitted: return .green
        case .skipped: return .gray
        }
    }
}

// MARK: - Round Status Section

struct RoundStatusSection: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    
    var body: some View {
        if multiplayerEngine.isFinalRound {
            FinalRoundBanner(multiplayerEngine: multiplayerEngine)
        }
    }
}

struct FinalRoundBanner: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    
    private var triggerPlayerName: String? {
        guard let triggerId = multiplayerEngine.finalRoundTriggerPlayerId else { return nil }
        return multiplayerEngine.gameEngine.players.first { $0.id.uuidString == triggerId }?.name
    }
    
    var body: some View {
        HStack {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Final Round!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                if let name = triggerPlayerName {
                    Text("\(name) reached \(multiplayerEngine.gameEngine.winningScore) points!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Waiting Players Section

struct WaitingPlayersSection: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    
    private var waitingPlayers: [Player] {
        multiplayerEngine.getPendingPlayers()
    }
    
    var body: some View {
        if !waitingPlayers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "hourglass")
                        .foregroundColor(.orange)
                    Text("Waiting For")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(waitingPlayers) { player in
                        WaitingPlayerChip(
                            player: player,
                            status: multiplayerEngine.playerRoundStatuses[player.id.uuidString] ?? .pending
                        )
                    }
                }
            }
            .padding()
            .background(FarkleTheme.cardBackground)
            .cornerRadius(16)
        }
    }
}

struct WaitingPlayerChip: View {
    let player: Player
    let status: PlayerRoundStatus.TurnStatus
    
    var body: some View {
        HStack(spacing: 6) {
            if status == .inProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "clock")
                    .font(.caption)
            }
            
            Text(player.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .foregroundColor(status == .inProgress ? .blue : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            (status == .inProgress ? Color.blue : Color.orange).opacity(0.1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Spectating Section (Host only)

struct SpectatingSection: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    
    private var activeTurns: [TurnProgressData] {
        multiplayerEngine.getActiveRemoteTurns()
    }
    
    var body: some View {
        if !activeTurns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.purple)
                    Text("Live Turns")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(activeTurns.count) playing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ForEach(activeTurns, id: \.playerId) { progress in
                    SpectatingCard(progress: progress)
                }
            }
            .padding()
            .background(FarkleTheme.cardBackground)
            .cornerRadius(16)
        }
    }
}

struct SpectatingCard: View {
    let progress: TurnProgressData
    
    /// Check if a specific die at a given index should be shown as selected
    private func isDieSelected(die: Int, index: Int, in progress: TurnProgressData) -> Bool {
        // Simple approach: check if the die value is in selected dice
        // For spectating, we just show which values are selected without exact position matching
        return progress.selectedDice.contains(die)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Player name and status
            HStack {
                Text(progress.playerName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if progress.isPendingFarkle {
                    Text("FARKLE!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(6)
                } else {
                    Text("+\(progress.turnScore)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Dice display
            if !progress.currentRoll.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(progress.currentRoll.enumerated()), id: \.offset) { index, die in
                        SpectatorDieView(
                            value: die, 
                            isSelected: isDieSelected(die: die, index: index, in: progress)
                        )
                    }
                    
                    Spacer()
                    
                    // Roll count and remaining dice
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Roll #\(progress.rollCount + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(progress.remainingDice) dice left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("Preparing to roll...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Spacer()
                    
                    Text("\(progress.remainingDice) dice")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SpectatorDieView: View {
    let value: Int
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.green.opacity(0.2) : Color(.tertiarySystemBackground))
                .frame(width: 28, height: 28)
            
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
            
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .green : .primary)
        }
    }
}

// MARK: - Submitted Turns Section

struct SubmittedTurnsSection: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    
    var body: some View {
        if !multiplayerEngine.submittedTurns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("This Round")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                ForEach(multiplayerEngine.submittedTurns) { result in
                    SubmittedTurnRow(result: result)
                }
            }
            .padding()
            .background(FarkleTheme.cardBackground)
            .cornerRadius(16)
        }
    }
}

struct SubmittedTurnRow: View {
    let result: SubmittedTurnResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.playerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if result.turnResult.isFarkle {
                    Text("Farkled!")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("+\(result.turnResult.scoreEarned) pts")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.newTotalScore)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("total")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Host Controls Bar

struct HostControlsBar: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    let onForceAdvance: () -> Void
    
    private var canForceAdvance: Bool {
        multiplayerEngine.roundPhase == .roundInProgress &&
        multiplayerEngine.submittedPlayerCount > 0 &&
        !multiplayerEngine.allPlayersSubmitted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Host Controls")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("\(multiplayerEngine.getPendingPlayers().count) player\(multiplayerEngine.getPendingPlayers().count == 1 ? "" : "s") still playing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onForceAdvance) {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill")
                        Text("Skip Remaining")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canForceAdvance ? Color.orange : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!canForceAdvance)
            }
            .padding()
            .background(FarkleTheme.cardBackground)
        }
    }
}

// MARK: - Force Advance Confirmation

struct ForceAdvanceConfirmation: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    private var pendingPlayers: [Player] {
        multiplayerEngine.getPendingPlayers()
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            // Title
            Text("Skip Remaining Players?")
                .font(.title2)
                .fontWeight(.bold)
            
            // Message
            VStack(spacing: 8) {
                Text("The following players haven't submitted their turns:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                ForEach(pendingPlayers) { player in
                    Text("• \(player.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Text("Their turns will be skipped and they will score 0 points this round.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    onConfirm()
                    onDismiss()
                }) {
                    Text("Skip and Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                
                Button(action: onDismiss) {
                    Text("Wait for Players")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(FarkleTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(32)
    }
}

// MARK: - End Game Confirmation

struct EndGameConfirmation: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            // Title
            Text("End Game Early?")
                .font(.title2)
                .fontWeight(.bold)
            
            // Message
            VStack(spacing: 8) {
                Text("This will end the game immediately.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Current standings will be used as final scores.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Current leader info
            if let leader = multiplayerEngine.gameEngine.getPlayerRanking().first {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("\(leader.name) is leading with \(leader.totalScore) pts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    onConfirm()
                }) {
                    Text("End Game")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                Button(action: onDismiss) {
                    Text("Continue Playing")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(FarkleTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(32)
    }
}

// MARK: - Multiplayer Turn Sheet

struct MultiplayerTurnSheet: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    let player: Player
    @Environment(\.dismiss) private var dismiss
    
    @State private var localGameEngine = GameEngine()
    @State private var turnStarted = false
    @State private var turnComplete = false
    @State private var progressBroadcastTimer: Timer?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Player header
                TurnPlayerHeader(player: player, localEngine: localGameEngine)
                    .padding()
                    .background(FarkleTheme.cardBackground)
                
                Divider()
                
                // Turn content
                ScrollView {
                    VStack(spacing: 12) {
                        if !turnStarted {
                            // Pre-turn state
                            PreTurnView(player: player, onStartTurn: startTurn)
                        } else if turnComplete {
                            // Turn complete state
                            TurnCompleteView(
                                localEngine: localGameEngine,
                                player: player,
                                onSubmit: submitTurn
                            )
                        } else {
                            // Active turn
                            ActiveTurnView(localEngine: localGameEngine)
                        }
                    }
                    .padding()
                }
                
                // Action bar
                if turnStarted && !turnComplete {
                    TurnActionBar(
                        localEngine: localGameEngine,
                        onBank: completeTurn,
                        onFarkle: handleFarkle
                    )
                }
            }
            .navigationTitle("\(player.name)'s Turn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        multiplayerEngine.cancelLocalTurn()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupLocalEngine()
        }
        .onDisappear {
            stopProgressBroadcast()
        }
        .onChange(of: localGameEngine.currentRoll) { _, _ in
            broadcastProgress()
        }
        .onChange(of: localGameEngine.selectedDice) { _, _ in
            broadcastProgress()
        }
        .onChange(of: localGameEngine.turnScore) { _, _ in
            broadcastProgress()
        }
    }
    
    private func startProgressBroadcast() {
        // Broadcast immediately and then periodically
        broadcastProgress()
        progressBroadcastTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            broadcastProgress()
        }
    }
    
    private func stopProgressBroadcast() {
        progressBroadcastTimer?.invalidate()
        progressBroadcastTimer = nil
    }
    
    private func broadcastProgress() {
        guard turnStarted && !turnComplete else { return }
        multiplayerEngine.broadcastTurnProgress(playerId: player.id.uuidString, localEngine: localGameEngine)
    }
    
    private func setupLocalEngine() {
        // Copy relevant settings from main engine
        localGameEngine.winningScore = multiplayerEngine.gameEngine.winningScore
        localGameEngine.require500Opening = multiplayerEngine.gameEngine.require500Opening
        localGameEngine.openingScoreThreshold = multiplayerEngine.gameEngine.openingScoreThreshold
        localGameEngine.enableTripleFarkleRule = multiplayerEngine.gameEngine.enableTripleFarkleRule
        localGameEngine.tripleFarklePenalty = multiplayerEngine.gameEngine.tripleFarklePenalty
        localGameEngine.scoringRulesStore = multiplayerEngine.gameEngine.scoringRulesStore
        
        // Add a single player for this turn
        localGameEngine.addPlayer(name: player.name)
        if !localGameEngine.players.isEmpty {
            // Copy player state
            localGameEngine.players[0].totalScore = player.totalScore
            localGameEngine.players[0].isOnBoard = player.isOnBoard
            localGameEngine.players[0].consecutiveFarkles = player.consecutiveFarkles
        }
    }
    
    private func startTurn() {
        multiplayerEngine.startLocalTurn(for: player.id.uuidString)
        localGameEngine.startGame()
        turnStarted = true
        startProgressBroadcast()
    }
    
    private func completeTurn() {
        stopProgressBroadcast()
        localGameEngine.bankScore()
        turnComplete = true
    }
    
    private func handleFarkle() {
        stopProgressBroadcast()
        localGameEngine.acknowledgeFarkle()
        turnComplete = true
    }
    
    private func submitTurn() {
        // Build turn result from local engine state
        let rolls = localGameEngine.players.first?.gameHistory.map { turn in
            TurnResultData.RollRecord(
                diceRolled: turn.diceRolled,
                diceSelected: turn.selectedDice,
                scoreFromSelection: turn.score
            )
        } ?? []
        
        let wasFarkle = localGameEngine.players.first?.gameHistory.last?.isFarkle ?? false
        let scoreEarned = localGameEngine.players.first?.totalScore ?? 0
        
        let result = TurnResultData(
            scoreEarned: wasFarkle ? 0 : scoreEarned,
            isFarkle: wasFarkle,
            wasManualMode: false,
            rolls: rolls
        )
        
        multiplayerEngine.submitLocalTurn(playerId: player.id.uuidString, result: result)
        dismiss()
    }
}

struct TurnPlayerHeader: View {
    let player: Player
    @ObservedObject var localEngine: GameEngine
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Current: \(player.totalScore) pts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if localEngine.gameState == .playing {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(localEngine.players.first?.roundScore ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("this turn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct PreTurnView: View {
    let player: Player
    let onStartTurn: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "die.face.6")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Ready to play?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Roll the dice to start your turn")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onStartTurn) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Turn")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct ActiveTurnView: View {
    @ObservedObject var localEngine: GameEngine
    
    var body: some View {
        VStack(spacing: 12) {
            // Dice selection
            if !localEngine.currentRoll.isEmpty || localEngine.pendingFarkle {
                DiceSelectionView(gameEngine: localEngine)
            }
            
            // Turn management info
            TurnManagementView(gameEngine: localEngine)
        }
    }
}

struct TurnCompleteView: View {
    @ObservedObject var localEngine: GameEngine
    let player: Player
    let onSubmit: () -> Void
    
    private var wasFarkle: Bool {
        localEngine.players.first?.gameHistory.last?.isFarkle ?? false
    }
    
    private var scoreEarned: Int {
        localEngine.players.first?.totalScore ?? 0
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if wasFarkle {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("Farkle!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Text("No points scored this turn")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text("+\(scoreEarned) points!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("New total: \(player.totalScore + scoreEarned)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onSubmit) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Submit Turn")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct TurnActionBar: View {
    @ObservedObject var localEngine: GameEngine
    let onBank: () -> Void
    let onFarkle: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                if localEngine.pendingFarkle {
                    Button(action: onFarkle) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Continue")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                } else {
                    // Roll button
                    if localEngine.currentRoll.isEmpty {
                        Button(action: {
                            _ = localEngine.rollDice()
                        }) {
                            HStack {
                                Text("\(localEngine.remainingDice)×")
                                Image(systemName: "die.face.6")
                                Text("Roll")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    } else {
                        // Continue rolling
                        Button(action: {
                            localEngine.continueRolling()
                        }) {
                            Text("Keep Rolling")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(localEngine.canPlayerContinueRolling() ? Color.blue : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!localEngine.canPlayerContinueRolling())
                        
                        // Bank button
                        Button(action: onBank) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Bank \(localEngine.turnScore + (localEngine.players.first?.roundScore ?? 0))")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(localEngine.canPlayerBank() ? Color.green : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!localEngine.canPlayerBank())
                    }
                }
            }
            .padding()
            .background(FarkleTheme.cardBackground)
        }
    }
}

// MARK: - Multiplayer Game Over Overlay

struct MultiplayerGameOverOverlay: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    @State private var isPresented = false
    @State private var showingScoreboard = false
    
    private var winner: Player? {
        multiplayerEngine.gameEngine.getPlayerRanking().first
    }
    
    private var rankings: [Player] {
        multiplayerEngine.gameEngine.getPlayerRanking()
    }
    
    var body: some View {
        ZStack {
            // Dimmed backdrop
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
                    
                    // Multiplayer badge
                    HStack(spacing: 6) {
                        Image(systemName: "wifi")
                            .font(.caption)
                        Text(multiplayerEngine.isNetworkHost ? "Host" : "Connected")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Divider
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Final Scores section
                    VStack(spacing: 8) {
                        Text("Final Scores")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        ForEach(Array(rankings.enumerated()), id: \.element.id) { index, player in
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
                
                // Bottom action bar
                VStack(spacing: 12) {
                    if multiplayerEngine.isNetworkHost {
                        // Play Again - host only
                        Button(action: {
                            HapticFeedback.success()
                            multiplayerEngine.gameEngine.restartGame()
                            multiplayerEngine.roundPhase = .roundInProgress
                            multiplayerEngine.isFinalRound = false
                            multiplayerEngine.finalRoundTriggerPlayerId = nil
                            multiplayerEngine.startNewRound()
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
                    } else {
                        // Waiting message for clients
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("Waiting for host...")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemFill))
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
                        
                        // Leave Game / New Game button
                        Button(action: {
                            HapticFeedback.medium()
                            multiplayerEngine.leaveMultiplayerGame()
                            multiplayerEngine.gameEngine.resetGame()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: multiplayerEngine.isNetworkHost ? "plus.circle" : "xmark.circle")
                                    .font(.system(size: 14, weight: .medium))
                                Text(multiplayerEngine.isNetworkHost ? "New Game" : "Leave")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(multiplayerEngine.isNetworkHost ? .secondary : .red)
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
            ScoreboardView(gameEngine: multiplayerEngine.gameEngine)
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
    MultiplayerRoundPlayView(multiplayerEngine: {
        let engine = MultiplayerGameEngine()
        engine.gameEngine.addPlayer(name: "Alice")
        engine.gameEngine.addPlayer(name: "Bob")
        engine.enableDebugMode()
        return engine
    }())
}

