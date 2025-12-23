//
//  AccessibilityAnnouncer.swift
//  FarkleScorer
//
//  Centralized VoiceOver announcements for key game events.
//

import UIKit

struct AccessibilityAnnouncer {
    /// Announce that a player banked their score
    static func announceBank(playerName: String, pointsBanked: Int, newTotal: Int, nextPlayerName: String?) {
        var message = "\(playerName) banked \(pointsBanked) points. Total score: \(newTotal)."
        if let nextPlayer = nextPlayerName {
            message += " \(nextPlayer)'s turn."
        }
        announce(message)
    }
    
    /// Announce a dice roll
    static func announceRoll(diceCount: Int, values: [Int]) {
        let valuesText = values.map { String($0) }.joined(separator: ", ")
        let message = "Rolled \(diceCount) dice: \(valuesText)"
        announce(message)
    }
    
    /// Announce a farkle (no scoring dice)
    static func announceFarkle(playerName: String, diceValues: [Int], nextPlayerName: String?) {
        var message = "Farkle! \(playerName) rolled no scoring dice and loses all round points."
        if let nextPlayer = nextPlayerName {
            message += " \(nextPlayer)'s turn."
        }
        announce(message)
    }
    
    /// Announce that a player skipped their turn
    static func announceSkip(playerName: String, nextPlayerName: String?) {
        var message = "\(playerName) skipped their turn."
        if let nextPlayer = nextPlayerName {
            message += " \(nextPlayer)'s turn."
        }
        announce(message)
    }
    
    /// Announce the current turn for a new player
    static func announceTurn(playerName: String, totalScore: Int, roundScore: Int) {
        var message = "\(playerName)'s turn. Total score: \(totalScore)."
        if roundScore > 0 {
            message += " Round score: \(roundScore)."
        }
        announce(message)
    }
    
    /// Announce game over
    static func announceGameOver(winnerName: String, winnerScore: Int) {
        let message = "Game over! \(winnerName) wins with \(winnerScore) points!"
        announce(message)
    }
    
    /// Announce final round started
    static func announceFinalRound(triggerPlayerName: String) {
        let message = "Final round! \(triggerPlayerName) reached the winning score. Everyone gets one more turn."
        announce(message)
    }
    
    /// Core announcement method - posts to VoiceOver
    private static func announce(_ message: String) {
        // Only announce if VoiceOver is running
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        // Small delay to let any existing announcements finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

