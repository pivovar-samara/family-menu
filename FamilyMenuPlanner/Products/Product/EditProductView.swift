//
//  EditProductView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct EditProductView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: EditProductViewModel

    init(viewModel: EditProductViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Product Details Card
                ProductDetailsCard(viewModel: viewModel)
                
                // Unit Selection Card
                UnitSelectionCard(viewModel: viewModel)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color.appBackground)
        .navigationTitle(viewModel.isCreatingNewProduct ? "Add Product".localized() : "Edit Product".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save".localized()) {
                    viewModel.saveChanges {
                        dismiss()
                    }
                }
                .foregroundColor(Color.accent)
                .font(.body.weight(.semibold))
                .accessibilityIdentifier("Save")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized()) {
                    viewModel.rollback()
                    dismiss()
                }
                .foregroundColor(Color.accent)
            }
        }
        .onAppear {
            viewModel.loadProduct()
            viewModel.setupSelectedUnit()
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
}


// MARK: - Product Details Card
struct ProductDetailsCard: View {
    @ObservedObject var viewModel: EditProductViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Product Information".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Product Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Product Name".localized())
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                TextField("Enter product name".localized(), text: Binding(
                    get: { viewModel.product?.name ?? "" },
                    set: { newValue in
                        viewModel.product?.name = newValue
                    }
                ), onEditingChanged: { isEditing in
                    // Prevent auto-dismiss during text editing
                    viewModel.setAutoDismissPreventionState(isEditing)
                })
                .textFieldStyle(ModernTextFieldStyle())
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("product_name_field")
            }
        }
        .padding(20)
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Unit Selection Card
struct UnitSelectionCard: View {
    @ObservedObject var viewModel: EditProductViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Unit of Measurement".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Unit Picker
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.units, id: \.self) { unit in
                        ChipView(
                            text: (unit.name ?? "").localized(),
                            style: viewModel.selectedUnit == unit ? .filled : .outline,
                            tint: Color.accent,
                            font: .caption,
                            onTap: {
                                viewModel.selectedUnit = unit
                                viewModel.updateProductUnit(unit)
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("unit_chip_\(unit.name ?? "")")
                    }
                }
            }
        }
        .cardStyle(
            cornerRadius: 16,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.06),
            shadowRadius: 8,
            borderColor: Color.clear,
            borderWidth: 0,
            padding: 20
        )
    }
}

// Legacy UnitChip removed in favor of ChipView with ChipStyle
