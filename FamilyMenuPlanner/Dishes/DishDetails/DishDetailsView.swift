//
//  DishDetailsView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct DishDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: DishDetailsViewModel
    
    init(viewModel: DishDetailsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Form {
            // Dish details
            Section(header: Text("Dish Details")) {
                TextField("Dish Name", text: Binding(
                    get: { viewModel.dish?.name ?? "" },
                    set: { viewModel.dish?.name = $0 }
                ))

                TextEditor(text: $viewModel.descriptionText)
                    .frame(height: 100)
                    .onAppear {
                        viewModel.descriptionText = viewModel.dish?.details ?? ""
                    }
                    .onChange(of: viewModel.descriptionText) { newValue in
                        viewModel.dish?.details = newValue
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
                            viewModel.selectedIngredient = detail
                            viewModel.isAddingIngredient = false
                            viewModel.showProductSelection = true
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
                            set: { detail.quantity = $0 }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        
                        Text((detail.product?.unit?.name ?? "").localized())
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }
                }
                .onMove(perform: viewModel.moveIngredient)
                .onDelete(perform: viewModel.deleteIngredient)

                Button("Add Ingredient") {
                    viewModel.selectedIngredient = nil
                    viewModel.isAddingIngredient = true
                    viewModel.showProductSelection = true
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
                        viewModel.addIngredient(for: selectedProduct)
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
