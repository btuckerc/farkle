import SwiftUI

struct MultiplayerSetupView: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    @State private var showingGameModeSelection = false
    @State private var showingPlayerAssignment = false
    @State private var selectedPlayerId: String?
    @State private var selectedDeviceId: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                // Connection Status Header
                connectionStatusSection

                // Game Mode Selection
                if !multiplayerEngine.isMultiplayerMode {
                    gameModeSelectionSection
                } else {
                    // Multiplayer Controls
                    multiplayerControlsSection
                }

                // Player Management (only visible when in setup)
                if multiplayerEngine.gameEngine.gameState == .setup {
                    playerManagementSection
                }

                // Device Assignment (only for host)
                if multiplayerEngine.isNetworkHost && multiplayerEngine.isMultiplayerMode {
                    deviceAssignmentSection
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Game Setup")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingGameModeSelection) {
            GameModeSelectionSheet(multiplayerEngine: multiplayerEngine)
        }
        .sheet(isPresented: $showingPlayerAssignment) {
            PlayerAssignmentSheet(
                multiplayerEngine: multiplayerEngine,
                selectedPlayerId: selectedPlayerId
            )
        }
    }

    // MARK: - Connection Status Section

    private var connectionStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 12, height: 12)

                Text(multiplayerEngine.connectionStatus)
                    .font(.headline)
                    .foregroundColor(connectionColor)

                Spacer()

                if multiplayerEngine.isMultiplayerMode {
                    Button("Disconnect") {
                        multiplayerEngine.leaveMultiplayerGame()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            if multiplayerEngine.isMultiplayerMode {
                HStack {
                    Label(multiplayerEngine.isNetworkHost ? "Hosting" : "Joined",
                          systemImage: multiplayerEngine.isNetworkHost ? "wifi.router" : "wifi")

                    Spacer()

                    Text("\(multiplayerEngine.connectedDevices.count + 1) devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !multiplayerEngine.gameId.isEmpty {
                Text("Game ID: \(multiplayerEngine.gameId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var connectionColor: Color {
        switch multiplayerEngine.networkManager.connectionState {
        case .disconnected:
            return .gray
        case .browsing, .connecting:
            return .orange
        case .hosting, .connected:
            return .green
        }
    }

    // MARK: - Game Mode Selection Section

    private var gameModeSelectionSection: some View {
        VStack(spacing: 16) {
            Text("Choose Game Mode")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                Button(action: {
                    // Single device mode - do nothing, already default
                }) {
                    GameModeCard(
                        title: "Single Device",
                        description: "Play with everyone on this device",
                        icon: "iphone",
                        isSelected: true
                    )
                }
                .disabled(true) // Always available but already selected

                Button(action: {
                    showingGameModeSelection = true
                }) {
                    GameModeCard(
                        title: "Multiplayer",
                        description: "Connect multiple devices nearby",
                        icon: "wifi",
                        isSelected: false
                    )
                }
            }
        }
    }

    // MARK: - Multiplayer Controls Section

    private var multiplayerControlsSection: some View {
        VStack(spacing: 16) {
            Text("Connected Devices")
                .font(.title2)
                .fontWeight(.semibold)

            if multiplayerEngine.connectedDevices.isEmpty && !multiplayerEngine.isNetworkHost {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Looking for games...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    // Host device (this device if hosting)
                    if multiplayerEngine.isNetworkHost {
                        DeviceCard(
                            name: UIDevice.current.name + " (Host)",
                            isHost: true,
                            playerCount: multiplayerEngine.getPlayersForDevice(multiplayerEngine.currentDeviceId).count
                        )
                    }

                    // Connected devices
                    ForEach(multiplayerEngine.connectedDevices) { device in
                        DeviceCard(
                            name: device.displayName,
                            isHost: device.isHost,
                            playerCount: multiplayerEngine.getPlayersForDevice(device.id).count
                        )
                    }
                }
            }
        }
    }

    // MARK: - Player Management Section

    private var playerManagementSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Players")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Add Player") {
                    // This would show a sheet to add a player
                    // For now, we'll add a default player
                    let playerNumber = multiplayerEngine.gameEngine.players.count + 1
                    multiplayerEngine.addPlayer(name: "Player \(playerNumber)")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!multiplayerEngine.canControlGame)
            }

            if multiplayerEngine.gameEngine.players.isEmpty {
                Text("No players added yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(multiplayerEngine.gameEngine.players.enumerated()), id: \.element.id) { index, player in
                        MultiplayerPlayerRowCard(
                            player: player,
                            assignedDevice: multiplayerEngine.playerDeviceAssignments[player.id.uuidString],
                            isHost: multiplayerEngine.isNetworkHost,
                            canEdit: multiplayerEngine.canControlGame,
                            onAssignDevice: {
                                selectedPlayerId = player.id.uuidString
                                showingPlayerAssignment = true
                            },
                            onRemove: {
                                multiplayerEngine.removePlayer(at: index)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Device Assignment Section

    private var deviceAssignmentSection: some View {
        VStack(spacing: 16) {
            Text("Device Assignment")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap a player above to assign them to a specific device, or leave unassigned for shared device mode.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Supporting Views

struct GameModeCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// DeviceCard is defined in MultiplayerGameSetupView.swift

struct MultiplayerPlayerRowCard: View {
    let player: Player
    let assignedDevice: String?
    let isHost: Bool
    let canEdit: Bool
    let onAssignDevice: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)

                if assignedDevice != nil {
                    Text("Assigned to device")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Shared device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isHost && canEdit {
                Button("Assign") {
                    onAssignDevice()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            if canEdit {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Sheets

struct GameModeSelectionSheet: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Choose Multiplayer Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)

                VStack(spacing: 16) {
                    Button(action: {
                        multiplayerEngine.startHostingGame()
                        dismiss()
                    }) {
                        MultiplayerModeCard(
                            title: "Host Game",
                            description: "Start a new game that others can join",
                            icon: "wifi.router.fill",
                            color: .green
                        )
                    }

                    Button(action: {
                        multiplayerEngine.joinGame()
                        dismiss()
                    }) {
                        MultiplayerModeCard(
                            title: "Join Game",
                            description: "Find and join a nearby game",
                            icon: "wifi",
                            color: .blue
                        )
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Multiplayer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
    }
}

struct MultiplayerModeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PlayerAssignmentSheet: View {
    @ObservedObject var multiplayerEngine: MultiplayerGameEngine
    let selectedPlayerId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let playerId = selectedPlayerId,
                   let player = multiplayerEngine.gameEngine.players.first(where: { $0.id.uuidString == playerId }) {

                    Text("Assign \(player.name) to Device")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)

                    VStack(spacing: 12) {
                        // Host device
                        Button(action: {
                            multiplayerEngine.assignPlayerToDevice(playerId, deviceId: multiplayerEngine.currentDeviceId)
                            dismiss()
                        }) {
                            DeviceAssignmentCard(
                                name: UIDevice.current.name + " (Host)",
                                isSelected: multiplayerEngine.playerDeviceAssignments[playerId] == multiplayerEngine.currentDeviceId
                            )
                        }

                        // Connected devices
                        ForEach(multiplayerEngine.connectedDevices) { device in
                            Button(action: {
                                multiplayerEngine.assignPlayerToDevice(playerId, deviceId: device.id)
                                dismiss()
                            }) {
                                DeviceAssignmentCard(
                                    name: device.displayName,
                                    isSelected: multiplayerEngine.playerDeviceAssignments[playerId] == device.id
                                )
                            }
                        }

                        // Unassigned option
                        Button(action: {
                            multiplayerEngine.assignPlayerToDevice(playerId, deviceId: "")
                            dismiss()
                        }) {
                            DeviceAssignmentCard(
                                name: "Shared (any device)",
                                isSelected: multiplayerEngine.playerDeviceAssignments[playerId] == nil
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Assign Player")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
    }
}

struct DeviceAssignmentCard: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(name)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
