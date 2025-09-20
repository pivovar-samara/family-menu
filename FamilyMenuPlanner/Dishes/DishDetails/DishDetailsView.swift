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
    
    init(viewModel: DishDetailsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            ProgressIndicatorView(
                currentStep: currentStep.rawValue + 1,
                totalSteps: DishFormStep.allCases.count,
                steps: DishFormStep.allCases
            )
            .padding(.top, 24)
            .padding(.horizontal)
            .padding(.bottom, 16)
            
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
            .padding(.top, 12)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color.appBackground)
        .onAppear {
            viewModel.loadDish()
            viewModel.loadIngredients()
            viewModel.loadSelectedMealTypes()
            viewModel.loadSelectedCategory()
        }
        .sheet(isPresented: $viewModel.showProductSelection) {
            NavigationStack {
                if viewModel.isAddingIngredient {
                    ProductSelectionCoordinator().createProductSelectionView(
                        currentProduct: nil,
                        selectionMode: .multiple,
                        preselectedProducts: [],
                        onProductSelected: { _ in },
                        onProductsSelected: { selectedProducts in
                            viewModel.addIngredients(products: selectedProducts, defaultQuantity: 1.0)
                        }
                    )
                    .navigationTitle("Select Products".localized())
                } else {
                    ProductSelectionCoordinator().createProductSelectionView(
                        currentProduct: viewModel.selectedIngredient?.product,
                        selectionMode: .single,
                        preselectedProducts: [],
                        onProductSelected: { selectedProduct in
                            viewModel.selectedIngredient?.product = selectedProduct
                            viewModel.loadIngredients()
                        },
                        onProductsSelected: nil
                    )
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
