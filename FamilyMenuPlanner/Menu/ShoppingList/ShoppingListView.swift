//
//  ShoppingListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingSortOptions = false
    @State private var showingSelectionOptions = false
    
    let shoppingList: [String: [String: Double]] // Dictionary where key is the product name and value is quantity with unit
    let weekDate: Date // The date for the current week
    
    var body: some View {
        List {
            // Progress header
            if !viewModel.shoppingItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(viewModel.purchasedCount), total: Double(max(viewModel.totalCount, 1)))
                        .tint(Color.accent)
                    Text(String(format: "%d of %d purchased".localized(), viewModel.purchasedCount, viewModel.totalCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("shopping_list_progress_label")
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            listContent
        }
        .trackScreenAppear(name: AnalyticsScreenName.ShoppingList)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Shopping List".localized())
        .searchable(text: $viewModel.searchText, prompt: "Search items...".localized())
        .toolbar { toolbarContent }
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
        .onAppear {
            viewModel.clearOldSelections()
            viewModel.loadShoppingList(from: shoppingList, for: weekDate)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.filteredItems.isEmpty {
            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyShoppingListView()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("shopping_list_empty_state")
            } else {
                ViewHelper.emptyState(Color.clear, message: "No results found".localized())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("shopping_list_no_results_state")
            }
        } else {
            ForEach(viewModel.filteredItems, id: \.id) { item in
                ShoppingListCardView(
                    item: item,
                    onToggleSelection: {
                        viewModel.toggleSelection(for: item)
                    }
                )
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("shopping_list_item_\(item.productName)")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if #available(iOS 26.0, *) {
                Button(role: .close) {
                    dismiss()
                }
                .tint(Color.accent)
            } else {
                Button("Close".localized()) {
                    dismiss()
                }
                .foregroundColor(Color.accent)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Selection options button
                if !viewModel.shoppingItems.isEmpty {
                    Button(action: {
                        showingSelectionOptions = true
                    }) {
                        Image(systemName: "checkmark.circle")
                            .font(.body)
                            .foregroundColor(Color.accent)
                    }
                    .accessibilityIdentifier("selection_options_button")
                    .accessibilityLabel("Selection options".localized())
                    .confirmationDialog("Selection options".localized(), isPresented: $showingSelectionOptions, titleVisibility: .visible) {
                        Button("Select All".localized()) {
                            viewModel.selectAll()
                        }
                        Button("Deselect All".localized()) {
                            viewModel.deselectAll()
                        }
                        Button("Cancel".localized(), role: .cancel) {}
                    }
                }
                // Sort button
                Button(action: {
                    showingSortOptions = true
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Color.accent)
                }
                .accessibilityIdentifier("sort_shopping_list_button")
                .accessibilityLabel("Sort shopping list".localized())
                .confirmationDialog("Sort shopping list".localized(), isPresented: $showingSortOptions, titleVisibility: .visible) {
                    ForEach(ShoppingListSortOption.allCases, id: \.self) { option in
                        Button(option.displayName) {
                            viewModel.updateSortOption(option)
                        }
                    }
                    Button("Cancel".localized(), role: .cancel) {}
                }
            }
        }
    }
}

// MARK: - Shopping List Card Component
struct ShoppingListCardView: View {
    let item: ShoppingListItem
    let onToggleSelection: () -> Void
    
    var body: some View {
        Button(action: onToggleSelection) {
            HStack(spacing: 16) {
                // Selection checkbox
                ZStack {
                    Circle()
                        .fill(item.isSelected ? Color.accent : Color.accent.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if item.isSelected {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundColor(Color.accent)
                    }
                }
                
                // Item Information
                VStack(alignment: .leading, spacing: 8) {
                    // Product name
                    Text(item.productName)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .strikethrough(item.isSelected)
                    
                    // Quantity and unit
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(formattedDoubleForUnits(item.quantity)) \(item.unitName.localized())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Shopping cart icon
                Image(systemName: "cart")
                    .font(.title3)
                    .foregroundColor(item.isSelected ? Color.appSuccess : Color.accent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.isSelected ? Color.appSuccess.opacity(0.05) : Color.appSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                item.isSelected ? Color.appSuccess : Color.appBorder,
                                lineWidth: item.isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("shopping_list_card_\(item.productName)")
        .accessibilityLabel("\(item.productName), \(formattedDoubleForUnits(item.quantity)) \(item.unitName.localized())")
        .accessibilityHint(item.isSelected ? "Selected".localized() : "Tap to select this item".localized())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isSelected)
    }
}

// MARK: - Empty State Component
struct EmptyShoppingListView: View {
    var body: some View {
        EmptyStateView(
            icon: "cart",
            title: "No Shopping Items".localized(),
            description: "Generate a menu first to see your shopping list".localized()
        )
    }
}
