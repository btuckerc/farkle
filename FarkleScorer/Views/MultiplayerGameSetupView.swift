import SwiftUI

struct MultiplayerGameSetupView: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @State private var newPlayerName = ""
    @State private var showingRules = false
    @State private var showingNetworkInfo = false
    @State private var showingSettings = false

    var gameEngine: GameEngine {
        multiplayerGameEngine.gameEngine
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Streamlined Header (no app name, focused on context)
                        VStack(spacing: 16) {
                            HStack {
                                Text("New Game")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Spacer()

                                // Network status indicator
                                if multiplayerGameEngine.isMultiplayerMode {
                                    Button(action: { showingNetworkInfo = true }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(connectionColor)
                                                .frame(width: 8, height: 8)

                                            Text(multiplayerGameEngine.isNetworkHost ? "HOST" : "CLIENT")
                                                .farkleCaption()
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.top, 12)

                            Text(multiplayerGameEngine.isMultiplayerMode ? "Multi-Phone Game Setup" : "Configure your game")
                                .farkleSection()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .background(Color(.systemBackground))

                    VStack(spacing: 24) {
                        // Players Section (Flip7-style card)
                        PlayersCard(
                            gameEngine: gameEngine,
                            canEdit: !multiplayerGameEngine.isMultiplayerMode || multiplayerGameEngine.isNetworkHost
                        )

                        // Multiplayer Setup Section (moved to middle)
                        MultiplayerSetupSection(multiplayerGameEngine: multiplayerGameEngine)

                        // Game Rules Configuration (moved to middle - only show if host or single player)
                        if !multiplayerGameEngine.isMultiplayerMode || multiplayerGameEngine.isNetworkHost {
                            GameRulesSection(gameEngine: gameEngine)
                        }

                        // Scoring Customization Section (moved to bottom - only show if host or single player)
                        if !multiplayerGameEngine.isMultiplayerMode || multiplayerGameEngine.isNetworkHost {
                            FullScoringCustomizationSection(gameEngine: gameEngine)
                        }

                        // Quick Rules Reference

                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for start button
                }
            }

                        // Fixed Start Game Button with subtle shadow
            VStack(spacing: 0) {
                FullStartGameSection(multiplayerGameEngine: multiplayerGameEngine)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .padding(.top, 12)
            }
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2)
            )
        }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRules = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingRules) {
            FarkleRulesView()
        }
        .sheet(isPresented: $showingNetworkInfo) {
            NetworkInfoView(multiplayerGameEngine: multiplayerGameEngine)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(gameEngine: gameEngine)
        }
    }

    private var connectionColor: Color {
        switch multiplayerGameEngine.networkManager.connectionState {
        case .disconnected:
            return .gray
        case .browsing, .connecting:
            return .orange
        case .hosting, .connected:
            return .green
        }
    }
}

// MARK: - Scoring Customization Section

struct FullScoringCustomizationSection: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var isExpanded = false
    @State private var showingScoringCustomization = false

    var body: some View {
        FarkleCard {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(spacing: 12) {
                        Text("Customize point values for different dice combinations to create house rules or balance gameplay.")
                            .farkleCaption()
                            .padding(.top, 8)

                        Button(action: { showingScoringCustomization = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                Text("Open Scoring Editor")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.top, 12)
                },
                label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scoring Customization")
                                .farkleSection()

                            Text(isExpanded ? "Tap to hide options" : "Tap to customize point values")
                                .farkleCaption()
                        }

                        Spacer()
                    }
                }
            )
        }
        .sheet(isPresented: $showingScoringCustomization) {
            ScoringCustomizationView(gameEngine: gameEngine)
        }
    }
}

// MARK: - Multiplayer Setup Section

struct MultiplayerSetupSection: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !multiplayerGameEngine.isMultiplayerMode {
                // Collapsible Device Setup for Single Device Mode
                DisclosureGroup(
                    isExpanded: $isExpanded,
                    content: {
                        VStack(spacing: 16) {
                            MultiPhoneOptionsView(multiplayerGameEngine: multiplayerGameEngine)

                            // Debug mode only visible when expanded
                            #if DEBUG
                            DebugModeOption(multiplayerGameEngine: multiplayerGameEngine)
                            #endif
                        }
                        .padding(.top, 12)
                    },
                    label: {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.gen3")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Single Device")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text("ACTIVE")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(4)
                                }

                                Text(isExpanded ? "Tap to hide multi-phone options" : "Tap to see multi-phone options")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                )
            } else {
                // Multiplayer Active View (always visible when connected)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Device Setup")
                        .font(.title2)
                        .fontWeight(.semibold)

                    MultiplayerActiveView(multiplayerGameEngine: multiplayerGameEngine)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Component Views

struct MultiPhoneOptionsView: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine

    var body: some View {
        VStack(spacing: 8) {
            Text("Switch to Multi-Phone:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                HostGameButton(multiplayerGameEngine: multiplayerGameEngine)
                JoinGameButton(multiplayerGameEngine: multiplayerGameEngine)
            }
        }
    }
}

struct HostGameButton: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine

    var body: some View {
        Button(action: {
            multiplayerGameEngine.startHostingGame()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.router")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Host Game")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("Start a game for others to join")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct JoinGameButton: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @State private var showingHostSelection = false

    var body: some View {
        Button(action: {
            multiplayerGameEngine.joinGame()
            showingHostSelection = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Join Game")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("Find and join a nearby game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingHostSelection) {
            HostSelectionSheet(multiplayerGameEngine: multiplayerGameEngine)
        }
    }
}

// MARK: - Host Selection Sheet (Pick-from-list UI)

struct HostSelectionSheet: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wifi.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Find a Game")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select a game to join from the list below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Connection state indicator
                if multiplayerGameEngine.networkManager.connectionState == .connecting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Connecting...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                }
                
                // Discovered hosts list
                if multiplayerGameEngine.discoveredHosts.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Looking for games...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Make sure the host has started their game")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(multiplayerGameEngine.discoveredHosts) { host in
                                DiscoveredHostCard(
                                    host: host,
                                    onSelect: {
                                        multiplayerGameEngine.connectToHost(host)
                                        // Don't dismiss yet - wait for connection
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        multiplayerGameEngine.networkManager.stopNetworking()
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: multiplayerGameEngine.networkManager.connectionState) { oldValue, newValue in
            // Auto-dismiss when connected
            if newValue == .connected {
                dismiss()
            }
        }
    }
}

struct DiscoveredHostCard: View {
    let host: DiscoveredHost
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Host icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "wifi.router.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                
                // Host info
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        // Game code
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.caption2)
                            Text(host.gameId)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        
                        // Player count
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text("\(host.playerCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DebugModeOption: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine

    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Button(action: {
                multiplayerGameEngine.enableDebugMode()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "hammer")
                        .font(.title3)
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Debug Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Test multi-phone features without real devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct MultiplayerActiveView: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: multiplayerGameEngine.isNetworkHost ? "wifi.router.fill" : "wifi")
                    .foregroundColor(multiplayerGameEngine.isNetworkHost ? .green : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(multiplayerGameEngine.isNetworkHost ? "Hosting Game" : "Joined Game")
                        .font(.headline)
                    Text(multiplayerGameEngine.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(multiplayerGameEngine.isDebugMode ? "Exit Debug" : "Leave") {
                    if multiplayerGameEngine.isDebugMode {
                        multiplayerGameEngine.disableDebugMode()
                    } else {
                        multiplayerGameEngine.leaveMultiplayerGame()
                    }
                }
                .font(.caption)
                .foregroundColor(multiplayerGameEngine.isDebugMode ? .orange : .red)
                .buttonStyle(.bordered)
            }

            if !multiplayerGameEngine.connectedDevices.isEmpty || multiplayerGameEngine.isNetworkHost {
                ConnectedDevicesView(multiplayerGameEngine: multiplayerGameEngine)
            }
        }
    }
}

struct ConnectedDevicesView: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Connected Devices")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(multiplayerGameEngine.connectedDevices.count + 1) device\(multiplayerGameEngine.connectedDevices.count == 0 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if multiplayerGameEngine.isNetworkHost {
                DeviceCard(
                    name: UIDevice.current.name + " (Host)",
                    isHost: true,
                    playerCount: multiplayerGameEngine.getPlayersForDevice(multiplayerGameEngine.currentDeviceId).count
                )
            }

            ForEach(multiplayerGameEngine.connectedDevices) { device in
                DeviceCard(
                    name: device.displayName,
                    isHost: false,
                    playerCount: multiplayerGameEngine.getPlayersForDevice(device.id).count
                )
            }
        }
    }
}

// MARK: - Reusing Game Rules Configuration from GameSetupView
// GameRulesSection, QuickRulesSection, and RuleItem are defined in GameSetupView.swift

// MARK: - Full Start Game Section (restored and enhanced from original)

struct FullStartGameSection: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine

    var gameEngine: GameEngine {
        multiplayerGameEngine.gameEngine
    }

    var canStartGame: Bool {
        if !multiplayerGameEngine.canControlGame {
            return false
        } else if gameEngine.players.isEmpty {
            return false
        } else if multiplayerGameEngine.isMultiplayerMode && !multiplayerGameEngine.networkManager.isConnected && !multiplayerGameEngine.isNetworkHost {
            return false
        } else {
            return gameEngine.players.count >= 1
        }
    }

    var startButtonText: String {
        if !multiplayerGameEngine.canControlGame {
            return "Waiting for host..."
        } else if gameEngine.players.isEmpty {
            return "Add players to start"
        } else if multiplayerGameEngine.isMultiplayerMode && !multiplayerGameEngine.networkManager.isConnected && !multiplayerGameEngine.isNetworkHost {
            return "Connecting..."
        } else {
            return "Start Game"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Multiplayer-specific info
            if !canStartGame && multiplayerGameEngine.isMultiplayerMode {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)

                    Text(multiplayerGameEngine.isNetworkHost ?
                         "Make sure all devices are connected before starting" :
                         "Waiting for the host to start the game")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            Button(action: {
                multiplayerGameEngine.startGame()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(startButtonText)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canStartGame)
            .opacity(canStartGame ? 1.0 : 0.6)

            if !canStartGame && !multiplayerGameEngine.isMultiplayerMode {
                Text("Add at least 1 player to start")
                    .farkleCaption()
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Reusing Farkle Rules from GameSetupView
// FarkleRulesView, RulesSection, ScoringRule, and RuleDescription are defined in GameSetupView.swift

// MARK: - Device Cards and Supporting Views

struct DeviceCard: View {
    let name: String
    let isHost: Bool
    let playerCount: Int

    var body: some View {
        HStack {
            Image(systemName: isHost ? "wifi.router.fill" : "iphone")
                .foregroundColor(isHost ? .green : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(playerCount) player\(playerCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isHost {
                Text("HOST")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Network Info View

struct NetworkInfoView: View {
    @ObservedObject var multiplayerGameEngine: MultiplayerGameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection status
                VStack(spacing: 12) {
                    Text("Network Status")
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 12, height: 12)

                        Text(multiplayerGameEngine.connectionStatus)
                            .font(.headline)
                    }
                }

                // Game details
                if !multiplayerGameEngine.gameId.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Game Details")
                            .font(.headline)

                        HStack {
                            Text("Game ID:")
                            Spacer()
                            Text(multiplayerGameEngine.gameId)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Role:")
                            Spacer()
                            Text(multiplayerGameEngine.isNetworkHost ? "Host" : "Client")
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Connected Devices:")
                            Spacer()
                            Text("\(multiplayerGameEngine.connectedDevices.count + 1)")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                }

                // Connected devices list
                if !multiplayerGameEngine.connectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connected Devices")
                            .font(.headline)

                        VStack(spacing: 8) {
                            // Host device
                            if multiplayerGameEngine.isNetworkHost {
                                DeviceInfoRow(
                                    name: UIDevice.current.name,
                                    isHost: true,
                                    playerCount: multiplayerGameEngine.getPlayersForDevice(multiplayerGameEngine.currentDeviceId).count
                                )
                            }

                            // Other devices
                            ForEach(multiplayerGameEngine.connectedDevices) { device in
                                DeviceInfoRow(
                                    name: device.displayName,
                                    isHost: device.isHost,
                                    playerCount: multiplayerGameEngine.getPlayersForDevice(device.id).count
                                )
                            }
                        }
                    }
                }

                Spacer()

                // Disconnect button
                Button("Leave Game") {
                    multiplayerGameEngine.leaveMultiplayerGame()
                    dismiss()
                }
                .foregroundColor(.red)
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Network Info")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }

    private var connectionColor: Color {
        switch multiplayerGameEngine.networkManager.connectionState {
        case .disconnected:
            return .gray
        case .browsing, .connecting:
            return .orange
        case .hosting, .connected:
            return .green
        }
    }
}

struct DeviceInfoRow: View {
    let name: String
    let isHost: Bool
    let playerCount: Int

    var body: some View {
        HStack {
            Image(systemName: isHost ? "wifi.router.fill" : "iphone")
                .foregroundColor(isHost ? .green : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(playerCount) player\(playerCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isHost {
                Text("HOST")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MultiplayerGameSetupView(multiplayerGameEngine: MultiplayerGameEngine())
}
