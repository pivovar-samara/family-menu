//
//  ProductListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI

struct ProductListView: View {
    @StateObject private var viewModel: ProductListViewModel
    // Sorting dialog state
    @State private var showingSortOptions = false
    // Additional UI state variables can be added here as needed

    init(viewModel: ProductListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ProductListBody(
            filteredProducts: viewModel.filteredProducts,
            searchText: viewModel.searchText,
            onAdd: { viewModel.isAddingNewProduct = true },
            onEdit: { product in viewModel.selectedProduct = product },
            onDelete: { product in viewModel.deleteProduct(product) }
        )
        .searchable(text: $viewModel.searchText, prompt: "Search products...".localized())
        .navigationTitle("Products".localized())
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton(sfSymbolName: "plus") {
                viewModel.isAddingNewProduct = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityIdentifier("add_product_button")
        }
        .modifier(productListToolbar)
        .modifier(productListAddSheet)
        .modifier(productListEditSheet)
        .modifier(productListAlert)
        .onAppear {
            viewModel.loadProducts()
        }
    }

    private var productListToolbar: some ViewModifier {
        SortingToolbarModifier(
            showingSortOptions: $showingSortOptions,
            sortOptions: Array(ProductSortOption.allCases),
            onSortOptionSelected: { sortOption in
                viewModel.updateSortOption(sortOption)
            },
            accessibilityIdentifier: "sort_products_button",
            accessibilityLabel: "Sort products".localized(),
            dialogTitle: "Sort products".localized()
        )
    }
    private var productListAddSheet: some ViewModifier {
        AddSheetModifier(isPresented: $viewModel.isAddingNewProduct) {
            EditProductCoordinator().createEditProductView()
        }
    }
    private var productListEditSheet: some ViewModifier {
        EditSheetModifier(
            selectedItem: $viewModel.selectedProduct,
            onDismiss: { viewModel.selectedProduct = nil }
        ) { product in
            EditProductCoordinator().createEditProductView(
                product: product,
                onDismiss: { shouldSave, _ in
                    if !shouldSave {
                        AppLogger.info("Product editing dismissed without saving", category: AppLogger.viewModel)
                    }
                    viewModel.selectedProduct = nil
                }
            )
        }
    }
    private var productListAlert: some ViewModifier {
        AlertModifier(
            currentAlert: Binding(get: { viewModel.currentAlert }, set: { _ in viewModel.dismissAlert() }),
            onDismiss: { viewModel.dismissAlert() }
        )
    }

    private struct ProductListBody: View {
        let filteredProducts: [Product]
        let searchText: String
        let onAdd: () -> Void
        let onEdit: (Product) -> Void
        let onDelete: (Product) -> Void
        var body: some View {
            List {
                if filteredProducts.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ProductListEmptyState(onAdd: onAdd)
                    } else {
                        ProductListNoResultsState()
                    }
                } else {
                    ProductListRows(products: filteredProducts, onEdit: onEdit, onDelete: onDelete)
                }
            }
            .accessibilityIdentifier("ProductList")
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
    }

    private struct ProductListRows: View {
        let products: [Product]
        let onEdit: (Product) -> Void
        let onDelete: (Product) -> Void
        var body: some View {
            ForEach(products, id: \.self) { product in
                productCard(for: product)
            }
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        @ViewBuilder
        private func productCard(for product: Product) -> some View {
            ProductCardView(
                product: product,
                onEdit: { onEdit(product) },
                onDelete: { onDelete(product) }
            )
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("product_list_item_\(product.name ?? "unnamed")")
        }
    }

    private struct ProductListEmptyState: View {
        let onAdd: () -> Void
        var body: some View {
            EmptyProductListView(onAddProduct: onAdd)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("product_list_empty_state")
        }
    }

    private struct ProductListNoResultsState: View {
        var body: some View {
            ViewHelper.emptyState(Color.clear, message: "No results found".localized())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("product_list_no_results_state")
        }
    }
}

// MARK: - Product Card Component
struct ProductCardView: View {
    let product: Product
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with unit chip and actions
            HStack {
                if let unitName = product.unit?.name?.localized(), !unitName.isEmpty {
                    ChipView(
                        text: unitName,
                        style: .filled,
                        tint: Color.accent,
                        font: .caption
                    )
                }

                Spacer()

                // Visible Edit menu trigger
                SwiftUI.Menu {
                    Button(action: onEdit) {
                        Label("Edit".localized(), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete".localized(), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(Color.accent)
                        .frame(width: 32, height: 32)
                        .background(Color.accent.opacity(0.1))
                        .cornerRadius(8)
                }
                .accessibilityIdentifier("EditProductButton")
                .accessibilityLabel("Edit product")
            }

            // Product name
            Text(product.name ?? "Unnamed Product".localized())
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("ProductNameLabel")
        }
        .cardStyle(
            cornerRadius: UIConstants.cardCornerRadius,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.06),
            shadowRadius: UIConstants.cardShadowRadius,
            borderColor: Color.appBorder,
            borderWidth: UIConstants.cardBorderWidth,
            padding: UIConstants.cardPadding
        )
        .onTapGesture {
            onEdit()
        }
        .confirmationDialog(
            "Delete Product".localized(),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete".localized(), role: .destructive) {
                onDelete()
            }
            Button("Cancel".localized(), role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this product?".localized())
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Supporting Components
// ProductListUnitChip is now replaced by ChipView in ProductCardView
struct EmptyProductListView: View {
    let onAddProduct: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "cart",
            title: "No Products Yet".localized(),
            description: "Start building your pantry by adding your first product".localized(),
            actionTitle: "Add Your First Product".localized(),
            action: onAddProduct
        )
    }
}

