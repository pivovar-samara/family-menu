//
//  ProductSelectionView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.12.24.
//

import SwiftUI

struct ProductSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: ProductSelectionViewModel
    
    init(viewModel: ProductSelectionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            // Empty state handling
            if viewModel.filteredProducts.isEmpty {
                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // No products at all – show onboarding empty state
                    EmptyProductSelectionView(onAdd: { viewModel.isAddingNewProduct = true })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("product_selection_empty_state")
                } else {
                    // Search yielded no results
                    ViewHelper.emptyState(Color.clear, message: "No results found".localized())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("product_selection_no_results_state")
                }
            } else {
                // Product selection cards
                ForEach(viewModel.filteredProducts, id: \.self) { product in
                    productRow(for: product)
                }
            }

            // Spacer to keep content above any bottom elements
            Color.clear
                .frame(height: 20)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Select Product".localized())
        .searchable(text: $viewModel.searchText, prompt: "Search products...".localized())
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton(sfSymbolName: "plus") {
                viewModel.isAddingNewProduct = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityIdentifier("add_product_button")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel".localized()) {
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
            if viewModel.selectionMode == .multiple {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected".localized()) {
                        viewModel.onProductsSelected?(Array(viewModel.selectedProducts))
                        dismiss()
                    }
                    .disabled(viewModel.selectedProducts.isEmpty)
                    .foregroundColor(Color("AccentColor"))
                    .accessibilityIdentifier("product_selection_done_button")
                }
            }
        }
        .onAppear {
            viewModel.loadProducts()
        }
        .modifier(
            AddSheetModifier(isPresented: $viewModel.isAddingNewProduct) {
                EditProductCoordinator().createEditProductView { saved, product in
                    if saved {
                        viewModel.handleNewProductSaved(product)
                        if viewModel.selectionMode == .single {
                            dismiss()
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Product Selection Card Component
struct ProductSelectionCardView: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Product Icon with Selection State
                ZStack {
                    Circle()
                        .fill(isSelected ? Color("AccentColor") : Color("AccentColor").opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "cube.box")
                            .font(.title3)
                            .foregroundColor(Color("AccentColor"))
                    }
                }
                
                // Product Information
                VStack(alignment: .leading, spacing: 6) {
                    // Product name
                    Text(product.name ?? "Unnamed Product".localized())
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Unit information
                    if let unitName = product.unit?.name?.localized(), !unitName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "per %@".localized(), unitName))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("AccentColor"))
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.3))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color("AccentColor").opacity(0.05) : Color("SecondaryBackgroundColor"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color("AccentColor") : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("product_selection_card_\(product.name ?? "unnamed")")
        .accessibilityLabel("\(product.name ?? "Unnamed Product".localized()), \(product.unit?.name?.localized() ?? "no unit".localized())")
        .accessibilityHint(isSelected ? "Currently selected".localized() : "Tap to select this product".localized())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Private Helpers
private extension ProductSelectionView {
    @ViewBuilder
    func productRow(for product: Product) -> some View {
        let isSelectedSingle = product == viewModel.selectedProduct || product == viewModel.currentProduct
        let isSelectedMulti = viewModel.selectedProducts.contains(product)

        ProductSelectionCardView(
            product: product,
            isSelected: viewModel.selectionMode == .single ? isSelectedSingle : isSelectedMulti,
            onSelect: {
                switch viewModel.selectionMode {
                case .single:
                    viewModel.selectedProduct = product
                    viewModel.onProductSelected(product)
                    dismiss()
                case .multiple:
                    viewModel.toggleSelection(for: product)
                }
            }
        )
        .padding(.vertical, 6)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("product_selection_item_\(product.name ?? "unnamed")")
    }
}

// MARK: - Empty State Component
struct EmptyProductSelectionView: View {
    let onAdd: () -> Void
    var body: some View {
        EmptyStateView(
            icon: "cube.box",
            title: "No Products Available".localized(),
            description: "Create products first to select them for your dishes".localized(),
            actionTitle: "Add Product".localized(),
            action: onAdd
        )
    }
}
