import Foundation
import Combine
import UIKit

class MultiplayerGameEngine: ObservableObject {

    // MARK: - Core Game Engine
    @Published var gameEngine: GameEngine

    // MARK: - Network Manager
    @Published var networkManager: MultipeerNetworkManager

    // MARK: - Multiplayer State
    @Published var isMultiplayerMode: Bool = false
    @Published var isNetworkHost: Bool = false
    @Published var gameId: String = ""

    // MARK: - Stable Device Identity
    /// This device's stable ID (from network manager)
    var currentDeviceId: String {
        networkManager.localDeviceId
    }
    
    // MARK: - Player Assignment (playerId -> deviceId)
    @Published var playerDeviceAssignments: [String: String] = [:]

    // MARK: - Connection Management
    @Published var connectionStatus: String = "Disconnected"
    @Published var connectedDevices: [NetworkPeer] = []
    @Published var discoveredHosts: [DiscoveredHost] = []
    @Published var networkError: NetworkError?

    // MARK: - Player Assignment (computed)
    @Published var playersOnThisDevice: [Player] = []
    @Published var isCurrentPlayerOnThisDevice: Bool = false

    // MARK: - Game State Control
    @Published var canControlGame: Bool = true

    // MARK: - Simultaneous Round State
    @Published var roundNumber: Int = 0
    @Published var playerRoundStatuses: [String: PlayerRoundStatus.TurnStatus] = [:] // playerId -> status
    @Published var submittedTurns: [SubmittedTurnResult] = []
    @Published var roundPhase: RoundStateData.GamePhase = .setup
    @Published var isFinalRound: Bool = false
    @Published var finalRoundTriggerPlayerId: String?
    
    // MARK: - Local Turn State (for this device's players)
    @Published var localTurnInProgress: Bool = false
    @Published var localTurnPlayerId: String?
    
    // MARK: - Spectating State (for host to see other devices' turns)
    /// Active turn progress from other devices (playerId -> progress)
    @Published var activeTurnProgress: [String: TurnProgressData] = [:]
    
    // Debug mode for testing without real devices
    @Published var isDebugMode = false
    
    // MARK: - Recovery State
    @Published var isResyncPending: Bool = false
    private var lastSyncReceived: Date = Date()
    private let resyncTimeout: TimeInterval = 5.0

    private var cancellables = Set<AnyCancellable>()
    private let syncThrottleInterval: TimeInterval = 0.5
    private var lastSyncTime: Date = Date()

    init() {
        self.gameEngine = GameEngine()
        self.networkManager = MultipeerNetworkManager()

        setupNetworkCallbacks()
        setupGameEngineObservation()
        setupAppLifecycleObservation()
    }
    
    // MARK: - App Lifecycle for Recovery
    
    private func setupAppLifecycleObservation() {
        // Listen for app returning to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)
        
        // Listen for app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkConnectionHealth()
            }
            .store(in: &cancellables)
    }
    
    /// Handle app returning to foreground - request resync if connected
    private func handleAppForeground() {
        guard isMultiplayerMode else { return }
        
        if !isNetworkHost && networkManager.isConnected {
            // Client: request full sync from host
            requestFullSync()
        } else if isNetworkHost && networkManager.isConnected {
            // Host: broadcast current state to ensure clients are in sync
            broadcastRoundState()
            syncGameStateNow()
        }
    }
    
    /// Check connection health and trigger resync if needed
    private func checkConnectionHealth() {
        guard isMultiplayerMode && networkManager.isConnected else { return }
        
        // If we haven't received a sync in a while, request one
        let timeSinceLastSync = Date().timeIntervalSince(lastSyncReceived)
        if timeSinceLastSync > resyncTimeout && !isNetworkHost {
            requestFullSync()
        }
    }
    
    /// Request full game state sync from host (client-side)
    func requestFullSync() {
        guard !isNetworkHost && isMultiplayerMode else { return }
        
        isResyncPending = true
        sendNetworkMessage(.requestFullSync)
        
        print("🔄 Requesting full sync from host...")
        
        // Timeout the resync request after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + resyncTimeout) { [weak self] in
            self?.isResyncPending = false
        }
    }
    
    /// Mark sync as received (called when we get state from host)
    private func markSyncReceived() {
        lastSyncReceived = Date()
        isResyncPending = false
    }

    // MARK: - Network Setup

    private func setupNetworkCallbacks() {
        // Handle incoming messages
        networkManager.onMessageReceived = { [weak self] message, peer in
            self?.handleNetworkMessage(message, from: peer)
        }

        // Handle peer connections
        networkManager.onPeerConnected = { [weak self] peer in
            self?.handlePeerConnected(peer)
        }

        // Handle peer disconnections
        networkManager.onPeerDisconnected = { [weak self] peer in
            self?.handlePeerDisconnected(peer)
        }

        // Observe network state changes
        networkManager.$connectionState
            .sink { [weak self] state in
                self?.connectionStatus = state.description
            }
            .store(in: &cancellables)

        networkManager.$connectedPeers
            .sink { [weak self] peers in
                self?.connectedDevices = peers
                self?.updateCanControlGame()
            }
            .store(in: &cancellables)
        
        networkManager.$discoveredHosts
            .sink { [weak self] hosts in
                self?.discoveredHosts = hosts
            }
            .store(in: &cancellables)

        networkManager.$isHost
            .sink { [weak self] isHost in
                self?.isNetworkHost = isHost
                let isMultiplayer = self?.isMultiplayerMode ?? false
                self?.canControlGame = isHost || !isMultiplayer
                self?.updateRuleEditingPermissions()
            }
            .store(in: &cancellables)
    }
    
    /// Update GameEngine's rule editing permissions based on multiplayer state
    private func updateRuleEditingPermissions() {
        if isMultiplayerMode {
            gameEngine.canEditRules = isNetworkHost
            gameEngine.editingDisabledReason = isNetworkHost ? nil : "Only the host can edit rules"
        } else {
            gameEngine.canEditRules = true
            gameEngine.editingDisabledReason = nil
        }
    }

    private func setupGameEngineObservation() {
        // Observe game state changes and sync them
        gameEngine.$players
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
                self?.updatePlayersOnThisDevice()
                self?.networkManager.updateAdvertisedPlayerCount(self?.gameEngine.players.count ?? 0)
            }
            .store(in: &cancellables)

        gameEngine.$currentPlayerIndex
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
                self?.updateCurrentPlayerStatus()
            }
            .store(in: &cancellables)

        gameEngine.$gameState
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
        
        // Observe game rule changes for host-synced editing
        gameEngine.$winningScore
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
        
        gameEngine.$require500Opening
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
        
        gameEngine.$openingScoreThreshold
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
        
        gameEngine.$enableTripleFarkleRule
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
        
        gameEngine.$tripleFarklePenalty
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
        
        gameEngine.$scoringRulesStore
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
            }
            .store(in: &cancellables)
    }

    // MARK: - Multiplayer Control

    func startHostingGame() {
        isMultiplayerMode = true
        isNetworkHost = true
        gameId = generateGameCode()
        roundNumber = 0
        roundPhase = .setup
        playerRoundStatuses.removeAll()
        submittedTurns.removeAll()

        networkManager.startHosting(gameId: gameId)
        canControlGame = true
        updateRuleEditingPermissions()

        print("🎮 Started hosting multiplayer game: \(gameId)")
    }
    
    /// Generate a short, readable game code
    private func generateGameCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<4).map { _ in chars.randomElement()! })
        return code
    }

    func joinGame() {
        isMultiplayerMode = true
        isNetworkHost = false

        networkManager.startBrowsing()
        canControlGame = false
        updateRuleEditingPermissions()

        print("🔍 Looking for multiplayer games...")
    }
    
    /// Connect to a specific discovered host
    func connectToHost(_ host: DiscoveredHost) {
        gameId = host.gameId
        networkManager.connectToHost(host)
    }

    func leaveMultiplayerGame() {
        networkManager.stopNetworking()
        isMultiplayerMode = false
        isNetworkHost = false
        canControlGame = true
        gameId = ""
        playerDeviceAssignments.removeAll()
        playersOnThisDevice.removeAll()
        roundNumber = 0
        roundPhase = .setup
        playerRoundStatuses.removeAll()
        submittedTurns.removeAll()
        localTurnInProgress = false
        localTurnPlayerId = nil
        updateRuleEditingPermissions()

        print("👋 Left multiplayer game")
    }

    // MARK: - Player Device Assignment

    func assignPlayerToDevice(_ playerId: String, deviceId: String) {
        guard isNetworkHost else { return }

        if deviceId.isEmpty {
            playerDeviceAssignments.removeValue(forKey: playerId)
        } else {
            playerDeviceAssignments[playerId] = deviceId
        }
        updatePlayersOnThisDevice()

        // Broadcast updated roster to all clients
        broadcastRoundState()
    }

    func assignPlayerToCurrentDevice(_ playerId: String) {
        assignPlayerToDevice(playerId, deviceId: currentDeviceId)
    }

    func getPlayersForDevice(_ deviceId: String) -> [Player] {
        return gameEngine.players.filter { player in
            playerDeviceAssignments[player.id.uuidString] == deviceId
        }
    }

    func getDeviceForPlayer(_ playerId: UUID) -> String? {
        return playerDeviceAssignments[playerId.uuidString]
    }
    
    /// Get players assigned to this device
    func getMyPlayers() -> [Player] {
        return getPlayersForDevice(currentDeviceId)
    }
    
    /// Check if a specific player is assigned to this device
    func isPlayerOnThisDevice(_ playerId: String) -> Bool {
        return playerDeviceAssignments[playerId] == currentDeviceId
    }

    private func updatePlayersOnThisDevice() {
        playersOnThisDevice = getPlayersForDevice(currentDeviceId)
        updateCurrentPlayerStatus()
    }

    private func updateCurrentPlayerStatus() {
        if let currentPlayer = gameEngine.currentPlayer {
            let currentPlayerId = currentPlayer.id.uuidString
            isCurrentPlayerOnThisDevice = playerDeviceAssignments[currentPlayerId] == currentDeviceId
        } else {
            isCurrentPlayerOnThisDevice = false
        }

        updateCanControlGame()
    }

    private func updateCanControlGame() {
        if !isMultiplayerMode {
            canControlGame = true
        } else if isNetworkHost {
            canControlGame = true
        } else {
            // Clients can control their assigned players
            canControlGame = !playersOnThisDevice.isEmpty
        }
    }

    // MARK: - Game Actions with Network Support

    func addPlayer(name: String) {
        guard canControlGame || isNetworkHost else { return }

        if isMultiplayerMode && isNetworkHost {
            gameEngine.addPlayer(name: name)
            // Auto-assign to host device initially
            if let newPlayer = gameEngine.players.last {
                assignPlayerToCurrentDevice(newPlayer.id.uuidString)
            }
        } else if !isMultiplayerMode {
            gameEngine.addPlayer(name: name)
        }
    }

    func removePlayer(at index: Int) {
        guard canControlGame || isNetworkHost else { return }

        if index < gameEngine.players.count {
            let playerId = gameEngine.players[index].id.uuidString
            playerDeviceAssignments.removeValue(forKey: playerId)
            playerRoundStatuses.removeValue(forKey: playerId)
        }

        gameEngine.removePlayer(at: index)
    }

    func startGame() {
        guard isNetworkHost || !isMultiplayerMode else { return }

        gameEngine.startGame()
        
        if isMultiplayerMode && isNetworkHost {
            // Initialize round state
            roundNumber = 1
            roundPhase = .roundInProgress
            isFinalRound = false
            finalRoundTriggerPlayerId = nil
            
            // Set all players to pending
            for player in gameEngine.players {
                playerRoundStatuses[player.id.uuidString] = .pending
            }
            submittedTurns.removeAll()
            
            // Broadcast game started and initial round state
            sendNetworkMessage(.gameStarted)
            broadcastRoundState()
        }
    }
    
    // MARK: - Simultaneous Round Coordination (Host)
    
    /// Start a new round (host only)
    func startNewRound() {
        guard isNetworkHost && isMultiplayerMode else { return }
        
        roundNumber += 1
        submittedTurns.removeAll()
        
        // Reset all player statuses to pending
        for player in gameEngine.players {
            playerRoundStatuses[player.id.uuidString] = .pending
        }
        
        roundPhase = .roundInProgress
        
        // Broadcast new round
        sendNetworkMessage(.roundStarted(roundNumber: roundNumber))
        broadcastRoundState()
        
        print("🔄 Started round \(roundNumber)")
    }
    
    /// Check if all players have submitted their turns
    var allPlayersSubmitted: Bool {
        for player in gameEngine.players {
            let status = playerRoundStatuses[player.id.uuidString] ?? .pending
            if status != .submitted && status != .skipped {
                return false
            }
        }
        return true
    }
    
    /// Get count of submitted players
    var submittedPlayerCount: Int {
        playerRoundStatuses.values.filter { $0 == .submitted || $0 == .skipped }.count
    }
    
    /// Get players who haven't submitted yet
    func getPendingPlayers() -> [Player] {
        return gameEngine.players.filter { player in
            let status = playerRoundStatuses[player.id.uuidString] ?? .pending
            return status == .pending || status == .inProgress
        }
    }
    
    /// Force advance to next round (host only, with confirmation)
    func forceAdvanceRound(reason: ForceAdvanceReason) {
        guard isNetworkHost && isMultiplayerMode else { return }
        
        // Mark any pending players as skipped
        for player in gameEngine.players {
            let status = playerRoundStatuses[player.id.uuidString] ?? .pending
            if status == .pending || status == .inProgress {
                playerRoundStatuses[player.id.uuidString] = .skipped
            }
        }
        
        // Broadcast the force advance
        sendNetworkMessage(.forceAdvanceRound(reason))
        
        // Check if game should end
        if checkForGameEnd() {
            endGame()
        } else {
            startNewRound()
        }
    }
    
    /// Handle turn submission from a client
    func handleTurnSubmission(_ submission: TurnSubmissionData) {
        guard isNetworkHost else { return }
        
        // Verify the submission is from the correct device
        let expectedDeviceId = playerDeviceAssignments[submission.playerId]
        guard expectedDeviceId == submission.deviceId else {
            print("⚠️ Turn submission from wrong device: expected \(expectedDeviceId ?? "nil"), got \(submission.deviceId)")
            return
        }
        
        // Find the player
        guard let playerIndex = gameEngine.players.firstIndex(where: { $0.id.uuidString == submission.playerId }) else {
            print("⚠️ Turn submission for unknown player: \(submission.playerId)")
            return
        }
        
        let player = gameEngine.players[playerIndex]
        
        // Apply the turn result
        var newTotalScore = player.totalScore
        var newIsOnBoard = player.isOnBoard
        
        if submission.turnResult.isFarkle {
            // Handle farkle
            gameEngine.players[playerIndex].consecutiveFarkles += 1
            
            // Check triple farkle penalty
            if gameEngine.enableTripleFarkleRule && gameEngine.players[playerIndex].consecutiveFarkles >= 3 {
                newTotalScore = max(0, newTotalScore - gameEngine.tripleFarklePenalty)
                gameEngine.players[playerIndex].totalScore = newTotalScore
                gameEngine.players[playerIndex].consecutiveFarkles = 0
            }
        } else {
            // Successful turn - add score
            let scoreEarned = submission.turnResult.scoreEarned
            
            // Check opening score requirement
            if !player.isOnBoard && gameEngine.require500Opening {
                if scoreEarned >= gameEngine.openingScoreThreshold {
                    newIsOnBoard = true
                    gameEngine.players[playerIndex].isOnBoard = true
                    newTotalScore += scoreEarned
                    gameEngine.players[playerIndex].totalScore = newTotalScore
                }
                // If not enough to get on board, score is lost
            } else {
                newTotalScore += scoreEarned
                gameEngine.players[playerIndex].totalScore = newTotalScore
            }
            
            // Reset consecutive farkles
            gameEngine.players[playerIndex].consecutiveFarkles = 0
        }
        
        // Create submitted turn result
        let submittedResult = SubmittedTurnResult(
            id: UUID().uuidString,
            playerId: submission.playerId,
            playerName: player.name,
            turnResult: submission.turnResult,
            newTotalScore: newTotalScore,
            newIsOnBoard: newIsOnBoard,
            submittedAt: Date()
        )
        submittedTurns.append(submittedResult)
        
        // Mark player as submitted
        playerRoundStatuses[submission.playerId] = .submitted
        
        // Clear any live turn progress for this player
        clearTurnProgress(for: submission.playerId)
        
        // Check if player triggered final round
        if !isFinalRound && newTotalScore >= gameEngine.winningScore {
            isFinalRound = true
            finalRoundTriggerPlayerId = submission.playerId
            print("🏁 Final round triggered by \(player.name)!")
        }
        
        // Broadcast updated state
        broadcastRoundState()
        
        // Check if round is complete
        if allPlayersSubmitted {
            roundPhase = .roundComplete
            
            // Auto-advance or wait for host
            if checkForGameEnd() {
                endGame()
            } else {
                // Delay slightly then start new round
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startNewRound()
                }
            }
        }
        
        print("✅ Received turn submission from \(player.name): \(submission.turnResult.scoreEarned) pts (farkle: \(submission.turnResult.isFarkle))")
    }
    
    /// Check if game should end (final round complete)
    private func checkForGameEnd() -> Bool {
        guard isFinalRound else { return false }
        
        // In simultaneous mode, game ends after the final round is complete
        // (everyone gets one more turn after someone reaches winning score)
        return allPlayersSubmitted
    }
    
    /// End the game
    private func endGame() {
        roundPhase = .gameOver
        gameEngine.gameState = .gameOver
        
        sendNetworkMessage(.gameEnded)
        broadcastRoundState()
        
        print("🎉 Game Over!")
    }
    
    // MARK: - Local Turn Management (for this device's players)
    
    /// Start a turn for a local player
    func startLocalTurn(for playerId: String) {
        guard isPlayerOnThisDevice(playerId) else { return }
        guard playerRoundStatuses[playerId] == .pending else { return }
        
        localTurnInProgress = true
        localTurnPlayerId = playerId
        playerRoundStatuses[playerId] = .inProgress
        
        // If we're the host, broadcast the status change
        if isNetworkHost {
            broadcastRoundState()
        }
    }
    
    /// Submit the completed turn for a local player
    func submitLocalTurn(playerId: String, result: TurnResultData) {
        guard localTurnPlayerId == playerId else { return }
        
        let submission = TurnSubmissionData(
            playerId: playerId,
            deviceId: currentDeviceId,
            turnResult: result,
            timestamp: Date()
        )
        
        localTurnInProgress = false
        localTurnPlayerId = nil
        
        if isNetworkHost {
            // Process locally
            handleTurnSubmission(submission)
        } else {
            // Send to host
            sendNetworkMessage(.turnSubmission(submission))
            // Optimistically mark as submitted locally
            playerRoundStatuses[playerId] = .submitted
        }
    }
    
    /// Cancel the current local turn (reset to pending)
    func cancelLocalTurn() {
        guard let playerId = localTurnPlayerId else { return }
        
        localTurnInProgress = false
        localTurnPlayerId = nil
        playerRoundStatuses[playerId] = .pending
    }
    
    /// Broadcast turn progress for spectating (called periodically during local turn)
    func broadcastTurnProgress(playerId: String, localEngine: GameEngine) {
        guard let player = gameEngine.players.first(where: { $0.id.uuidString == playerId }) else { return }
        
        let progress = TurnProgressData(
            playerId: playerId,
            playerName: player.name,
            deviceId: currentDeviceId,
            currentRoll: localEngine.currentRoll,
            selectedDice: localEngine.selectedDice,
            turnScore: localEngine.turnScore + (localEngine.players.first?.roundScore ?? 0),
            rollCount: localEngine.players.first?.gameHistory.count ?? 0,
            remainingDice: localEngine.remainingDice,
            isPendingFarkle: localEngine.pendingFarkle,
            timestamp: Date()
        )
        
        sendNetworkMessage(.turnProgress(progress))
    }
    
    /// Handle incoming turn progress from another device (host only)
    private func handleTurnProgress(_ progress: TurnProgressData) {
        guard isNetworkHost else { return }
        
        // Store/update the progress for this player
        activeTurnProgress[progress.playerId] = progress
    }
    
    /// Clear turn progress for a player (when their turn completes)
    func clearTurnProgress(for playerId: String) {
        activeTurnProgress.removeValue(forKey: playerId)
    }
    
    /// Get active turns on other devices (for spectating UI)
    func getActiveRemoteTurns() -> [TurnProgressData] {
        return Array(activeTurnProgress.values).sorted { $0.playerName < $1.playerName }
    }

    // MARK: - Network Message Handling

    private func handleNetworkMessage(_ message: GameMessage, from peer: NetworkPeer) {
        switch message {
        // MARK: Handshake
        case .hello(let helloData):
            handleHello(helloData, from: peer)
            
        case .welcome(let welcomeData):
            handleWelcome(welcomeData, from: peer)
            
        case .requestFullSync:
            if isNetworkHost {
                sendWelcome(to: peer)
            }
            
        // MARK: Round Coordination
        case .roundStateSync(let roundState):
            if !isNetworkHost {
                applyRoundStateSync(roundState)
            }
            
        case .turnSubmission(let submission):
            if isNetworkHost {
                handleTurnSubmission(submission)
            }
            
        case .turnProgress(let progress):
            if isNetworkHost {
                handleTurnProgress(progress)
            }
            
        case .forceAdvanceRound(let reason):
            if !isNetworkHost {
                handleForceAdvance(reason)
            }
            
        case .roundStarted(let round):
            if !isNetworkHost {
                roundNumber = round
                roundPhase = .roundInProgress
                // Reset local state for new round
                localTurnInProgress = false
                localTurnPlayerId = nil
            }
            
        // MARK: Legacy Messages
        case .gameStateSync(let gameStateData):
            if !isNetworkHost {
                applyGameStateSync(gameStateData)
            }

        case .playerAction(let action):
            if isNetworkHost {
                executePlayerAction(action, from: peer)
            }

        case .playerJoined(_):
            break

        case .playerLeft(let playerId):
            if isNetworkHost {
                // Handle player leaving
                playerDeviceAssignments.removeValue(forKey: playerId)
                playerRoundStatuses.removeValue(forKey: playerId)
            }

        case .gameStarted:
            if !isNetworkHost {
                // Request full state sync
                sendNetworkMessage(.requestFullSync)
            }

        case .gameEnded:
            roundPhase = .gameOver
            gameEngine.gameState = .gameOver

        case .ping, .pong:
            break
        }
    }
    
    // MARK: - Handshake Handling
    
    private func handleHello(_ helloData: HelloData, from peer: NetworkPeer) {
        guard isNetworkHost else { return }
        
        print("📨 Received hello from \(helloData.displayName)")
        
        // Send welcome with full game state
        sendWelcome(to: peer)
    }
    
    private func sendWelcome(to peer: NetworkPeer) {
        guard isNetworkHost else { return }
        
        let config = GameConfigData(
            gameId: gameId,
            winningScore: gameEngine.winningScore,
            require500Opening: gameEngine.require500Opening,
            openingScoreThreshold: gameEngine.openingScoreThreshold,
            enableTripleFarkleRule: gameEngine.enableTripleFarkleRule,
            tripleFarklePenalty: gameEngine.tripleFarklePenalty,
            scoringRules: gameEngine.scoringRulesStore
        )
        
        let roster = gameEngine.players.map { player in
            PlayerRosterEntry(
                id: player.id.uuidString,
                name: player.name,
                totalScore: player.totalScore,
                isOnBoard: player.isOnBoard,
                consecutiveFarkles: player.consecutiveFarkles,
                assignedDeviceId: playerDeviceAssignments[player.id.uuidString]
            )
        }
        
        let roundState = createRoundStateData()
        
        let welcome = WelcomeData(
            hostDeviceId: currentDeviceId,
            gameConfig: config,
            roster: roster,
            currentRoundState: roundState,
            protocolVersion: ProtocolConstants.currentVersion
        )
        
        sendNetworkMessage(.welcome(welcome), to: [peer])
        
        print("📤 Sent welcome to \(peer.displayName)")
    }
    
    private func handleWelcome(_ welcomeData: WelcomeData, from peer: NetworkPeer) {
        guard !isNetworkHost else { return }
        
        print("📨 Received welcome from host")
        markSyncReceived()
        
        // Apply game config
        gameEngine.winningScore = welcomeData.gameConfig.winningScore
        gameEngine.require500Opening = welcomeData.gameConfig.require500Opening
        gameEngine.openingScoreThreshold = welcomeData.gameConfig.openingScoreThreshold
        gameEngine.enableTripleFarkleRule = welcomeData.gameConfig.enableTripleFarkleRule
        gameEngine.tripleFarklePenalty = welcomeData.gameConfig.tripleFarklePenalty
        gameEngine.scoringRulesStore = welcomeData.gameConfig.scoringRules
        
        // Apply roster
        gameEngine.players.removeAll()
        for entry in welcomeData.roster {
            var player = Player(name: entry.name)
            player.totalScore = entry.totalScore
            player.isOnBoard = entry.isOnBoard
            player.consecutiveFarkles = entry.consecutiveFarkles
            gameEngine.players.append(player)
            
            if let deviceId = entry.assignedDeviceId {
                playerDeviceAssignments[entry.id] = deviceId
            }
        }
        
        // Apply round state
        applyRoundStateSync(welcomeData.currentRoundState)
        
        // Update game state based on round phase
        switch welcomeData.currentRoundState.gamePhase {
        case .setup:
            gameEngine.gameState = .setup
        case .roundInProgress, .roundComplete:
            gameEngine.gameState = welcomeData.currentRoundState.isFinalRound ? .finalRound : .playing
        case .gameOver:
            gameEngine.gameState = .gameOver
        }
        
        updatePlayersOnThisDevice()
    }
    
    // MARK: - Round State Sync
    
    private func broadcastRoundState() {
        guard isNetworkHost && isMultiplayerMode else { return }
        
        let roundState = createRoundStateData()
        sendNetworkMessage(.roundStateSync(roundState))
    }
    
    private func createRoundStateData() -> RoundStateData {
        let statuses = gameEngine.players.map { player in
            PlayerRoundStatus(
                id: player.id.uuidString,
                playerId: player.id.uuidString,
                playerName: player.name,
                status: playerRoundStatuses[player.id.uuidString] ?? .pending,
                assignedDeviceId: playerDeviceAssignments[player.id.uuidString]
            )
        }
        
        return RoundStateData(
            roundNumber: roundNumber,
            gamePhase: roundPhase,
            playerStatuses: statuses,
            submittedTurns: submittedTurns,
            isFinalRound: isFinalRound,
            finalRoundTriggerPlayerId: finalRoundTriggerPlayerId,
            timestamp: Date()
        )
    }
    
    private func applyRoundStateSync(_ roundState: RoundStateData) {
        markSyncReceived()
        
        roundNumber = roundState.roundNumber
        roundPhase = roundState.gamePhase
        isFinalRound = roundState.isFinalRound
        finalRoundTriggerPlayerId = roundState.finalRoundTriggerPlayerId
        submittedTurns = roundState.submittedTurns
        
        // Apply player statuses and update scores from submitted turns
        for status in roundState.playerStatuses {
            playerRoundStatuses[status.playerId] = status.status
            
            if let deviceId = status.assignedDeviceId {
                playerDeviceAssignments[status.playerId] = deviceId
            }
        }
        
        // Update player scores from submitted turns
        for submittedTurn in roundState.submittedTurns {
            if let playerIndex = gameEngine.players.firstIndex(where: { $0.id.uuidString == submittedTurn.playerId }) {
                gameEngine.players[playerIndex].totalScore = submittedTurn.newTotalScore
                gameEngine.players[playerIndex].isOnBoard = submittedTurn.newIsOnBoard
            }
        }
        
        updatePlayersOnThisDevice()
    }
    
    private func handleForceAdvance(_ reason: ForceAdvanceReason) {
        // Host forced round advancement
        localTurnInProgress = false
        localTurnPlayerId = nil
        
        // Any pending turns are now skipped
        for playerId in playerRoundStatuses.keys {
            if playerRoundStatuses[playerId] == .pending || playerRoundStatuses[playerId] == .inProgress {
                playerRoundStatuses[playerId] = .skipped
            }
        }
    }

    // MARK: - Legacy Action Handling (for backwards compatibility)
    
    private func executePlayerAction(_ action: GameMessage.PlayerAction, from peer: NetworkPeer) {
        guard isNetworkHost else { return }
        
        switch action {
        case .rollDice:
            _ = gameEngine.rollDice()
        case .selectDice(let dice):
            gameEngine.selectDice(dice)
        case .bankScore:
            gameEngine.bankScore()
        case .nextTurn, .skipTurn:
            gameEngine.skipTurn()
        case .acknowledgeFarkle:
            gameEngine.acknowledgeFarkle()
        case .manualScore(let score):
            gameEngine.addManualScore(score)
        case .undoLastAction:
            gameEngine.undoLastSelection()
        case .continueRolling:
            gameEngine.continueRolling()
        }

        syncGameStateNow()
    }

    private func applyGameStateSync(_ gameStateData: GameStateData) {
        markSyncReceived()
        
        gameEngine.currentPlayerIndex = gameStateData.currentPlayerIndex
        gameEngine.winningScore = gameStateData.winningScore
        gameEngine.currentRoll = gameStateData.currentRoll
        gameEngine.selectedDice = gameStateData.selectedDice
        gameEngine.remainingDice = gameStateData.remainingDice
        gameEngine.turnScore = gameStateData.turnScore
        gameEngine.isManualMode = gameStateData.isManualMode
        gameEngine.manualTurnScore = gameStateData.manualTurnScore
        gameEngine.manualScoreHistory = gameStateData.manualScoreHistory
        gameEngine.pendingFarkle = gameStateData.pendingFarkle
        gameEngine.farklePlayerName = gameStateData.farklePlayerName
        gameEngine.farkleDice = gameStateData.farkleDice
        gameEngine.canUndo = gameStateData.canUndo
        
        gameEngine.require500Opening = gameStateData.require500Opening
        gameEngine.openingScoreThreshold = gameStateData.openingScoreThreshold
        gameEngine.enableTripleFarkleRule = gameStateData.enableTripleFarkleRule
        gameEngine.tripleFarklePenalty = gameStateData.tripleFarklePenalty
        gameEngine.scoringRulesStore = gameStateData.scoringRules
        
        // Update player assignments from player data
        for playerData in gameStateData.players {
            if let deviceId = playerData.assignedDeviceId {
                playerDeviceAssignments[playerData.id] = deviceId
            }
        }
        
        updatePlayersOnThisDevice()
    }

    private func handlePeerConnected(_ peer: NetworkPeer) {
        print("✅ Player connected: \(peer.displayName) [deviceId: \(peer.id.prefix(8))...]")

        if isNetworkHost {
            // Send welcome with full game state
            sendWelcome(to: peer)
        }
    }

    private func handlePeerDisconnected(_ peer: NetworkPeer) {
        print("👋 Player disconnected: \(peer.displayName)")

        if isNetworkHost {
            // Find and handle players assigned to this device
            let disconnectedPlayers = gameEngine.players.filter {
                playerDeviceAssignments[$0.id.uuidString] == peer.id
            }
            
            for player in disconnectedPlayers {
                // Mark their turn as skipped if in progress
                if playerRoundStatuses[player.id.uuidString] == .inProgress ||
                   playerRoundStatuses[player.id.uuidString] == .pending {
                    playerRoundStatuses[player.id.uuidString] = .skipped
                }
            }
            
            // Check if round is now complete
            if allPlayersSubmitted && roundPhase == .roundInProgress {
                roundPhase = .roundComplete
                if checkForGameEnd() {
                    endGame()
                } else {
                    startNewRound()
                }
            }
            
            broadcastRoundState()
        }
    }

    // MARK: - Game State Synchronization

    private func syncGameStateIfNeeded() {
        guard isMultiplayerMode && isNetworkHost else { return }

        let now = Date()
        if now.timeIntervalSince(lastSyncTime) < syncThrottleInterval {
            return
        }

        syncGameStateNow()
    }

    private func syncGameStateNow() {
        guard isMultiplayerMode && isNetworkHost else { return }

        let gameStateData = createGameStateData()
        sendNetworkMessage(.gameStateSync(gameStateData))
        lastSyncTime = Date()
    }

    private func createGameStateData() -> GameStateData {
        return GameStateData(
            players: gameEngine.players.map { createPlayerData(from: $0) },
            currentPlayerIndex: gameEngine.currentPlayerIndex,
            gameState: GameStateData.GameStateValue(rawValue: gameEngine.gameState == .setup ? "setup" :
                                                    gameEngine.gameState == .playing ? "playing" :
                                                    gameEngine.gameState == .finalRound ? "finalRound" : "gameOver") ?? .setup,
            winningScore: gameEngine.winningScore,
            currentRoll: gameEngine.currentRoll,
            selectedDice: gameEngine.selectedDice,
            remainingDice: gameEngine.remainingDice,
            turnScore: gameEngine.turnScore,
            isManualMode: gameEngine.isManualMode,
            manualTurnScore: gameEngine.manualTurnScore,
            manualScoreHistory: gameEngine.manualScoreHistory,
            pendingFarkle: gameEngine.pendingFarkle,
            farklePlayerName: gameEngine.farklePlayerName,
            farkleDice: gameEngine.farkleDice,
            canUndo: gameEngine.canUndo,
            finalRoundActive: gameEngine.isFinalRoundActive,
            finalRoundDescription: gameEngine.finalRoundDescription,
            require500Opening: gameEngine.require500Opening,
            openingScoreThreshold: gameEngine.openingScoreThreshold,
            enableTripleFarkleRule: gameEngine.enableTripleFarkleRule,
            tripleFarklePenalty: gameEngine.tripleFarklePenalty,
            scoringRules: gameEngine.scoringRulesStore
        )
    }

    private func createPlayerData(from player: Player) -> PlayerData {
        return PlayerData(
            id: player.id.uuidString,
            name: player.name,
            totalScore: player.totalScore,
            roundScore: player.roundScore,
            isOnBoard: player.isOnBoard,
            consecutiveFarkles: player.consecutiveFarkles,
            assignedDeviceId: playerDeviceAssignments[player.id.uuidString],
            gameHistory: player.gameHistory.map { turn in
                PlayerData.TurnData(
                    id: turn.id.uuidString,
                    diceRolled: turn.diceRolled,
                    selectedDice: turn.selectedDice,
                    score: turn.score,
                    isFarkle: turn.isFarkle,
                    isSixDiceFarkle: turn.isSixDiceFarkle,
                    timestamp: turn.timestamp
                )
            }
        )
    }

    private func sendNetworkMessage(_ message: GameMessage, to peers: [NetworkPeer]? = nil) {
        networkManager.sendMessage(message, to: peers)
    }

    // MARK: - Debug Testing Methods

    func enableDebugMode() {
        isDebugMode = true
        isMultiplayerMode = true
        isNetworkHost = true
        canControlGame = true
        connectionStatus = "Debug Mode - Simulated Network"
        gameId = "DEBUG"
        roundNumber = 1
        roundPhase = .roundInProgress

        connectedDevices = [
            NetworkPeer(id: "debug-device-1", displayName: "iPhone (Debug 1)", isHost: false),
            NetworkPeer(id: "debug-device-2", displayName: "iPad (Debug 2)", isHost: false)
        ]

        if gameEngine.players.count >= 2 {
            playerDeviceAssignments[gameEngine.players[0].id.uuidString] = currentDeviceId
            playerDeviceAssignments[gameEngine.players[1].id.uuidString] = "debug-device-1"
            playerRoundStatuses[gameEngine.players[0].id.uuidString] = .pending
            playerRoundStatuses[gameEngine.players[1].id.uuidString] = .pending
            if gameEngine.players.count >= 3 {
                playerDeviceAssignments[gameEngine.players[2].id.uuidString] = "debug-device-2"
                playerRoundStatuses[gameEngine.players[2].id.uuidString] = .pending
            }
        }
        
        updatePlayersOnThisDevice()
    }

    func disableDebugMode() {
        isDebugMode = false
        leaveMultiplayerGame()
    }
}
