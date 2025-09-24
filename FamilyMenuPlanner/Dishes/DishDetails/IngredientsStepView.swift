//
//  IngredientsStepView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI
import UIKit

struct IngredientsStepView: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                IngredientsHeaderCard(
                    title: "What ingredients do you need?".localized(),
                    subtitle: "Add and organize your ingredients".localized(),
                    icon: "basket",
                    ingredientCount: viewModel.selectedIngredients.count,
                    selectedCategory: viewModel.selectedCategory,
                    selectedMealTypes: viewModel.selectedMealTypes
                )
                
                // Quick Add Section
                QuickAddIngredientCard(viewModel: viewModel)
                
                // Ingredients List
                if !viewModel.selectedIngredients.isEmpty {
                                    IngredientsListCard(
                    ingredients: viewModel.selectedIngredients,
                    currentSortOption: viewModel.currentSortOption,
                    onQuantityChange: viewModel.updateIngredientQuantity,
                    onDelete: viewModel.deleteIngredient,
                    onSort: { sortOption in
                        viewModel.sortIngredients(by: sortOption)
                    },
                    onEdit: { ingredient in
                        viewModel.selectedIngredient = ingredient
                        viewModel.isAddingIngredient = false
                        viewModel.showProductSelection = true
                    }
                )
                } else {
                    EmptyIngredientsCard(
                        onAddFirst: {
                            viewModel.selectedIngredient = nil
                            viewModel.isAddingIngredient = true
                            viewModel.showProductSelection = true
                        }
                    )
                }
                
                Spacer(minLength: 20) // Space for navigation controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Header Card with Ingredient Count
struct IngredientsHeaderCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let ingredientCount: Int
    let selectedCategory: DishCategory?
    let selectedMealTypes: Set<MealType>
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon with Badge
            ZStack {
                Image(systemName: icon)
                    .font(Font(UIFont.preferredFont(forTextStyle: .largeTitle)).weight(.light))
                    .foregroundColor(Color.accent)
                
                if ingredientCount > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.accent)
                                    .frame(width: 24, height: 24)
                                
                                Text("\(ingredientCount)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .frame(width: 48, height: 48)
                }
            }
            
            // Text Content
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Selected category & meal types summary
            if selectedCategory != nil || !selectedMealTypes.isEmpty {
                Divider().padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 12) {
                    if let category = selectedCategory?.name?.localized(), !category.isEmpty {
                        ChipView(
                            text: category,
                            icon: "tag",
                            style: .outline,
                            tint: Color.accent,
                            font: .caption
                        )
                    }

                    if !selectedMealTypes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedMealTypes), id: \.self) { mealType in
                                    ChipView(
                                        text: mealType.name?.localized() ?? "",
                                        icon: ViewHelper.mealTypeIcon(for: mealType),
                                        style: .outline,
                                        tint: StylingHelper.mealTypeColor(for: mealType),
                                        font: .caption
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
        .padding(24)
        .background(Color.appSecondaryBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

// MARK: - Quick Add Ingredient Card
struct QuickAddIngredientCard: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Add Ingredient".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                viewModel.selectedIngredient = nil
                viewModel.isAddingIngredient = true
                viewModel.showProductSelection = true
            }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.title3)
                    
                    Text("Select Product".localized())
                        .font(.body.weight(.medium))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(Color.accent)
                .padding(16)
                .background(Color.accent.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

// MARK: - Ingredients List Card
struct IngredientsListCard: View {
    let ingredients: [IngredientDetail]
    let currentSortOption: IngredientSortOption
    let onQuantityChange: (IngredientDetail, Double) -> Void
    let onDelete: (IndexSet) -> Void
    let onSort: (IngredientSortOption) -> Void
    let onEdit: (IngredientDetail) -> Void
    
    @State private var shouldDismissFocus = false
    

    
    private var sortedIngredients: [IngredientDetail] {
        switch currentSortOption {
        case .custom:
            return ingredients.sorted { $0.sortOrder < $1.sortOrder }
        case .alphabetical:
            return ingredients.sorted { 
                ($0.product?.name ?? "").localizedCaseInsensitiveCompare($1.product?.name ?? "") == .orderedAscending 
            }
        case .reverseAlphabetical:
            return ingredients.sorted { 
                ($0.product?.name ?? "").localizedCaseInsensitiveCompare($1.product?.name ?? "") == .orderedDescending 
            }
        case .quantityHighToLow:
            return ingredients.sorted { $0.quantity > $1.quantity }
        case .quantityLowToHigh:
            return ingredients.sorted { $0.quantity < $1.quantity }
        case .unitType:
            return ingredients.sorted { 
                let unit1 = $0.product?.unit?.name ?? ""
                let unit2 = $1.product?.unit?.name ?? ""
                if unit1 == unit2 {
                    return ($0.product?.name ?? "").localizedCaseInsensitiveCompare($1.product?.name ?? "") == .orderedAscending
                }
                return unit1.localizedCaseInsensitiveCompare(unit2) == .orderedAscending
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Ingredients List".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Sort Button
                Picker("Sort", selection: Binding(
                    get: { currentSortOption },
                    set: { newOption in
                        // Dismiss any focused text fields before sorting
                        shouldDismissFocus = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shouldDismissFocus = false
                        }
                        onSort(newOption)
                    }
                )) {
                    ForEach(IngredientSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue.localized())
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.accent)
            }
            
            Text("Tap to edit • Long press for options".localized())
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(sortedIngredients.indices, id: \.self) { index in
                    SmartIngredientRow(
                        ingredient: sortedIngredients[index],
                        onQuantityChange: onQuantityChange,
                        onEdit: { onEdit(sortedIngredients[index]) },
                        onDelete: { 
                            if let originalIndex = ingredients.firstIndex(of: sortedIngredients[index]) {
                                onDelete(IndexSet(integer: originalIndex))
                            }
                        },
                        showWarning: ViewHelper.hasUnusualQuantity(sortedIngredients[index]),
                        shouldDismissFocus: $shouldDismissFocus
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
        .padding(20)
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
    
    private func hasUnusualQuantity(_ ingredient: IngredientDetail) -> Bool {
        return ViewHelper.hasUnusualQuantity(ingredient)
    }
}

// MARK: - Smart Ingredient Row
struct SmartIngredientRow: View {
    let ingredient: IngredientDetail
    let onQuantityChange: (IngredientDetail, Double) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let showWarning: Bool
    @Binding var shouldDismissFocus: Bool
    
    @State private var isEditing = false
    @State private var tempQuantity: String = ""
    @State private var displayQuantity: Double?
    @FocusState private var isQuantityFieldFocused: Bool
    
    private var formattedQuantity: String {
        let quantity = displayQuantity ?? ingredient.quantity
        
        // Use NumberFormatter to respect locale for decimal separator display
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        
        if let formattedString = formatter.string(from: NSNumber(value: quantity)) {
            return formattedString
        } else {
            // Fallback to standard formatting
            if quantity == floor(quantity) {
                return String(Int(quantity))
            } else {
                return String(format: "%.1f", quantity)
            }
        }
    }
    
    private var quantityTextField: some View {
        HStack(spacing: 4) {
            TextField("0", text: $tempQuantity, onEditingChanged: { isCurrentlyEditing in
                // When editing ends (focus lost), commit the change
                if !isCurrentlyEditing {
                    commitQuantityChange()
                }
            })
            .keyboardType(.decimalPad)
            .focused($isQuantityFieldFocused)
            .font(Font(UIFont.preferredFont(forTextStyle: .title3)).weight(.semibold).monospacedDigit())
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: 70)
            .background(isQuantityFieldFocused ? Color.accent.opacity(0.2) : Color.accent.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isQuantityFieldFocused ? Color.accent : Color.accent.opacity(0.5), lineWidth: isQuantityFieldFocused ? 2 : 1)
            )
            .onSubmit {
                commitQuantityChange()
            }
            .onAppear {
                tempQuantity = formattedQuantity
                // Auto-focus when entering edit mode with a more reliable delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if isEditing {
                        isQuantityFieldFocused = true
                    }
                }
            }
            .onChange(of: shouldDismissFocus) { shouldDismiss in
                if shouldDismiss && isQuantityFieldFocused && isEditing {
                    // Add a small delay to allow any ongoing UI updates to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if shouldDismiss { // Check again in case it was reset
                            isQuantityFieldFocused = false
                            commitQuantityChange()
                        }
                    }
                }
            }
            
            if let unit = ingredient.product?.unit?.name {
                Text(unit.localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Product Info
                Button(action: onEdit) {
                    HStack(spacing: 12) {
                        // Product Icon
                        ZStack {
                            Circle()
                                .fill(showWarning ? Color.appWarning.opacity(0.1) : Color.accent.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: showWarning ? "exclamationmark" : (ingredient.product != nil ? "checkmark" : "questionmark"))
                                .font(.body.weight(.medium))
                                .foregroundColor(showWarning ? .appWarning : (ingredient.product != nil ? Color.accent : .secondary))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ingredient.product?.name ?? "Select Product".localized())
                                .font(.body.weight(.medium))
                                .foregroundColor(ingredient.product == nil ? .secondary : .primary)
                                .lineLimit(2)
                            
                            if let unit = ingredient.product?.unit?.name {
                                Text("per \(unit.localized())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(Text(ingredient.product?.name ?? "Select Product".localized()))
                .accessibilityHint(Text("Tap to select this product".localized()))
                
                // Quantity Controls
                VStack(spacing: 8) {
                    // Quantity Display/Editor
                    if isEditing {
                        quantityTextField
                    } else {
                        Button(action: { startEditing() }) {
                            HStack(spacing: 4) {
                                Text(formattedQuantity)
                                    .font(Font(UIFont.preferredFont(forTextStyle: .title3)).weight(.semibold).monospacedDigit())
                                    .foregroundColor(.primary)
                                
                                if let unit = ingredient.product?.unit?.name {
                                    Text(unit.localized())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accent.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel(Text(String(format: "%@ %@", formattedQuantity, (ingredient.product?.unit?.name?.localized() ?? "").trimmingCharacters(in: .whitespaces))))
                        .accessibilityHint(Text("Tap to edit quantity".localized()))
                    }
                    
                    // Quantity Adjustment Controls
                    if !isEditing {
                        HStack(spacing: 8) {
                            Button(action: {
                                adjustQuantity(-1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Color.appError)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(Text("Decrease quantity".localized()))
                            
                            Button(action: {
                                adjustQuantity(1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Color.accent)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(Text("Increase quantity".localized()))
                        }
                    }
                }
            }
            
            // Warning message at the bottom
            if showWarning {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(Color.appWarning)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let info = DataValidationHelper.unusualQuantityMessage(for: ingredient) {
                            Text(info.message)
                                .font(.caption)
                                .foregroundColor(Color.appWarning)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(info.suggestion)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Large quantity".localized())
                                .font(.caption)
                                .foregroundColor(Color.appWarning)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.appChipBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit".localized(), systemImage: "pencil")
            }
            
            Button(action: onDelete) {
                Label("Delete".localized(), systemImage: "trash")
            }
        }
        .onAppear {
            // Sync display quantity with actual ingredient quantity on appear
            displayQuantity = nil
        }
        .onChange(of: ingredient.quantity) { newQuantity in
            // Only sync if we're not in the middle of a local adjustment
            if displayQuantity == nil {
                displayQuantity = nil // Keep showing actual quantity
            } else {
                // After a brief delay, sync back to the actual stored quantity
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    displayQuantity = nil
                }
            }
        }
    }
    
    private func startEditing() {
        isEditing = true
        tempQuantity = formattedQuantity
        // Ensure focus is set after the view updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isQuantityFieldFocused = true
        }
    }
    
    private func commitQuantityChange() {
        // Normalize decimal separator - handle both comma and period input
        let normalizedQuantity = tempQuantity.replacingOccurrences(of: ",", with: ".")
        
        if let newQuantity = Double(normalizedQuantity), newQuantity > 0 {
            let clampedQuantity = max(newQuantity, 0.1) // Allow any positive value, minimum 0.1
            displayQuantity = clampedQuantity // Update display immediately
            onQuantityChange(ingredient, clampedQuantity)
        }
        isQuantityFieldFocused = false
        isEditing = false
        
        // Reset display quantity after a brief delay to sync with Core Data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            displayQuantity = nil
        }
    }
    
    private func adjustQuantity(_ delta: Int) {
        let currentQuantity = displayQuantity ?? ingredient.quantity
        let step = getQuantityStep()
        let newQuantity = currentQuantity + (Double(delta) * step)
        let clampedQuantity = max(newQuantity, 0.1) // Minimum of 0.1 to prevent zero
        
        // Only update if the quantity actually changed
        if clampedQuantity != currentQuantity {
            // Update display quantity immediately for instant UI feedback
            displayQuantity = clampedQuantity
            
            // Update Core Data in the background
            onQuantityChange(ingredient, clampedQuantity)
        }
    }
    
    private func getQuantityStep() -> Double {
        guard let unit = ingredient.product?.unit?.name?.lowercased() else { return 1.0 }
        let currentQuantity = displayQuantity ?? ingredient.quantity
        
        switch unit {
        case "kg", "kilogram", "kilograms", "l", "liter", "liters", "litre", "litres":
            return 0.1
        case "g", "gram", "grams":
            return currentQuantity < 100 ? 10 : 50
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            return currentQuantity < 100 ? 10 : 50
        case "pcs", "pieces", "piece":
            return 1.0
        default:
            return 0.1
        }
    }
}

// MARK: - Empty Ingredients Card
struct EmptyIngredientsCard: View {
    let onAddFirst: () -> Void
    
    var body: some View {
        EmptyStateView(
            icon: "basket",
            title: "No ingredients yet".localized(),
            description: "Start by adding your first ingredient".localized(),
            actionTitle: "Add First Ingredient".localized(),
            action: onAddFirst
        )
        .background(Color.appSecondaryBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

// Replaced by ChipView with ChipStyle
