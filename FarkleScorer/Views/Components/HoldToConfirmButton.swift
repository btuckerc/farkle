//
//  HoldToConfirmButton.swift
//  FarkleScorer
//
//  A button that requires a press-and-hold gesture to confirm commit actions.
//  Provides smooth visual feedback via a progress fill and haptics.
//  Accessibility: Respects Reduce Motion, limits haptics, and provides VoiceOver support.
//

import SwiftUI
import UIKit

struct HoldToConfirmButton<Label: View>: View {
    let action: () -> Void
    let holdDuration: TimeInterval
    let backgroundColor: Color
    let progressColor: Color
    let isEnabled: Bool
    let accessibilityLabel: String
    @ViewBuilder let label: () -> Label
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHolding = false
    @State private var holdProgress: CGFloat = 0
    @State private var completionTimer: Timer?
    @State private var didComplete = false
    
    init(
        holdDuration: TimeInterval = 0.6,
        backgroundColor: Color,
        progressColor: Color = .white.opacity(0.5),
        isEnabled: Bool = true,
        accessibilityLabel: String = "Confirm action",
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.holdDuration = holdDuration
        self.backgroundColor = backgroundColor
        self.progressColor = progressColor
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.label = label
    }
    
    var body: some View {
        label()
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    // Base background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isEnabled ? backgroundColor : backgroundColor.opacity(0.4))
                    
                    // Progress overlay (fills from left to right) - single smooth animation
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * holdProgress)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Smooth scale animation
            .scaleEffect(reduceMotion ? 1.0 : (isHolding ? 0.97 : 1.0))
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHolding)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isHolding, !didComplete else { return }
                        startHolding()
                    }
                    .onEnded { _ in
                        cancelHolding()
                    }
            )
            .allowsHitTesting(isEnabled)
            // Accessibility support
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isEnabled ? "Press and hold to confirm" : "Button disabled")
            .accessibilityValue(isHolding ? "Holding" : "")
            .accessibilityAddTraits(.isButton)
            // VoiceOver double-tap activates immediately (accessibility escape hatch)
            .accessibilityAction {
                if isEnabled {
                    HapticFeedback.success()
                    action()
                }
            }
    }
    
    private func startHolding() {
        isHolding = true
        didComplete = false
        
        // Start haptic
        HapticFeedback.light()
        
        // Animate progress smoothly from 0 to 1 over holdDuration using SwiftUI animation
        if reduceMotion {
            holdProgress = 1.0
        } else {
            withAnimation(.linear(duration: holdDuration)) {
                holdProgress = 1.0
            }
        }
        
        // Schedule completion check - if still holding when timer fires, complete the action
        completionTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
            if isHolding && !didComplete {
                completeAction()
            }
        }
    }
    
    private func cancelHolding() {
        completionTimer?.invalidate()
        completionTimer = nil
        
        if !didComplete {
            // Smoothly animate back to 0
            if reduceMotion {
                isHolding = false
                holdProgress = 0
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isHolding = false
                    holdProgress = 0
                }
            }
        }
    }
    
    private func completeAction() {
        didComplete = true
        HapticFeedback.success()
        
        // Ensure progress shows full
        if reduceMotion {
            holdProgress = 1.0
        } else {
            withAnimation(.easeOut(duration: 0.1)) {
                holdProgress = 1.0
            }
        }
        
        // Brief delay then execute action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            action()
            
            // Reset state after action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if reduceMotion {
                    isHolding = false
                    holdProgress = 0
                    didComplete = false
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isHolding = false
                        holdProgress = 0
                        didComplete = false
                    }
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension HoldToConfirmButton where Label == HoldButtonLabel {
    /// Convenience initializer for common button styles
    init(
        title: String,
        icon: String? = nil,
        holdDuration: TimeInterval = 0.6,
        backgroundColor: Color,
        progressColor: Color = .white.opacity(0.5),
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            holdDuration: holdDuration,
            backgroundColor: backgroundColor,
            progressColor: progressColor,
            isEnabled: isEnabled,
            accessibilityLabel: title,
            action: action
        ) {
            HoldButtonLabel(title: title, icon: icon, isEnabled: isEnabled)
        }
    }
}

struct HoldButtonLabel: View {
    let title: String
    let icon: String?
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                
                Text("Hold to confirm")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.7)
            }
        }
    }
}

// MARK: - Compact Hold Button (for inline use)

struct CompactHoldButton: View {
    let title: String
    let icon: String?
    let holdDuration: TimeInterval
    let backgroundColor: Color
    let isEnabled: Bool
    let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isHolding = false
    @State private var holdProgress: CGFloat = 0
    @State private var completionTimer: Timer?
    @State private var didComplete = false
    
    init(
        title: String,
        icon: String? = nil,
        holdDuration: TimeInterval = 0.5,
        backgroundColor: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.holdDuration = holdDuration
        self.backgroundColor = backgroundColor
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? backgroundColor : backgroundColor.opacity(0.4))
                
                // Progress overlay - single smooth animation
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.4))
                        .frame(width: geometry.size.width * holdProgress)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect(reduceMotion ? 1.0 : (isHolding ? 0.96 : 1.0))
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHolding)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isHolding, !didComplete else { return }
                    startHolding()
                }
                .onEnded { _ in
                    cancelHolding()
                }
        )
        .allowsHitTesting(isEnabled)
        // Accessibility support
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? "Press and hold to confirm" : "Button disabled")
        .accessibilityValue(isHolding ? "Holding" : "")
        .accessibilityAddTraits(.isButton)
        // VoiceOver double-tap activates immediately
        .accessibilityAction {
            if isEnabled {
                HapticFeedback.success()
                action()
            }
        }
    }
    
    private func startHolding() {
        isHolding = true
        didComplete = false
        
        // Start haptic
        HapticFeedback.light()
        
        // Animate progress smoothly from 0 to 1 over holdDuration
        if reduceMotion {
            holdProgress = 1.0
        } else {
            withAnimation(.linear(duration: holdDuration)) {
                holdProgress = 1.0
            }
        }
        
        // Schedule completion check
        completionTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
            if isHolding && !didComplete {
                completeAction()
            }
        }
    }
    
    private func cancelHolding() {
        completionTimer?.invalidate()
        completionTimer = nil
        
        if !didComplete {
            if reduceMotion {
                isHolding = false
                holdProgress = 0
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isHolding = false
                    holdProgress = 0
                }
            }
        }
    }
    
    private func completeAction() {
        didComplete = true
        HapticFeedback.success()
        
        if reduceMotion {
            holdProgress = 1.0
        } else {
            withAnimation(.easeOut(duration: 0.1)) {
                holdProgress = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if reduceMotion {
                    isHolding = false
                    holdProgress = 0
                    didComplete = false
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isHolding = false
                        holdProgress = 0
                        didComplete = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HoldToConfirmButton(
            title: "Bank Score",
            icon: "checkmark.circle.fill",
            backgroundColor: .green,
            action: { print("Banked!") }
        )
        .padding(.horizontal, 40)
        
        HoldToConfirmButton(
            title: "Skip Turn",
            icon: "forward.fill",
            backgroundColor: .red,
            action: { print("Skipped!") }
        )
        .padding(.horizontal, 40)
        
        HoldToConfirmButton(
            title: "Farkle",
            icon: "xmark.circle.fill",
            backgroundColor: .orange,
            isEnabled: false,
            action: { print("Farkled!") }
        )
        .padding(.horizontal, 40)
        
        HStack(spacing: 12) {
            CompactHoldButton(
                title: "Skip",
                icon: "forward.fill",
                backgroundColor: .gray,
                action: { print("Skipped!") }
            )
            
            CompactHoldButton(
                title: "Farkle",
                icon: "xmark.circle.fill",
                backgroundColor: .red,
                action: { print("Farkled!") }
            )
        }
        .padding(.horizontal, 40)
    }
    .padding()
}

