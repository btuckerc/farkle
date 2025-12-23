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
    @Published var playerDeviceAssignments: [String: String] = [:] // playerId -> deviceId
    @Published var currentDeviceId: String
    @Published var gameId: String = ""

    // MARK: - Connection Management
    @Published var connectionStatus: String = "Disconnected"
    @Published var connectedDevices: [NetworkPeer] = []
    @Published var networkError: NetworkError?

    // MARK: - Player Assignment
    @Published var playersOnThisDevice: [Player] = []
    @Published var isCurrentPlayerOnThisDevice: Bool = false

    // MARK: - Game State Control
    @Published var canControlGame: Bool = true // Can this device control the game?

    // Debug mode for testing without real devices
    @Published var isDebugMode = false

    private var cancellables = Set<AnyCancellable>()
    private let syncThrottleInterval: TimeInterval = 0.5
    private var lastSyncTime: Date = Date()

    init() {
        self.gameEngine = GameEngine()
        self.networkManager = MultipeerNetworkManager()
        self.currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        setupNetworkCallbacks()
        setupGameEngineObservation()
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

        networkManager.$isHost
            .sink { [weak self] isHost in
                self?.isNetworkHost = isHost
                let isMultiplayer = self?.isMultiplayerMode ?? false
                self?.canControlGame = isHost || !isMultiplayer
            }
            .store(in: &cancellables)
    }

    private func setupGameEngineObservation() {
        // Observe game state changes and sync them
        gameEngine.$players
            .sink { [weak self] _ in
                self?.syncGameStateIfNeeded()
                self?.updatePlayersOnThisDevice()
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
    }

    // MARK: - Multiplayer Control

    func startHostingGame() {
        isMultiplayerMode = true
        isNetworkHost = true
        gameId = "Farkle-\(UUID().uuidString.prefix(8))"

        networkManager.startHosting(gameId: gameId)
        canControlGame = true

        print("🎮 Started hosting multiplayer game: \(gameId)")
    }

    func joinGame() {
        isMultiplayerMode = true
        isNetworkHost = false

        networkManager.startBrowsing()
        canControlGame = false // Will be updated when we connect

        print("🔍 Looking for multiplayer games...")
    }

    func leaveMultiplayerGame() {
        networkManager.stopNetworking()
        isMultiplayerMode = false
        isNetworkHost = false
        canControlGame = true
        gameId = ""
        playerDeviceAssignments.removeAll()
        playersOnThisDevice.removeAll()

        print("👋 Left multiplayer game")
    }

    // MARK: - Player Device Assignment

    func assignPlayerToDevice(_ playerId: String, deviceId: String) {
        guard isNetworkHost else { return }

        playerDeviceAssignments[playerId] = deviceId
        updatePlayersOnThisDevice()

        // Notify all clients of the assignment change
        broadcastPlayerAssignments()
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
            // Clients can control if it's their turn or if they have no assigned players (shared device mode)
            canControlGame = isCurrentPlayerOnThisDevice || playersOnThisDevice.isEmpty
        }
    }

    // MARK: - Game Actions with Network Support

    func addPlayer(name: String) {
        guard canControlGame else { return }

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
        guard canControlGame else { return }

        if index < gameEngine.players.count {
            let playerId = gameEngine.players[index].id.uuidString
            playerDeviceAssignments.removeValue(forKey: playerId)
        }

        gameEngine.removePlayer(at: index)
    }

    func startGame() {
        guard canControlGame else { return }

        gameEngine.startGame()

        if isMultiplayerMode && isNetworkHost {
            sendNetworkMessage(.gameStarted)
        }
    }

    func rollDice() -> [Int] {
        guard canControlGame || isCurrentPlayerOnThisDevice else { return [] }

        let result = gameEngine.rollDice()

        if isMultiplayerMode {
            sendNetworkMessage(.playerAction(.rollDice))
        }

        return result
    }

    func selectDice(_ dice: [Int]) {
        guard canControlGame || isCurrentPlayerOnThisDevice else { return }

        gameEngine.selectDice(dice)

        if isMultiplayerMode {
            sendNetworkMessage(.playerAction(.selectDice(dice)))
        }
    }

    func bankScore() {
        guard canControlGame || isCurrentPlayerOnThisDevice else { return }

        gameEngine.bankScore()

        if isMultiplayerMode {
            sendNetworkMessage(.playerAction(.bankScore))
        }
    }

    func acknowledgeFarkle() {
        guard canControlGame || isCurrentPlayerOnThisDevice else { return }

        gameEngine.acknowledgeFarkle()

        if isMultiplayerMode {
            sendNetworkMessage(.playerAction(.acknowledgeFarkle))
        }
    }

    // MARK: - Network Message Handling

    private func handleNetworkMessage(_ message: GameMessage, from peer: NetworkPeer) {
        switch message {
        case .gameStateSync(let gameStateData):
            if !isNetworkHost {
                applyGameStateSync(gameStateData)
            }

        case .playerAction(let action):
            if isNetworkHost {
                executePlayerAction(action, from: peer)
            }

        case .playerJoined(_):
            // Handle player joining from another device
            break

        case .playerLeft(_):
            // Handle player leaving
            break

        case .gameStarted:
            if !isNetworkHost {
                // Sync our game state with the host
                requestGameStateSync()
            }

        case .gameEnded:
            // Handle game end
            break

        case .ping, .pong:
            // Handled by network manager
            break
        }
    }

    private func executePlayerAction(_ action: GameMessage.PlayerAction, from peer: NetworkPeer) {
        // Only execute if the action is from a valid peer and it's their turn
        guard isNetworkHost else { return }

        switch action {
        case .rollDice:
            _ = gameEngine.rollDice()
        case .selectDice(let dice):
            gameEngine.selectDice(dice)
        case .bankScore:
            gameEngine.bankScore()
        case .nextTurn:
            gameEngine.skipPlayer()
        case .acknowledgeFarkle:
            gameEngine.acknowledgeFarkle()
        case .manualScore(let score):
            gameEngine.manualTurnScore = score
        case .undoLastAction:
            gameEngine.undoLastSelection()
        }

        // Sync the new state
        syncGameStateNow()
    }

    private func applyGameStateSync(_ gameStateData: GameStateData) {
        // Convert network data back to game engine state
        // This is a simplified version - you'd need to implement full state conversion
        gameEngine.currentPlayerIndex = gameStateData.currentPlayerIndex
        gameEngine.winningScore = gameStateData.winningScore
        gameEngine.currentRoll = gameStateData.currentRoll
        gameEngine.selectedDice = gameStateData.selectedDice
        gameEngine.remainingDice = gameStateData.remainingDice
        gameEngine.turnScore = gameStateData.turnScore
        gameEngine.isManualMode = gameStateData.isManualMode
        gameEngine.manualTurnScore = gameStateData.manualTurnScore
        gameEngine.pendingFarkle = gameStateData.pendingFarkle
        gameEngine.farklePlayerName = gameStateData.farklePlayerName
        gameEngine.farkleDice = gameStateData.farkleDice
        gameEngine.canUndo = gameStateData.canUndo
    }

    private func handlePeerConnected(_ peer: NetworkPeer) {
        print("✅ Player connected: \(peer.displayName)")

        if isNetworkHost {
            // Send current game state to new peer
            syncGameStateNow()
        }
    }

    private func handlePeerDisconnected(_ peer: NetworkPeer) {
        print("👋 Player disconnected: \(peer.displayName)")

        // Handle disconnection gracefully
        // Could reassign players from disconnected device to other devices
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
            pendingFarkle: gameEngine.pendingFarkle,
            farklePlayerName: gameEngine.farklePlayerName,
            farkleDice: gameEngine.farkleDice,
            canUndo: gameEngine.canUndo,
            finalRoundActive: gameEngine.isFinalRoundActive,
            finalRoundDescription: gameEngine.finalRoundDescription
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

    private func requestGameStateSync() {
        // Client requesting game state from host
        sendNetworkMessage(.ping) // Use ping as a simple game state request
    }

    private func sendNetworkMessage(_ message: GameMessage, to peers: [NetworkPeer]? = nil) {
        networkManager.sendMessage(message, to: peers)
    }

    private func broadcastPlayerAssignments() {
        // Create a message containing all player assignments
        // This could be enhanced with a dedicated message type
        syncGameStateNow()
    }

    // MARK: - Debug Testing Methods

    func enableDebugMode() {
        isDebugMode = true
        isMultiplayerMode = true
        isNetworkHost = true
        canControlGame = true
        connectionStatus = "Debug Mode - Simulated Network"

        // Add fake devices for testing
        connectedDevices = [
            NetworkPeer(id: "debug-device-1", displayName: "iPhone (Debug 1)", isHost: false),
            NetworkPeer(id: "debug-device-2", displayName: "iPad (Debug 2)", isHost: false)
        ]

        // Assign some players to different devices
        if gameEngine.players.count >= 2 {
            playerDeviceAssignments[gameEngine.players[0].id.uuidString] = currentDeviceId
            playerDeviceAssignments[gameEngine.players[1].id.uuidString] = "debug-device-1"
            if gameEngine.players.count >= 3 {
                playerDeviceAssignments[gameEngine.players[2].id.uuidString] = "debug-device-2"
            }
        }
    }

    func disableDebugMode() {
        isDebugMode = false
        leaveMultiplayerGame()
    }
}
