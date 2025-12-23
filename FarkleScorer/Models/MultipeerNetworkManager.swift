import Foundation
import MultipeerConnectivity
import Combine
import UIKit

class MultipeerNetworkManager: NSObject, NetworkManagerProtocol, ObservableObject {

    // MARK: - NetworkManagerProtocol Properties
    @Published var isHost: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectedPeers: [NetworkPeer] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredHosts: [DiscoveredHost] = []

    var onMessageReceived: ((GameMessage, NetworkPeer) -> Void)?
    var onPeerConnected: ((NetworkPeer) -> Void)?
    var onPeerDisconnected: ((NetworkPeer) -> Void)?

    // MARK: - Stable Device Identity
    /// Stable UUID for this device (persisted across app launches)
    let localDeviceId: String
    
    // MARK: - Current Game Info
    private(set) var currentGameId: String = ""
    private(set) var playerCount: Int = 0

    // MARK: - MultipeerConnectivity Properties
    private var peerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let serviceType = "farkle-game"

    // MARK: - Peer Identity Mapping
    /// Maps MCPeerID to stable device ID (received via handshake)
    private var peerToDeviceId: [MCPeerID: String] = [:]
    /// Maps stable device ID to MCPeerID
    private var deviceIdToPeer: [String: MCPeerID] = [:]
    /// Maps MCPeerID to NetworkPeer
    private var peerMapping: [MCPeerID: NetworkPeer] = [:]
    
    // MARK: - Discovery State
    /// Maps MCPeerID to DiscoveredHost (for browsing clients)
    private var discoveredPeers: [MCPeerID: DiscoveredHost] = [:]
    /// Pending connection target (when user selects a host)
    private var pendingConnectionTarget: MCPeerID?

    // MARK: - Connection Management
    private var connectionTimer: Timer?
    private var pingTimer: Timer?
    private let maxReconnectAttempts = 3
    private var reconnectAttempts: [MCPeerID: Int] = [:]
    
    // MARK: - Handshake State
    private var pendingHandshakes: Set<MCPeerID> = []
    private var completedHandshakes: Set<MCPeerID> = []

    override init() {
        // Load or create stable device ID
        if let savedId = UserDefaults.standard.string(forKey: "stableDeviceId") {
            self.localDeviceId = savedId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "stableDeviceId")
            self.localDeviceId = newId
        }
        
        // Create peer ID with device name (for display) but we use localDeviceId for identity
        let deviceName = UIDevice.current.name
        self.peerID = MCPeerID(displayName: deviceName)

        super.init()
        
        createSession()
        startPingTimer()
    }

    deinit {
        stopNetworking()
        connectionTimer?.invalidate()
        pingTimer?.invalidate()
    }
    
    // MARK: - Session Management
    
    private func createSession() {
        // Use encrypted sessions for security (required for App Store)
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session?.delegate = self
    }
    
    private func recreateSession() {
        session?.disconnect()
        session = nil
        createSession()
    }

    // MARK: - NetworkManagerProtocol Implementation

    func startHosting(gameId: String) {
        stopCurrentNetworking()
        recreateSession()

        isHost = true
        currentGameId = gameId
        connectionState = .hosting

        // Create advertiser with game metadata including stable device ID
        let discoveryInfo: [String: String] = [
            "gameId": gameId,
            "deviceId": localDeviceId,
            "hostName": peerID.displayName,
            "version": ProtocolConstants.appVersion,
            "playerCount": "0"
        ]

        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )

        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        print("🎮 Started hosting Farkle game: \(gameId) [deviceId: \(localDeviceId.prefix(8))...]")
    }
    
    /// Update the advertised player count (call when players change)
    func updateAdvertisedPlayerCount(_ count: Int) {
        guard isHost else { return }
        playerCount = count
        
        // Restart advertiser with updated info
        advertiser?.stopAdvertisingPeer()
        
        let discoveryInfo: [String: String] = [
            "gameId": currentGameId,
            "deviceId": localDeviceId,
            "hostName": peerID.displayName,
            "version": ProtocolConstants.appVersion,
            "playerCount": "\(count)"
        ]
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startBrowsing() {
        stopCurrentNetworking()
        recreateSession()

        isHost = false
        connectionState = .browsing
        discoveredHosts.removeAll()
        discoveredPeers.removeAll()

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        print("🔍 Started browsing for Farkle games [deviceId: \(localDeviceId.prefix(8))...]")
    }
    
    func connectToHost(_ host: DiscoveredHost) {
        guard let mcPeerID = discoveredPeers.first(where: { $0.value.id == host.id })?.key else {
            print("❌ Cannot connect: host not found in discovered peers")
            return
        }
        
        guard let session = session else {
            print("❌ Cannot connect: no session")
            return
        }
        
        pendingConnectionTarget = mcPeerID
        connectionState = .connecting
        
        // Create context with our device ID for the handshake
        let contextData: [String: String] = [
            "deviceId": localDeviceId,
            "displayName": peerID.displayName,
            "version": ProtocolConstants.appVersion
        ]
        
        let context = try? JSONEncoder().encode(contextData)
        
        // Send invitation to the specific host
        browser?.invitePeer(mcPeerID, to: session, withContext: context, timeout: 30)
        
        print("📤 Sent connection request to: \(host.displayName)")
    }

    func stopNetworking() {
        stopCurrentNetworking()
        session?.disconnect()
        connectionState = .disconnected
        isConnected = false
        connectedPeers.removeAll()
        peerMapping.removeAll()
        peerToDeviceId.removeAll()
        deviceIdToPeer.removeAll()
        discoveredHosts.removeAll()
        discoveredPeers.removeAll()
        pendingHandshakes.removeAll()
        completedHandshakes.removeAll()
        reconnectAttempts.removeAll()
        pendingConnectionTarget = nil
        currentGameId = ""

        print("📴 Stopped all networking")
    }

    func disconnect() {
        stopNetworking()
    }

    func sendMessage(_ message: GameMessage, to peers: [NetworkPeer]?) {
        guard let session = session else { return }
        guard !peerMapping.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(message)

            // Determine target peers
            let targetPeers: [MCPeerID]
            if let specificPeers = peers {
                targetPeers = specificPeers.compactMap { networkPeer in
                    deviceIdToPeer[networkPeer.id]
                }
            } else {
                targetPeers = Array(peerMapping.keys)
            }

            guard !targetPeers.isEmpty else { return }

            // Determine delivery mode based on message importance
            let mode: MCSessionSendDataMode = messageDeliveryMode(for: message)

            try session.send(data, toPeers: targetPeers, with: mode)

        } catch {
            print("❌ Failed to send message: \(error)")
        }
    }
    
    /// Send a message that bypasses throttling (for critical messages)
    func sendMessageImmediately(_ message: GameMessage, to peers: [NetworkPeer]?) {
        sendMessage(message, to: peers)
    }

    // MARK: - Private Methods

    private func stopCurrentNetworking() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        connectionTimer?.invalidate()
        connectionTimer = nil
    }

    /// Determine delivery mode based on message type
    /// Critical messages use reliable delivery, frequent updates can use unreliable
    private func messageDeliveryMode(for message: GameMessage) -> MCSessionSendDataMode {
        switch message {
        // Critical messages - must be delivered reliably
        case .hello, .welcome, .requestFullSync:
            return .reliable
        case .roundStateSync, .turnSubmission, .forceAdvanceRound, .roundStarted:
            return .reliable
        case .gameStarted, .gameEnded, .playerJoined, .playerLeft:
            return .reliable
        case .playerAction:
            return .reliable
        case .gameStateSync:
            return .reliable  // Changed: state sync is critical
            
        // Non-critical messages - can use unreliable for performance
        case .turnProgress:
            return .unreliable  // Frequent updates, okay to drop some
        case .ping, .pong:
            return .unreliable
        }
    }

    private func createNetworkPeer(from mcPeerID: MCPeerID, deviceId: String, isHost: Bool) -> NetworkPeer {
        return NetworkPeer(
            id: deviceId,
            displayName: mcPeerID.displayName,
            isHost: isHost
        )
    }

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPingToAllPeers()
        }
    }

    private func sendPingToAllPeers() {
        guard isConnected else { return }
        sendMessage(.ping, to: nil)
    }

    private func handlePeerDisconnection(_ peerID: MCPeerID) {
        guard let networkPeer = peerMapping[peerID] else { return }
        
        let deviceId = peerToDeviceId[peerID]

        peerMapping.removeValue(forKey: peerID)
        peerToDeviceId.removeValue(forKey: peerID)
        if let deviceId = deviceId {
            deviceIdToPeer.removeValue(forKey: deviceId)
        }
        pendingHandshakes.remove(peerID)
        completedHandshakes.remove(peerID)
        
        connectedPeers.removeAll { $0.id == networkPeer.id }

        if connectedPeers.isEmpty {
            isConnected = false
            connectionState = isHost ? .hosting : .browsing
        }

        onPeerDisconnected?(networkPeer)

        print("👋 Peer disconnected: \(networkPeer.displayName) [deviceId: \(networkPeer.id.prefix(8))...]")

        // If we're not the host and the host disconnected, reset to browsing
        if !isHost && networkPeer.isHost {
            startBrowsing()
        }
    }

    private func attemptReconnection(to peerID: MCPeerID) {
        let attempts = reconnectAttempts[peerID, default: 0]
        guard attempts < maxReconnectAttempts else {
            reconnectAttempts.removeValue(forKey: peerID)
            return
        }

        reconnectAttempts[peerID] = attempts + 1

        // Wait before reconnecting to avoid spam
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempts + 1)) { [weak self] in
            guard let self = self else { return }

            if !self.isHost {
                // Try browsing again to find the peer
                self.browser?.startBrowsingForPeers()
            }
        }
    }
    
    // MARK: - Handshake Processing
    
    /// Process incoming hello from a client (host side)
    func processHello(_ helloData: HelloData, from mcPeerID: MCPeerID) {
        guard isHost else { return }
        
        // Register the peer's device ID
        peerToDeviceId[mcPeerID] = helloData.deviceId
        deviceIdToPeer[helloData.deviceId] = mcPeerID
        
        // Create and store the network peer
        let networkPeer = createNetworkPeer(from: mcPeerID, deviceId: helloData.deviceId, isHost: false)
        peerMapping[mcPeerID] = networkPeer
        
        if !connectedPeers.contains(where: { $0.id == networkPeer.id }) {
            connectedPeers.append(networkPeer)
        }
        
        completedHandshakes.insert(mcPeerID)
        pendingHandshakes.remove(mcPeerID)
        
        isConnected = true
        connectionState = .connected
        
        print("✅ Handshake complete with client: \(helloData.displayName) [deviceId: \(helloData.deviceId.prefix(8))...]")
        
        onPeerConnected?(networkPeer)
    }
    
    /// Process incoming welcome from host (client side)
    func processWelcome(_ welcomeData: WelcomeData, from mcPeerID: MCPeerID) {
        guard !isHost else { return }
        
        // Register the host's device ID
        peerToDeviceId[mcPeerID] = welcomeData.hostDeviceId
        deviceIdToPeer[welcomeData.hostDeviceId] = mcPeerID
        
        // Create and store the network peer (as host)
        let networkPeer = createNetworkPeer(from: mcPeerID, deviceId: welcomeData.hostDeviceId, isHost: true)
        peerMapping[mcPeerID] = networkPeer
        
        if !connectedPeers.contains(where: { $0.id == networkPeer.id }) {
            connectedPeers.append(networkPeer)
        }
        
        completedHandshakes.insert(mcPeerID)
        pendingHandshakes.remove(mcPeerID)
        
        isConnected = true
        connectionState = .connected
        
        print("✅ Received welcome from host: \(mcPeerID.displayName) [deviceId: \(welcomeData.hostDeviceId.prefix(8))...]")
        
        onPeerConnected?(networkPeer)
    }
    
    /// Get the MCPeerID for a device ID
    func getMCPeerID(for deviceId: String) -> MCPeerID? {
        return deviceIdToPeer[deviceId]
    }
    
    /// Get the device ID for an MCPeerID
    func getDeviceId(for mcPeerID: MCPeerID) -> String? {
        return peerToDeviceId[mcPeerID]
    }
}

// MARK: - MCSessionDelegate

extension MultipeerNetworkManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch state {
            case .connecting:
                print("🤝 Connecting to: \(peerID.displayName)")
                self.connectionState = .connecting
                self.pendingHandshakes.insert(peerID)

            case .connected:
                print("🔗 Session connected to: \(peerID.displayName)")
                
                // For clients: send hello to initiate handshake
                if !self.isHost {
                    let hello = HelloData(
                        deviceId: self.localDeviceId,
                        displayName: self.peerID.displayName,
                        appVersion: ProtocolConstants.appVersion,
                        gameId: self.currentGameId
                    )
                    self.sendMessage(.hello(hello), to: nil)
                    print("📤 Sent hello to host")
                }
                
                // Don't set connected state yet - wait for handshake
                self.reconnectAttempts.removeValue(forKey: peerID)

            case .notConnected:
                print("❌ Disconnected from: \(peerID.displayName)")
                self.handlePeerDisconnection(peerID)
                self.attemptReconnection(to: peerID)

            @unknown default:
                print("⚠️ Unknown connection state for: \(peerID.displayName)")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Handle ping/pong internally
                if case .ping = message {
                    if let networkPeer = self.peerMapping[peerID] {
                        self.sendMessage(.pong, to: [networkPeer])
                    }
                    return
                } else if case .pong = message {
                    return
                }
                
                // Handle handshake messages
                if case .hello(let helloData) = message {
                    self.processHello(helloData, from: peerID)
                    // Forward to game engine for welcome response
                    if let networkPeer = self.peerMapping[peerID] {
                        self.onMessageReceived?(message, networkPeer)
                    }
                    return
                }
                
                if case .welcome(let welcomeData) = message {
                    self.processWelcome(welcomeData, from: peerID)
                    // Forward to game engine for state setup
                    if let networkPeer = self.peerMapping[peerID] {
                        self.onMessageReceived?(message, networkPeer)
                    }
                    return
                }
                
                // For other messages, require completed handshake
                guard let networkPeer = self.peerMapping[peerID] else {
                    print("⚠️ Received message from unknown peer: \(peerID.displayName)")
                    return
                }

                self.onMessageReceived?(message, networkPeer)
            }

        } catch {
            print("❌ Failed to decode message from \(peerID.displayName): \(error)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used for this implementation
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used for this implementation
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used for this implementation
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerNetworkManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {

        print("📨 Received connection request from: \(peerID.displayName)")
        
        // Parse context to get client's device ID
        var clientDeviceId: String?
        if let context = context,
           let contextData = try? JSONDecoder().decode([String: String].self, from: context) {
            clientDeviceId = contextData["deviceId"]
            print("   Client deviceId: \(clientDeviceId?.prefix(8) ?? "unknown")...")
        }

        // Accept the invitation
        invitationHandler(true, session)
        
        // Store pending handshake info
        pendingHandshakes.insert(peerID)
        
        // Note: Full handshake completes when we receive their hello message
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Failed to start advertising: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerNetworkManager: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        guard let info = info else {
            print("⚠️ Found peer without discovery info: \(peerID.displayName)")
            return
        }
        
        // Extract host information
        let gameId = info["gameId"] ?? "Unknown"
        let deviceId = info["deviceId"] ?? peerID.displayName
        let hostName = info["hostName"] ?? peerID.displayName
        let version = info["version"] ?? "1.0"
        let playerCount = Int(info["playerCount"] ?? "0") ?? 0
        
        print("🎯 Found game host: \(hostName) [gameId: \(gameId), deviceId: \(deviceId.prefix(8))...]")
        
        // Create discovered host entry
        let discoveredHost = DiscoveredHost(
            id: deviceId,
            displayName: hostName,
            gameId: gameId,
            playerCount: playerCount,
            appVersion: version
        )
        
        // Store mapping and update published list
        discoveredPeers[peerID] = discoveredHost
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update or add to discovered hosts list
            if let existingIndex = self.discoveredHosts.firstIndex(where: { $0.id == deviceId }) {
                self.discoveredHosts[existingIndex] = discoveredHost
            } else {
                self.discoveredHosts.append(discoveredHost)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("📡 Lost peer: \(peerID.displayName)")
        
        // Remove from discovered hosts
        if let discoveredHost = discoveredPeers[peerID] {
            discoveredPeers.removeValue(forKey: peerID)
            
            DispatchQueue.main.async { [weak self] in
                self?.discoveredHosts.removeAll { $0.id == discoveredHost.id }
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Failed to start browsing: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}
