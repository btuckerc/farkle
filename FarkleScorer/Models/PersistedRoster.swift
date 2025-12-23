//
//  PersistedRoster.swift
//  FarkleScorer
//
//  Persists a single ordered player roster across app launches.
//

import Foundation

/// Represents a persisted player roster that can be saved and loaded
struct PersistedRoster: Codable, Equatable {
    var names: [String]
    
    init(names: [String] = []) {
        self.names = names
    }
    
    // MARK: - Keys
    
    private static let rosterKey = "farkleLastPlayerRoster"
    private static let legacyKey = "savedPlayerNames" // Old key used in MultiplayerGameSetupView
    
    // MARK: - Load
    
    /// Loads the persisted roster from UserDefaults, migrating from legacy key if needed
    static func load() -> PersistedRoster? {
        // First, check for the new key
        if let data = UserDefaults.standard.data(forKey: rosterKey),
           let roster = try? JSONDecoder().decode(PersistedRoster.self, from: data) {
            return roster
        }
        
        // Fall back to migrating from legacy key
        if let legacyNames = UserDefaults.standard.array(forKey: legacyKey) as? [String],
           !legacyNames.isEmpty {
            let roster = PersistedRoster(names: legacyNames)
            // Migrate: save to new key and remove old key
            roster.save()
            UserDefaults.standard.removeObject(forKey: legacyKey)
            return roster
        }
        
        return nil
    }
    
    /// Loads the roster or returns a default roster with 2 empty player slots
    static func loadOrDefault() -> PersistedRoster {
        return load() ?? PersistedRoster(names: ["", ""])
    }
    
    // MARK: - Save
    
    /// Saves the roster to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.rosterKey)
        }
    }
    
    // MARK: - Clear
    
    /// Clears the persisted roster from UserDefaults
    static func clear() {
        UserDefaults.standard.removeObject(forKey: rosterKey)
        // Also clean up legacy key if it still exists
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }
    
    // MARK: - Helpers
    
    /// Returns true if the roster has at least one non-empty name
    var hasValidPlayers: Bool {
        names.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    /// Returns the count of non-empty player names
    var validPlayerCount: Int {
        names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
}

