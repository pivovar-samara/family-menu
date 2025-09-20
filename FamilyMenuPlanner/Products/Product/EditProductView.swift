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
                            isSelected: viewModel.selectedUnit == unit,
                            background: viewModel.selectedUnit == unit ? Color.accent : Color.appChipBackground,
                            foregroundColor: viewModel.selectedUnit == unit ? .white : .primary,
                            font: .body.weight(viewModel.selectedUnit == unit ? .semibold : .medium),
                            horizontalPadding: 16,
                            verticalPadding: 12,
                            cornerRadius: 12,
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

// MARK: - Unit Chip Component
struct UnitChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.body.weight(isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accent : Color.appBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.accent : Color.gray.opacity(0.3),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityIdentifier("unit_chip_\(title)")
    }
}
