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
            .background(Color("BackgroundColor"))
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
                        backgroundColor: categoryColor(for: categoryName),
                        foregroundColor: .white,
                        font: .caption.weight(.medium),
                        horizontalPadding: UIConstants.chipHorizontalPadding,
                        verticalPadding: UIConstants.chipVerticalPadding,
                        cornerRadius: UIConstants.chipCornerRadius
                    )
                }
                
                Spacer()
                
                // Action buttons
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
                    .accessibilityIdentifier("edit_dish_button_\(dish.name ?? "unnamed")")
                    .accessibilityLabel("Edit dish")
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("delete_dish_button_\(dish.name ?? "unnamed")")
                    .accessibilityLabel("Delete dish")
                }
            }
            
            // Main Content
            VStack(alignment: .leading, spacing: 12) {
                // Dish name with icon
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(Color("AccentColor"))
                        .font(.title2)
                        .frame(width: 24, height: 24)
                    
                    Text(dish.name ?? "Unnamed Dish".localized())
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
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
                                    backgroundColor: Color("BackgroundColor"),
                                    foregroundColor: .secondary,
                                    borderColor: ViewHelper.mealTypeColor(for: mealType).opacity(0.3),
                                    font: .caption,
                                    horizontalPadding: 8,
                                    verticalPadding: 4,
                                    cornerRadius: 8
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

// MARK: - Supporting Components

public struct DishListCategoryChip: View {
    let title: String
    let color: Color
    
    public var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: color.opacity(0.3), radius: 2)
    }
}

public struct DishListMealTypeChip: View {
    let mealType: MealType
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: ViewHelper.mealTypeIcon(for: mealType))
                .font(.caption2)
                .foregroundColor(ViewHelper.mealTypeColor(for: mealType))
            
            Text(mealType.name?.localized() ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color("BackgroundColor"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ViewHelper.mealTypeColor(for: mealType).opacity(0.3), lineWidth: 1)
        )
    }
}

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

