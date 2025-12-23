import Foundation

// MARK: - Network Protocol
protocol NetworkManagerProtocol: ObservableObject {
    var isHost: Bool { get }
    var isConnected: Bool { get }
    var connectedPeers: [NetworkPeer] { get }
    var connectionState: ConnectionState { get }
    var discoveredHosts: [DiscoveredHost] { get }

    func startHosting(gameId: String)
    func startBrowsing()
    func stopNetworking()
    func sendMessage(_ message: GameMessage, to peers: [NetworkPeer]?)
    func disconnect()
    func connectToHost(_ host: DiscoveredHost)

    var onMessageReceived: ((GameMessage, NetworkPeer) -> Void)? { get set }
    var onPeerConnected: ((NetworkPeer) -> Void)? { get set }
    var onPeerDisconnected: ((NetworkPeer) -> Void)? { get set }
}

// MARK: - Discovered Host (for pick-from-list join flow)
struct DiscoveredHost: Identifiable, Hashable, Codable {
    let id: String           // Stable device ID
    let displayName: String  // Human-readable name
    let gameId: String       // Short game code
    let playerCount: Int     // Current number of players
    let appVersion: String   // For compatibility checks
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiscoveredHost, rhs: DiscoveredHost) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Network Peer (with stable device identity)
struct NetworkPeer: Identifiable, Hashable, Codable {
    let id: String           // Stable device ID (UUID)
    let displayName: String  // Human-readable device name
    let isHost: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NetworkPeer, rhs: NetworkPeer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Connection State
enum ConnectionState: String, Codable {
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

// MARK: - Game Messages (v2 protocol with handshake + simultaneous rounds)
enum GameMessage: Codable {
    // MARK: Handshake & Identity
    /// Client sends to host upon connection
    case hello(HelloData)
    /// Host sends to client after accepting hello
    case welcome(WelcomeData)
    /// Request full game state resync (client → host)
    case requestFullSync
    
    // MARK: Round Coordination (simultaneous rounds)
    /// Host broadcasts current round state to all clients
    case roundStateSync(RoundStateData)
    /// Client submits their completed turn to host
    case turnSubmission(TurnSubmissionData)
    /// Client broadcasts live turn progress (for spectating)
    case turnProgress(TurnProgressData)
    /// Host forces round advancement (with reason)
    case forceAdvanceRound(ForceAdvanceReason)
    /// Host signals round is starting
    case roundStarted(roundNumber: Int)
    
    // MARK: Legacy Game State (kept for compatibility during transition)
    case gameStateSync(GameStateData)
    case playerAction(PlayerAction)
    case playerJoined(PlayerData)
    case playerLeft(playerId: String)
    case gameStarted
    case gameEnded
    
    // MARK: Connection Health
    case ping
    case pong

    enum PlayerAction: Codable {
        case rollDice
        case selectDice([Int])
        case bankScore
        case nextTurn  // Legacy alias, prefer skipTurn
        case skipTurn  // Canonical turn-skip action
        case acknowledgeFarkle
        case manualScore(Int)
        case undoLastAction
        case continueRolling  // Keep rolling with current selection
    }
}

// MARK: - Handshake DTOs

/// Sent by client to host upon connection
struct HelloData: Codable {
    let deviceId: String        // Stable UUID for this device
    let displayName: String     // Human-readable device name
    let appVersion: String      // For compatibility checks
    let gameId: String          // Game code the client wants to join
}

/// Sent by host to client after accepting hello
struct WelcomeData: Codable {
    let hostDeviceId: String           // Host's stable device ID
    let gameConfig: GameConfigData     // Current game rules
    let roster: [PlayerRosterEntry]    // All players with assignments
    let currentRoundState: RoundStateData  // Current round status
    let protocolVersion: Int           // For future compatibility (currently 2)
}

/// Game configuration/rules
struct GameConfigData: Codable {
    let gameId: String
    let winningScore: Int
    let require500Opening: Bool
    let openingScoreThreshold: Int
    let enableTripleFarkleRule: Bool
    let tripleFarklePenalty: Int
    let scoringRules: ScoringRulesStore
}

/// Player roster entry with device assignment
struct PlayerRosterEntry: Codable, Identifiable {
    let id: String              // Player UUID
    let name: String
    let totalScore: Int
    let isOnBoard: Bool
    let consecutiveFarkles: Int
    let assignedDeviceId: String?  // Which device controls this player
}

// MARK: - Simultaneous Round DTOs

/// Current state of a simultaneous round
struct RoundStateData: Codable {
    let roundNumber: Int
    let gamePhase: GamePhase
    let playerStatuses: [PlayerRoundStatus]
    let submittedTurns: [SubmittedTurnResult]  // Results from this round
    let isFinalRound: Bool
    let finalRoundTriggerPlayerId: String?
    let timestamp: Date
    
    enum GamePhase: String, Codable {
        case setup          // Game not started yet
        case roundInProgress  // Players are taking turns
        case roundComplete   // All players submitted, waiting for host to advance
        case gameOver       // Game ended
    }
}

/// Per-player status within a round
struct PlayerRoundStatus: Codable, Identifiable {
    let id: String  // Player ID
    let playerId: String
    let playerName: String
    let status: TurnStatus
    let assignedDeviceId: String?
    
    enum TurnStatus: String, Codable {
        case pending     // Hasn't started their turn yet
        case inProgress  // Currently playing
        case submitted   // Turn result submitted
        case skipped     // Host force-skipped this player
    }
}

/// Result of a single turn submission
struct TurnSubmissionData: Codable {
    let playerId: String
    let deviceId: String          // Which device submitted this
    let turnResult: TurnResultData
    let timestamp: Date
}

/// The actual turn result (what happened during the turn)
struct TurnResultData: Codable {
    let scoreEarned: Int          // Points banked this turn (0 if farkle)
    let isFarkle: Bool
    let wasManualMode: Bool
    let rolls: [RollRecord]       // History of rolls in this turn
    
    struct RollRecord: Codable {
        let diceRolled: [Int]
        let diceSelected: [Int]
        let scoreFromSelection: Int
    }
}

/// Submitted turn that's been accepted by host
struct SubmittedTurnResult: Codable, Identifiable {
    let id: String  // Unique submission ID
    let playerId: String
    let playerName: String
    let turnResult: TurnResultData
    let newTotalScore: Int
    let newIsOnBoard: Bool
    let submittedAt: Date
}

/// Reason for host forcing round advancement
enum ForceAdvanceReason: Codable {
    case timeout                    // Player took too long
    case playerDisconnected(playerId: String)
    case hostOverride               // Host manually chose to advance
}

/// Live turn progress for spectating (sent from client to host)
struct TurnProgressData: Codable {
    let playerId: String
    let playerName: String
    let deviceId: String
    let currentRoll: [Int]           // Current dice showing
    let selectedDice: [Int]          // Dice player has selected
    let turnScore: Int               // Running score this turn
    let rollCount: Int               // Number of rolls this turn
    let remainingDice: Int           // Dice left to roll
    let isPendingFarkle: Bool        // Did they just farkle?
    let timestamp: Date
}

// MARK: - Legacy Data Transfer Objects (kept for compatibility)

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
    let manualScoreHistory: [Int]
    let pendingFarkle: Bool
    let farklePlayerName: String
    let farkleDice: [Int]
    let canUndo: Bool
    let finalRoundActive: Bool
    let finalRoundDescription: String
    
    // MARK: - Game Rules (synced from host)
    let require500Opening: Bool
    let openingScoreThreshold: Int
    let enableTripleFarkleRule: Bool
    let tripleFarklePenalty: Int
    
    // MARK: - Scoring Rules (house rules, synced from host)
    let scoringRules: ScoringRulesStore

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
    let assignedDeviceId: String?
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
    case versionMismatch(hostVersion: String, clientVersion: String)
    case gameIdMismatch
    case handshakeFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Failed to connect to game"
        case .messageSerializationFailed: return "Failed to send message"
        case .hostDisconnected: return "Host disconnected"
        case .peerNotFound: return "Player not found"
        case .gameNotFound: return "Game not found"
        case .versionMismatch(let host, let client): 
            return "Version mismatch: host \(host), you \(client)"
        case .gameIdMismatch: return "Game ID doesn't match"
        case .handshakeFailed: return "Failed to establish connection"
        }
    }
}

// MARK: - Protocol Version
struct ProtocolConstants {
    static let currentVersion = 2
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}
