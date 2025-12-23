import Foundation
import MultipeerConnectivity
import Combine

class MultipeerNetworkManager: NSObject, NetworkManagerProtocol, ObservableObject {

    // MARK: - NetworkManagerProtocol Properties
    @Published var isHost: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectedPeers: [NetworkPeer] = []
    @Published var connectionState: ConnectionState = .disconnected

    var onMessageReceived: ((GameMessage, NetworkPeer) -> Void)?
    var onPeerConnected: ((NetworkPeer) -> Void)?
    var onPeerDisconnected: ((NetworkPeer) -> Void)?

    // MARK: - MultipeerConnectivity Properties
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let serviceType = "farkle-game"

    // MARK: - Connection Management
    private var peerMapping: [MCPeerID: NetworkPeer] = [:]
    private var connectionTimer: Timer?
    private var pingTimer: Timer?
    private let maxReconnectAttempts = 3
    private var reconnectAttempts: [MCPeerID: Int] = [:]

    // MARK: - Battery Optimization
    private var lastMessageTime: Date = Date()
    private let messageThrottleInterval: TimeInterval = 0.1 // Limit messages to 10/second

    override init() {
        // Create unique peer ID based on device name
        let deviceName = UIDevice.current.name
        self.peerID = MCPeerID(displayName: deviceName)

        // Initialize session with security settings for battery optimization
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none // Faster, uses less battery for local network
        )

        super.init()

        session.delegate = self
        startPingTimer()
    }

    deinit {
        stopNetworking()
        connectionTimer?.invalidate()
        pingTimer?.invalidate()
    }

    // MARK: - NetworkManagerProtocol Implementation

    func startHosting(gameId: String) {
        stopCurrentNetworking()

        isHost = true
        connectionState = .hosting

        // Create advertiser with game metadata
        let discoveryInfo = [
            "gameId": gameId,
            "hostName": peerID.displayName,
            "version": "1.0"
        ]

        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )

        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        print("🎮 Started hosting Farkle game: \(gameId)")
    }

    func startBrowsing() {
        stopCurrentNetworking()

        isHost = false
        connectionState = .browsing

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        print("🔍 Started browsing for Farkle games")
    }

    func stopNetworking() {
        stopCurrentNetworking()
        session.disconnect()
        connectionState = .disconnected
        isConnected = false
        connectedPeers.removeAll()
        peerMapping.removeAll()
        reconnectAttempts.removeAll()

        print("📴 Stopped all networking")
    }

    func disconnect() {
        stopNetworking()
    }

    func sendMessage(_ message: GameMessage, to peers: [NetworkPeer]?) {
        guard !connectedPeers.isEmpty else { return }

        // Battery optimization: throttle messages
        let now = Date()
        if now.timeIntervalSince(lastMessageTime) < messageThrottleInterval {
            return
        }
        lastMessageTime = now

        do {
            let data = try JSONEncoder().encode(message)

            // Determine target peers
            let targetPeers: [MCPeerID]
            if let specificPeers = peers {
                targetPeers = specificPeers.compactMap { networkPeer in
                    peerMapping.first { $0.value.id == networkPeer.id }?.key
                }
            } else {
                targetPeers = Array(peerMapping.keys)
            }

            guard !targetPeers.isEmpty else { return }

            // Send with reliable delivery for important messages, unreliable for frequent updates
            let mode: MCSessionSendDataMode = isImportantMessage(message) ? .reliable : .unreliable

            try session.send(data, toPeers: targetPeers, with: mode)

        } catch {
            print("❌ Failed to send message: \(error)")
        }
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

    private func isImportantMessage(_ message: GameMessage) -> Bool {
        switch message {
        case .gameStateSync, .gameStarted, .gameEnded:
            return false // These can be sent unreliably for better performance
        case .playerAction, .playerJoined, .playerLeft:
            return true // These need guaranteed delivery
        case .ping, .pong:
            return false
        }
    }

    private func createNetworkPeer(from mcPeerID: MCPeerID, isHost: Bool = false) -> NetworkPeer {
        return NetworkPeer(
            id: mcPeerID.displayName,
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

        peerMapping.removeValue(forKey: peerID)
        connectedPeers.removeAll { $0.id == networkPeer.id }

        if connectedPeers.isEmpty {
            isConnected = false
            connectionState = isHost ? .hosting : .browsing
        }

        onPeerDisconnected?(networkPeer)

        print("👋 Peer disconnected: \(networkPeer.displayName)")

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

            case .connected:
                print("✅ Connected to: \(peerID.displayName)")

                let networkPeer = self.createNetworkPeer(from: peerID, isHost: !self.isHost)
                self.peerMapping[peerID] = networkPeer

                if !self.connectedPeers.contains(where: { $0.id == networkPeer.id }) {
                    self.connectedPeers.append(networkPeer)
                }

                self.isConnected = true
                self.connectionState = .connected
                self.reconnectAttempts.removeValue(forKey: peerID)

                self.onPeerConnected?(networkPeer)

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
        guard let networkPeer = peerMapping[peerID] else { return }

        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)

            DispatchQueue.main.async { [weak self] in
                // Handle ping/pong for connection health
                if case .ping = message {
                    self?.sendMessage(.pong, to: [networkPeer])
                    return
                } else if case .pong = message {
                    return // Just acknowledge the pong
                }

                self?.onMessageReceived?(message, networkPeer)
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

        print("📨 Received invitation from: \(peerID.displayName)")

        // Auto-accept invitations as host
        invitationHandler(true, session)
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

        print("🎯 Found game host: \(peerID.displayName)")

        // Auto-invite to join the game
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("📡 Lost peer: \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Failed to start browsing: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
}
