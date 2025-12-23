//
//  ConfirmationOverlay.swift
//  FarkleScorer
//
//  Flip7-style material confirmation overlay for in-app confirmations.
//  More elegant and less disruptive than system alerts.
//

import SwiftUI

struct ConfirmationOverlay: View {
    let title: String
    let message: String
    let primaryActionTitle: String
    let primaryActionRole: ButtonRole?
    let secondaryActionTitle: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onDismiss: () -> Void
    
    @State private var isPresented = false
    
    init(
        title: String,
        message: String,
        primaryActionTitle: String,
        primaryActionRole: ButtonRole? = nil,
        secondaryActionTitle: String = "Cancel",
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionRole = primaryActionRole
        self.secondaryActionTitle = secondaryActionTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }
            
            // Centered card
            VStack(spacing: 0) {
                // Title
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                // Message
                Text(message)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                
                Divider()
                
                // Buttons
                HStack(spacing: 0) {
                    // Secondary button (Cancel)
                    Button(action: {
                        HapticFeedback.light()
                        onSecondary()
                        dismissWithAnimation()
                    }) {
                        Text(secondaryActionTitle)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    
                    Divider()
                        .frame(height: 56)
                    
                    // Primary button
                    Button(action: {
                        if primaryActionRole == .destructive {
                            HapticFeedback.warning()
                        } else {
                            HapticFeedback.success()
                        }
                        onPrimary()
                        dismissWithAnimation()
                    }) {
                        Text(primaryActionTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryActionRole == .destructive ? .red : .blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
                    )
            )
            .frame(maxWidth: 320)
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1.0 : 0.9)
            .opacity(isPresented ? 1.0 : 0.0)
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPresented = true
            }
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Action Classification

/// Defines the type of action for gating purposes
enum GameActionType {
    /// Actions that can be undone (dice selection, manual score edits)
    case reversible
    /// Actions that require intentional gesture (hold) or confirmation - cannot be undone
    case commitIrreversible
}

/// Centralized action policy - determines how each action should be gated
enum GameAction {
    // Reversible actions (can be undone)
    case selectDice
    case deselectDice
    case addManualScore
    case removeManualScore
    case clearManualScores
    case continueRolling
    
    // Commit/irreversible actions (require hold or confirmation)
    case bankScore
    case skipTurn
    case farkleManual
    case previousPlayer
    case jumpToPlayer
    case endGame
    case newGame
    case playAgain
    
    var actionType: GameActionType {
        switch self {
        case .selectDice, .deselectDice, .addManualScore, .removeManualScore, 
             .clearManualScores, .continueRolling:
            return .reversible
        case .bankScore, .skipTurn, .farkleManual, .previousPlayer, 
             .jumpToPlayer, .endGame, .newGame, .playAgain:
            return .commitIrreversible
        }
    }
    
    /// Whether this action should use hold-to-confirm (vs overlay confirmation)
    var usesHoldToConfirm: Bool {
        switch self {
        case .bankScore, .skipTurn, .farkleManual:
            return true
        default:
            return false
        }
    }
    
    /// Whether this action should use overlay confirmation
    var usesOverlayConfirmation: Bool {
        switch self {
        case .previousPlayer, .jumpToPlayer, .endGame, .newGame, .playAgain:
            return true
        default:
            return false
        }
    }
}

// MARK: - Confirmation State Enum

enum ActiveConfirmation: Identifiable {
    case skipTurn
    case bankScore
    case endGame
    case newGame
    case playAgain
    case previousPlayer
    case jumpToPlayer(playerName: String, playerIndex: Int)
    case farkleManual
    case switchMode(toManual: Bool)
    
    var id: String {
        switch self {
        case .skipTurn: return "skipTurn"
        case .bankScore: return "bankScore"
        case .endGame: return "endGame"
        case .newGame: return "newGame"
        case .playAgain: return "playAgain"
        case .previousPlayer: return "previousPlayer"
        case .jumpToPlayer(let name, _): return "jumpToPlayer-\(name)"
        case .farkleManual: return "farkleManual"
        case .switchMode(let toManual): return "switchMode-\(toManual)"
        }
    }
    
    var title: String {
        switch self {
        case .skipTurn: return "Skip Turn?"
        case .bankScore: return "Bank Score?"
        case .endGame: return "End Game?"
        case .newGame: return "New Game?"
        case .playAgain: return "Play Again?"
        case .previousPlayer: return "Previous Player?"
        case .jumpToPlayer(let name, _): return "Jump to \(name)?"
        case .farkleManual: return "Farkle?"
        case .switchMode(let toManual):
            return toManual ? "Switch to Calculator?" : "Switch to Digital?"
        }
    }
    
    var message: String {
        switch self {
        case .skipTurn:
            return "This will end your turn without banking any points."
        case .bankScore:
            return "Bank your current points and end your turn."
        case .endGame:
            return "This will end the current game. All progress will be lost."
        case .newGame:
            return "Start a new game with the current players?"
        case .playAgain:
            return "Start a new game with the same players and rules? All scores will be reset."
        case .previousPlayer:
            return "Go back to the previous player's turn? This is a referee action."
        case .jumpToPlayer(let name, _):
            return "Jump to \(name)'s turn? This is a referee action."
        case .farkleManual:
            return "Mark this turn as a Farkle? All accumulated points this round will be lost."
        case .switchMode(let toManual):
            if toManual {
                return "You have an in-progress digital roll. Switching will keep your progress, but you'll be entering points in Calculator mode."
            } else {
                return "You have points entered in Calculator. Switching will keep your progress, but you'll be using Digital dice."
            }
        }
    }
    
    var primaryActionTitle: String {
        switch self {
        case .skipTurn: return "Skip Turn"
        case .bankScore: return "Bank Score"
        case .endGame: return "End Game"
        case .newGame: return "New Game"
        case .playAgain: return "Play Again"
        case .previousPlayer: return "Go Back"
        case .jumpToPlayer: return "Jump"
        case .farkleManual: return "Farkle"
        case .switchMode(let toManual):
            return toManual ? "Switch to Calculator" : "Switch to Digital"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .skipTurn, .endGame, .farkleManual: return true
        case .bankScore, .newGame, .playAgain, .previousPlayer, .jumpToPlayer, .switchMode: return false
        }
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()
        
        ConfirmationOverlay(
            title: "Skip Turn?",
            message: "This will end your turn without banking any points.",
            primaryActionTitle: "Skip Turn",
            primaryActionRole: .destructive,
            onPrimary: { print("Skipped") },
            onDismiss: { print("Dismissed") }
        )
    }
}

