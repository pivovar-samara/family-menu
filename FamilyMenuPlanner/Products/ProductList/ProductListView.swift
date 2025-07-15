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
        ToolbarModifier(showingSortOptions: $showingSortOptions, viewModel: viewModel)
    }
    private var productListAddSheet: some ViewModifier {
        AddSheetModifier(isPresented: $viewModel.isAddingNewProduct)
    }
    private var productListEditSheet: some ViewModifier {
        EditSheetModifier(selectedProduct: $viewModel.selectedProduct, viewModel: viewModel)
    }
    private var productListAlert: some ViewModifier {
        AlertModifier(currentAlert: Binding(get: { viewModel.currentAlert }, set: { _ in viewModel.dismissAlert() }))
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
                Color.clear
                    .frame(height: 80)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .accessibilityIdentifier("ProductList")
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundColor"))
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
                        backgroundColor: Color("AccentColor"),
                        foregroundColor: .white,
                        font: .caption.weight(.medium),
                        horizontalPadding: UIConstants.chipHorizontalPadding,
                        verticalPadding: UIConstants.chipVerticalPadding,
                        cornerRadius: UIConstants.chipCornerRadius
                    )
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(Color("AccentColor"))
                            .frame(width: 32, height: 32)
                            .background(Color("AccentColor").opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("EditProductButton")
                    .accessibilityLabel("Edit product")

                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("DeleteProductButton")
                    .accessibilityLabel("Delete product")
                }
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
            backgroundColor: Color("SecondaryBackgroundColor"),
            shadowColor: .black.opacity(0.06),
            shadowRadius: UIConstants.cardShadowRadius,
            borderColor: Color.gray.opacity(0.1),
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
        VStack(spacing: 24) {
            // Illustration
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.1), Color("AccentColor").opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "cart")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color("AccentColor").opacity(0.6))
                )

            VStack(spacing: 12) {
                Text("No Products Yet".localized())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Start building your pantry by adding your first product".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: onAddProduct) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Your First Product".localized())
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color("AccentColor"))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toolbar Modifier
private struct ToolbarModifier: ViewModifier {
    @Binding var showingSortOptions: Bool
    let viewModel: ProductListViewModel
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSortOptions = true }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Color("AccentColor"))
                }
                .accessibilityIdentifier("sort_products_button")
                .accessibilityLabel("Sort products".localized())
                .confirmationDialog("Sort products".localized(), isPresented: $showingSortOptions, titleVisibility: .visible) {
                    Button("Name A-Z".localized()) {
                        viewModel.updateSortOption(.nameAscending)
                    }
                    Button("Name Z-A".localized()) {
                        viewModel.updateSortOption(.nameDescending)
                    }
                    Button("Unit".localized()) {
                        viewModel.updateSortOption(.unit)
                    }
                    Button("Cancel".localized(), role: .cancel) {}
                }
            }
        }
    }
}

// MARK: - Add Sheet Modifier
private struct AddSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            isPresented = false
        }) {
            NavigationStack {
                EditProductCoordinator().createEditProductView()
            }
        }
    }
}

// MARK: - Edit Sheet Modifier
private struct EditSheetModifier: ViewModifier {
    @Binding var selectedProduct: Product?
    let viewModel: ProductListViewModel
    func body(content: Content) -> some View {
        content.sheet(item: $selectedProduct, onDismiss: {
            viewModel.selectedProduct = nil
        }) { product in
            NavigationStack {
                EditProductCoordinator().createEditProductView(
                    product: product,
                    onDismiss: { shouldSave in
                        if !shouldSave {
                            // User dismissed without saving - ensure rollback happens
                            // The EditProductViewModel's deinit will handle rollback as fallback
                            AppLogger.info("Product editing dismissed without saving", category: AppLogger.viewModel)
                        }
                        viewModel.selectedProduct = nil
                    }
                )
            }
        }
    }
}

// MARK: - Alert Modifier
private struct AlertModifier: ViewModifier {
    @Binding var currentAlert: AlertItem?
    func body(content: Content) -> some View {
        content.alert(item: $currentAlert) { alert in
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

