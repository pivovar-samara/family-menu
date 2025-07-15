//
//  UIComponents.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 28.01.25.
//

import SwiftUI

// MARK: - Reusable UI Components

/// Floating action button component for adding new items
struct FloatingActionButton: View {
    let sfSymbolName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: sfSymbolName)
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color("AccentColor"))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Progress indicator for multi-step forms
struct ProgressIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int
    let steps: [DishFormStep]
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Progress fill
                    Rectangle()
                        .fill(Color("AccentColor"))
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            
            // Step labels
            HStack {
                ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(index < currentStep ? Color("AccentColor") : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(index < currentStep ? .white : .gray)
                            )
                        
                        Text(step.displayName)
                            .font(.caption2)
                            .foregroundColor(index < currentStep ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if index < steps.count - 1 {
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var progress: Double {
        guard totalSteps > 1 else { return 1.0 }
        return Double(currentStep - 1) / Double(totalSteps - 1)
    }
}

/// Navigation controls for multi-step forms
struct NavigationControlsView: View {
    @Binding var currentStep: DishFormStep
    let canProceed: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep != .basicInfo {
                Button("Back".localized()) {
                    withAnimation {
                        currentStep = DishFormStep(rawValue: currentStep.rawValue - 1) ?? .basicInfo
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
            
            // Next/Save button
            if currentStep == .review {
                Button("Save".localized()) {
                    onSave()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed)
            } else {
                Button("Next".localized()) {
                    withAnimation {
                        currentStep = DishFormStep(rawValue: currentStep.rawValue + 1) ?? .review
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed)
            }
        }
        .padding(.horizontal)
    }
}

/// Modern text field with consistent styling
struct ModernTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var onSubmit: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(ModernTextFieldStyle())
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .onSubmit {
                    onSubmit?()
                }
        }
    }
}

/// Modern text field style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("BackgroundColor"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

/// Loading indicator with optional message
struct LoadingView: View {
    let message: String?
    
    init(_ message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundColor"))
    }
}

/// Error view with retry option
struct ErrorView: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again".localized(), action: retryAction)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundColor"))
    }
}

// MARK: - Multi-Step Form Step Enum

enum DishFormStep: Int, CaseIterable, Hashable {
    case basicInfo = 0
    case mealTypes = 1
    case ingredients = 2
    case review = 3
    
    var title: String {
        switch self {
        case .basicInfo: return "Basic Information".localized()
        case .mealTypes: return "Meal Types".localized()
        case .ingredients: return "Ingredients".localized()
        case .review: return "Review".localized()
        }
    }
    
    var icon: String {
        switch self {
        case .basicInfo: return "info.circle"
        case .mealTypes: return "clock"
        case .ingredients: return "basket"
        case .review: return "checkmark.circle"
        }
    }
    
    var displayName: String { title }
} 