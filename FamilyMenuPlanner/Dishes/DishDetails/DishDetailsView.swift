//
//  DishDetailsView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

// MARK: - Main Multi-Step Dish Details View
struct DishDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DishDetailsViewModel
    @State private var currentStep: DishFormStep = .basicInfo
    
    enum DishFormStep: Int, CaseIterable {
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
    }
    
    init(viewModel: DishDetailsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            ProgressIndicatorView(
                currentStep: currentStep.rawValue,
                totalSteps: DishFormStep.allCases.count,
                steps: DishFormStep.allCases
            )
            .padding(.top, 8)
            .padding(.horizontal)
            
            // Step Content
            TabView(selection: $currentStep) {
                BasicInfoStepView(viewModel: viewModel)
                    .tag(DishFormStep.basicInfo)
                
                MealTypesStepView(viewModel: viewModel)
                    .tag(DishFormStep.mealTypes)
                
                IngredientsStepView(viewModel: viewModel)
                    .tag(DishFormStep.ingredients)
                
                ReviewStepView(viewModel: viewModel)
                    .tag(DishFormStep.review)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            .onChange(of: currentStep) { _ in
                // Resign focus when step changes via swipe gesture
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .clipped(antialiased: false)
            
            // Navigation Controls
            NavigationControlsView(
                currentStep: $currentStep,
                canProceed: canProceedToNextStep(),
                onSave: { saveAndDismiss() },
                onCancel: { cancelAndDismiss() }
            )
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color("BackgroundColor"))
        .onAppear {
            viewModel.loadDish()
            viewModel.loadIngredients()
            viewModel.loadSelectedMealTypes()
            viewModel.loadSelectedCategory()
        }
        .sheet(isPresented: $viewModel.showProductSelection) {
            NavigationStack {
                ProductSelectionCoordinator().createProductSelectionView(
                    currentProduct: viewModel.selectedIngredient?.product
                ) { selectedProduct in
                    if viewModel.isAddingIngredient {
                        viewModel.addIngredient(product: selectedProduct, quantity: 1.0)
                    } else {
                        viewModel.selectedIngredient?.product = selectedProduct
                        // Refresh ingredients list
                        viewModel.loadIngredients()
                    }
                }
            }
        }
        .alert(item: Binding(
            get: { viewModel.currentAlert },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK".localized())) {
                    alert.action?()
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func canProceedToNextStep() -> Bool {
        switch currentStep {
        case .basicInfo:
            return !(viewModel.dish?.name?.isEmpty ?? true)
        case .mealTypes:
            return !viewModel.selectedMealTypes.isEmpty
        case .ingredients:
            return !viewModel.selectedIngredients.isEmpty
        case .review:
            return true
        }
    }
    
    private func saveAndDismiss() {
        viewModel.saveChanges {
            dismiss()
        }
    }
    
    private func cancelAndDismiss() {
        viewModel.rollback()
        dismiss()
    }
}

// MARK: - Progress Indicator Component
struct ProgressIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int
    let steps: [DishDetailsView.DishFormStep]
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Bar
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index <= currentStep ? Color("AccentColor") : Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            
            // Step Info
            HStack {
                Image(systemName: steps[currentStep].icon)
                    .foregroundColor(Color("AccentColor"))
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String.localizedStringWithFormat("Step %d of %d".localized(), currentStep + 1, totalSteps))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(steps[currentStep].title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
}

// MARK: - Navigation Controls Component
struct NavigationControlsView: View {
    @Binding var currentStep: DishDetailsView.DishFormStep
    let canProceed: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    private func resignFocusAndNavigate(to newStep: DishDetailsView.DishFormStep) {
        // Resign any active text field focus to commit pending changes
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Small delay to ensure the text field onChange is processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut) {
                currentStep = newStep
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            if currentStep.rawValue > 0 {
                Button(action: { 
                    let previousStep = DishDetailsView.DishFormStep(rawValue: currentStep.rawValue - 1) ?? .basicInfo
                    resignFocusAndNavigate(to: previousStep)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back".localized())
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(Color("AccentColor"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color("SecondaryBackgroundColor"))
                    .cornerRadius(12)
                }
            } else {
                // Cancel Button
                Button(action: onCancel) {
                    Text("Cancel".localized())
                        .font(.body.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color("SecondaryBackgroundColor"))
                        .cornerRadius(12)
                }
            }
            
            Spacer()
            
            // Next/Save Button
            Button(action: {
                if currentStep == .review {
                    // For save, resign focus but don't navigate
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onSave()
                    }
                } else if canProceed {
                    let nextStep = DishDetailsView.DishFormStep(rawValue: currentStep.rawValue + 1) ?? .review
                    resignFocusAndNavigate(to: nextStep)
                }
            }) {
                HStack(spacing: 8) {
                    Text(currentStep == .review ? "Save".localized() : "Next".localized())
                    if currentStep != .review {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(canProceed ? Color("AccentColor") : Color.gray)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4)
            }
            .disabled(!canProceed)
        }
        .padding(.top, 16)
    }
}
