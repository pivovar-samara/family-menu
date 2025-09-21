//
//  DishListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct DishListView: View {
    @StateObject private var viewModel: DishListViewModel
    @State private var showingSortOptions = false

    init(viewModel: DishListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        DishListBody(
            filteredDishes: viewModel.filteredDishes,
            searchText: viewModel.searchText,
            onAdd: { viewModel.isAddingNewDish = true },
            onEdit: { dish in viewModel.selectedDish = dish },
            onDelete: { dish in viewModel.deleteDish(dish) }
        )
        .searchable(text: $viewModel.searchText, prompt: "Search dishes...".localized())
        .modifier(dishListToolbar)
        .modifier(dishListAddSheet)
        .modifier(dishListEditSheet)
        .modifier(dishListAlert)
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton(sfSymbolName: "plus") {
                viewModel.isAddingNewDish = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityIdentifier("add_dish_button")
        }
        .onAppear {
            viewModel.loadDishes()
        }
    }

    private var dishListToolbar: some ViewModifier {
        SortingToolbarModifier(
            showingSortOptions: $showingSortOptions,
            sortOptions: Array(DishSortOption.allCases),
            onSortOptionSelected: { sortOption in
                viewModel.updateSortOption(sortOption)
            },
            accessibilityIdentifier: "sort_dishes_button",
            accessibilityLabel: "Sort dishes".localized(),
            dialogTitle: "Sort dishes".localized()
        )
    }
    private var dishListAddSheet: some ViewModifier {
        AddSheetModifier(isPresented: $viewModel.isAddingNewDish) {
            DishDetailsCoordinator().createDishDetailsView()
        }
    }
    private var dishListEditSheet: some ViewModifier {
        EditSheetModifier(
            selectedItem: $viewModel.selectedDish,
            onDismiss: { viewModel.selectedDish = nil }
        ) { dish in
            DishDetailsCoordinator().createDishDetailsView(
                dish: dish,
                onDismiss: { shouldSave in
                    if !shouldSave {
                        AppLogger.info("Dish editing dismissed without saving", category: AppLogger.viewModel)
                    }
                    viewModel.selectedDish = nil
                }
            )
        }
    }
    private var dishListAlert: some ViewModifier {
        AlertModifier(
            currentAlert: Binding(get: { viewModel.currentAlert }, set: { _ in viewModel.dismissAlert() }),
            onDismiss: { viewModel.dismissAlert() }
        )
    }

    private struct DishListBody: View {
        let filteredDishes: [Dish]
        let searchText: String
        let onAdd: () -> Void
        let onEdit: (Dish) -> Void
        let onDelete: (Dish) -> Void
        var body: some View {
            List {
                if filteredDishes.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DishListEmptyState(onAdd: onAdd)
                    } else {
                        DishListNoResultsState()
                    }
                } else {
                    DishListRows(dishes: filteredDishes, onEdit: onEdit, onDelete: onDelete)
                }
                Color.clear
                    .frame(height: 80)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
    }

    private struct DishListRows: View {
        let dishes: [Dish]
        let onEdit: (Dish) -> Void
        let onDelete: (Dish) -> Void
        var body: some View {
            ForEach(dishes, id: \.self) { dish in
                dishCard(for: dish)
            }
        }
        @ViewBuilder
        private func dishCard(for dish: Dish) -> some View {
            DishCardView(
                dish: dish,
                onEdit: { onEdit(dish) },
                onDelete: { onDelete(dish) }
            )
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("dish_list_item_\(dish.name ?? "unnamed")")
        }
    }

    private struct DishListEmptyState: View {
        let onAdd: () -> Void
        var body: some View {
            EmptyDishListView(onAddDish: onAdd)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("dish_list_empty_state")
        }
    }

    private struct DishListNoResultsState: View {
        var body: some View {
            ViewHelper.emptyState(Color.clear, message: "No results found".localized())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("dish_list_no_results_state")
        }
    }
}

// MARK: - Dish Card Component
struct DishCardView: View {
    let dish: Dish
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Category and Actions
            HStack {
                // Category chip
                if let categoryName = dish.category?.name {
                    ChipView(
                        text: categoryName.localized(),
                        style: .filled,
                        tint: categoryColor(for: categoryName),
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
                .accessibilityIdentifier("edit_dish_button_\(dish.name ?? "unnamed")")
                .accessibilityLabel("Edit dish")
            }
            
            // Main Content
            VStack(alignment: .leading, spacing: 12) {
                // Dish name with icon
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(Color.accent)
                        .font(.title2)
                        .frame(width: 24, height: 24)
                    
                    Text(dish.name ?? "Unnamed Dish".localized())
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier("dish_name_\(dish.name ?? "unnamed")")
                }
                
                // Description
                if let details = dish.details, !details.isEmpty {
                    Text(details)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("No recipe details".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Footer with meal types
            if let mealTypes = dish.mealTypes?.allObjects as? [MealType], !mealTypes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(mealTypes, id: \.self) { mealType in
                                ChipView(
                                    text: mealType.name?.localized() ?? "",
                                    icon: ViewHelper.mealTypeIcon(for: mealType),
                                    style: .outline,
                                    tint: StylingHelper.mealTypeColor(for: mealType),
                                    font: .caption
                                )
                            }
                        }
                        .padding(.horizontal, 1) // Prevent clipping
                    }
                }
            }
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
        .accessibilityElement(children: .contain)
        .confirmationDialog(
            "Delete Dish".localized(),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete".localized(), role: .destructive) {
                onDelete()
            }
            Button("Cancel".localized(), role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this dish?".localized())
        }
    }
    
    // Helper function to get color for different categories
    private func categoryColor(for categoryName: String) -> Color {
        return StylingHelper.categoryColor(for: categoryName)
    }
}

// Legacy chip components were removed in favor of ChipView with ChipStyle

struct EmptyDishListView: View {
    let onAddDish: () -> Void
    
    var body: some View {
        EmptyStateView(
            icon: "fork.knife.circle",
            title: "No Dishes Yet".localized(),
            description: "Start building your recipe collection by adding your first dish".localized(),
            actionTitle: "Add Your First Dish".localized(),
            action: onAddDish
        )
    }
}

// MARK: - Extensions for ViewModel

extension DishListViewModel {
    func deleteDish(_ dish: Dish) {
        guard let index = filteredDishes.firstIndex(of: dish) else { return }
        deleteDishes(at: IndexSet([index]))
    }
}

