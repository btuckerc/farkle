//
//  FocusableTextField.swift
//  FarkleScorer
//
//  UIKit-backed text field that maintains keyboard focus when moving between fields.
//  Ported from Flip7 calculator for smoother player name entry.
//

import SwiftUI
import UIKit

// MARK: - Focus Coordinator

/// Manages focus across multiple FocusableTextFields without dismissing the keyboard
class FocusCoordinator: ObservableObject {
    private var textFields: [UUID: UITextField] = [:]
    private var order: [UUID] = []
    @Published var focusedId: UUID?
    
    func register(id: UUID, textField: UITextField) {
        textFields[id] = textField
        if !order.contains(id) {
            order.append(id)
        }
    }
    
    func setOrder(_ ids: [UUID]) {
        order = ids
    }
    
    func focus(_ id: UUID?) {
        // Resign current first responder if different
        if let currentId = focusedId, currentId != id, let currentField = textFields[currentId] {
            currentField.resignFirstResponder()
        }
        
        focusedId = id
        
        if let id = id, let textField = textFields[id] {
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }
    }
    
    func focusNext(after id: UUID) {
        guard let currentIndex = order.firstIndex(of: id) else {
            focus(nil)
            return
        }
        
        if currentIndex < order.count - 1 {
            let nextId = order[currentIndex + 1]
            if let nextField = textFields[nextId] {
                // Directly transfer focus without dismissing keyboard
                nextField.becomeFirstResponder()
                focusedId = nextId
            }
        } else {
            // Last field - dismiss keyboard
            if let currentField = textFields[id] {
                currentField.resignFirstResponder()
            }
            focusedId = nil
        }
    }
    
    func clearFocus() {
        if let currentId = focusedId, let currentField = textFields[currentId] {
            currentField.resignFirstResponder()
        }
        focusedId = nil
    }
    
    func unregister(id: UUID) {
        textFields.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }
}

// MARK: - Focusable Text Field Representable

struct FocusableTextFieldRepresentable: UIViewRepresentable {
    let id: UUID
    let placeholder: String
    @Binding var text: String
    let isLast: Bool
    @ObservedObject var coordinator: FocusCoordinator
    var onDelete: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = UIFont.rounded(ofSize: 17, weight: .regular)
        textField.delegate = context.coordinator
        textField.returnKeyType = isLast ? .done : .next
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .no
        textField.borderStyle = .none
        // Allow text field to shrink and not push container width
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        // Register with coordinator
        coordinator.register(id: id, textField: textField)
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.returnKeyType = isLast ? .done : .next
        uiView.placeholder = placeholder
        
        // Update registration in case view was recycled
        coordinator.register(id: id, textField: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(id: id, text: $text, focusCoordinator: coordinator, onDelete: onDelete)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let id: UUID
        @Binding var text: String
        let focusCoordinator: FocusCoordinator
        let onDelete: (() -> Void)?
        
        static let maxNameLength = 20
        
        init(id: UUID, text: Binding<String>, focusCoordinator: FocusCoordinator, onDelete: (() -> Void)?) {
            self.id = id
            _text = text
            self.focusCoordinator = focusCoordinator
            self.onDelete = onDelete
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            var newText = textField.text ?? ""
            // Enforce character limit
            if newText.count > Self.maxNameLength {
                newText = String(newText.prefix(Self.maxNameLength))
                textField.text = newText
            }
            text = newText
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            focusCoordinator.focusedId = id
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            focusCoordinator.focusNext(after: id)
            return false
        }
    }
}

// MARK: - UIFont Extension

extension UIFont {
    /// Creates a rounded system font
    static func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return systemFont
    }
}

// MARK: - Player Name Row Identifiable

/// A row in the player name list with a unique ID
struct PlayerNameRow: Identifiable, Equatable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
}

