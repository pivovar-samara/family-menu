//
//  DishDetailsView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct DishDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isTextEditorFocused: Bool
    
    @StateObject private var viewModel: DishDetailsViewModel
    
    init(viewModel: DishDetailsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    /// Comprehensive keyboard dismissal to prevent constraint conflicts
    private func dismissKeyboard() {
        // SwiftUI focus management
        isTextFieldFocused = false
        isTextEditorFocused = false
        
        // UIKit fallback for complex scenarios
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        Form {
            // Dish details
            Section(header: Text("Dish Details")) {
                TextField("Dish Name", text: Binding(
                    get: { viewModel.dish?.name ?? "" },
                    set: { viewModel.dish?.name = $0 }
                ))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .focused($isTextFieldFocused)

                TextEditor(text: $viewModel.descriptionText)
                    .safeFrame(height: 100)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.sentences)
                    .focused($isTextEditorFocused)
                    .onAppear {
                        viewModel.descriptionText = viewModel.dish?.details ?? ""
                    }
                    .onChange(of: viewModel.descriptionText) { newValue in
                        viewModel.dish?.details = newValue
                    }
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))
            
            // Dish Category Section
            Section(header: Text("Dish Category")) {
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("No Category").tag(nil as DishCategory?)
                    ForEach(viewModel.allDishCategories, id: \.self) { category in
                        Text((category.name ?? "").localized())
                            .tag(category as DishCategory?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: viewModel.selectedCategory) { newCategory in
                    viewModel.setDishCategory(newCategory)
                }
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))
            
            // Meal type
            Section(header: Text("Meal Types")) {
                ForEach(viewModel.allMealTypes, id: \.self) { mealType in
                    HStack {
                        Text((mealType.name ?? "").localized())
                        Spacer()
                        if viewModel.selectedMealTypes.contains(mealType) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleMealTypeSelection(mealType)
                    }
                }
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))

            Section(header: Text("Ingredients")) {
                ForEach(viewModel.selectedIngredients, id: \.self) { detail in
                    HStack {
                        Button(action: {
                            // Dismiss keyboard to prevent constraint conflicts
                            dismissKeyboard()
                            
                            // Add small delay to ensure keyboard is fully dismissed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                viewModel.selectedIngredient = detail
                                viewModel.isAddingIngredient = false
                                viewModel.showProductSelection = true
                            }
                        }) {
                            HStack {
                                Text(detail.product?.name ?? "Select a product")
                                    .foregroundColor(detail.product == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("Quantity", value: Binding(
                            get: { detail.quantity },
                            set: { viewModel.updateIngredientQuantity(detail, quantity: $0) }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .safeFrame(width: 60)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled(true)
                        
                        Text((detail.product?.unit?.name ?? "").localized())
                            .foregroundColor(.secondary)
                            .safeFrame(width: 30, alignment: .leading)
                    }
                }
                .onMove(perform: viewModel.moveIngredient)
                .onDelete(perform: viewModel.deleteIngredient)

                Button("Add Ingredient") {
                    // Dismiss keyboard to prevent constraint conflicts
                    dismissKeyboard()
                    
                    // Add small delay to ensure keyboard is fully dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.selectedIngredient = nil
                        viewModel.isAddingIngredient = true
                        viewModel.showProductSelection = true
                    }
                }
                .foregroundColor(Color("AccentColor"))
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))

            // Validation error
            if let error = viewModel.validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .listRowBackground(Color("SecondaryBackgroundColor"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .sheet(isPresented: $viewModel.showProductSelection) {
            NavigationStack {
                ProductSelectionCoordinator().createProductSelectionView(currentProduct: viewModel.selectedIngredient?.product) { selectedProduct in
                    if viewModel.isAddingIngredient {
                        viewModel.addIngredient(product: selectedProduct, quantity: 1.0)
                    } else {
                        viewModel.selectedIngredient?.product = selectedProduct
                        
                        // WA to update UI
                        if let lastElement = viewModel.selectedIngredients.popLast(){
                            viewModel.selectedIngredients.append(lastElement)
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Dish")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.saveChanges {
                        dismiss()
                    }
                }
                .foregroundColor(Color("AccentColor"))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.rollback()
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .onAppear {
            viewModel.loadDish()
            viewModel.loadIngredients()
            viewModel.loadSelectedMealTypes()
            viewModel.loadSelectedCategory()
        }
        .alert(item: Binding(
            get: { viewModel.currentAlert },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    alert.action?()
                }
            )
        }
    }
}
