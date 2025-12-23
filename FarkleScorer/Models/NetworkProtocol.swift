import Foundation

// MARK: - Network Protocol
protocol NetworkManagerProtocol: ObservableObject {
    var isHost: Bool { get }
    var isConnected: Bool { get }
    var connectedPeers: [NetworkPeer] { get }
    var connectionState: ConnectionState { get }

    func startHosting(gameId: String)
    func startBrowsing()
    func stopNetworking()
    func sendMessage(_ message: GameMessage, to peers: [NetworkPeer]?)
    func disconnect()

    var onMessageReceived: ((GameMessage, NetworkPeer) -> Void)? { get set }
    var onPeerConnected: ((NetworkPeer) -> Void)? { get set }
    var onPeerDisconnected: ((NetworkPeer) -> Void)? { get set }
}

// MARK: - Network Peer
struct NetworkPeer: Identifiable, Hashable {
    let id: String
    let displayName: String
    let isHost: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NetworkPeer, rhs: NetworkPeer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Connection State
enum ConnectionState {
    case disconnected
    case browsing
    case hosting
    case connecting
    case connected

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .browsing: return "Looking for games..."
        case .hosting: return "Hosting game"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        }
    }
}

// MARK: - Game Messages
enum GameMessage: Codable {
    case gameStateSync(GameStateData)
    case playerAction(PlayerAction)
    case playerJoined(PlayerData)
    case playerLeft(playerId: String)
    case gameStarted
    case gameEnded
    case ping
    case pong

    enum PlayerAction: Codable {
        case rollDice
        case selectDice([Int])
        case bankScore
        case nextTurn
        case acknowledgeFarkle
        case manualScore(Int)
        case undoLastAction
    }
}

// MARK: - Data Transfer Objects
struct GameStateData: Codable {
    let players: [PlayerData]
    let currentPlayerIndex: Int
    let gameState: GameStateValue
    let winningScore: Int
    let currentRoll: [Int]
    let selectedDice: [Int]
    let remainingDice: Int
    let turnScore: Int
    let isManualMode: Bool
    let manualTurnScore: Int
    let pendingFarkle: Bool
    let farklePlayerName: String
    let farkleDice: [Int]
    let canUndo: Bool
    let finalRoundActive: Bool
    let finalRoundDescription: String

    enum GameStateValue: String, Codable {
        case setup, playing, finalRound, gameOver
    }
}

struct PlayerData: Codable, Identifiable {
    let id: String
    let name: String
    let totalScore: Int
    let roundScore: Int
    let isOnBoard: Bool
    let consecutiveFarkles: Int
    let assignedDeviceId: String? // Which device this player is assigned to
    let gameHistory: [TurnData]

    struct TurnData: Codable, Identifiable {
        let id: String
        let diceRolled: [Int]
        let selectedDice: [Int]
        let score: Int
        let isFarkle: Bool
        let isSixDiceFarkle: Bool
        let timestamp: Date
    }
}

// MARK: - Network Error
enum NetworkError: Error, LocalizedError {
    case connectionFailed
    case messageSerializationFailed
    case hostDisconnected
    case peerNotFound
    case gameNotFound

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Failed to connect to game"
        case .messageSerializationFailed: return "Failed to send message"
        case .hostDisconnected: return "Host disconnected"
        case .peerNotFound: return "Player not found"
        case .gameNotFound: return "Game not found"
        }
    }
}
