//
//  ReviewStepView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct ReviewStepView: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                HeaderCard(
                    title: "Ready to save?".localized(),
                    subtitle: "Review your dish details".localized(),
                    icon: "checkmark.circle"
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Review".localized()))
                
                // Dish Summary Card
                DishSummaryCard(viewModel: viewModel)
                    .accessibilityElement(children: .contain)
                
                // Validation Card
                ValidationCard(viewModel: viewModel)
                    .accessibilityElement(children: .contain)
                
                // Quick Edit Actions
                QuickEditActionsCard()
                    .accessibilityElement(children: .contain)
                
                Spacer(minLength: 20) // Space for navigation controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Dish Summary Card
struct DishSummaryCard: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Dish Summary".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                // Basic Info Section
                SummarySection(
                    title: "Basic Information".localized(),
                    icon: "info.circle"
                ) {
                    HStack {
                        Spacer(minLength: 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SummaryRow(
                                label: "Name".localized(),
                                value: viewModel.dish?.name ?? "Unnamed Dish".localized(),
                                isValid: !(viewModel.dish?.name?.isEmpty ?? true)
                            )
                            
                            if !viewModel.descriptionText.isEmpty {
                                SummaryRow(
                                    label: "Description".localized(),
                                    value: viewModel.descriptionText,
                                    isMultiline: true
                                )
                            }
                            
                            SummaryRow(
                                label: "Category".localized(),
                                value: viewModel.selectedCategory?.name?.localized() ?? "No Category".localized()
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Divider()
                
                // Meal Types Section
                SummarySection(
                    title: "Meal Types".localized(),
                    icon: "clock"
                ) {
                    if !viewModel.selectedMealTypes.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Array(viewModel.selectedMealTypes), id: \.self) { mealType in
                                ChipView(
                                    text: mealType.name?.localized() ?? "",
                                    icon: ViewHelper.mealTypeIcon(for: mealType),
                                    buttonStateStyle: .chip,
                                    isSelected: false,
                                    font: .caption
                                )
                            }
                        }
                    } else {
                        HStack {
                            Spacer(minLength: 4)
                            Text("No meal types selected".localized())
                                .foregroundColor(Color.appError)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                Divider()
                
                // Ingredients Section
                SummarySection(
                    title: String.localizedStringWithFormat("Ingredients (%d)".localized(), viewModel.selectedIngredients.count),
                    icon: "basket"
                ) {
                    if !viewModel.selectedIngredients.isEmpty {
                        HStack{
                            Spacer(minLength: 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.selectedIngredients, id: \.objectID) { ingredient in
                                    IngredientSummaryRow(
                                        ingredient: ingredient,
                                        showWarning: ViewHelper.hasUnusualQuantity(ingredient)
                                    )
                                    .id("\(ingredient.objectID)-\(ingredient.quantity)-\(ingredient.product?.objectID.description ?? "")")
                                }
                            }
                        }
                    } else {
                        HStack {
                            Spacer(minLength: 4)
                            Text("No ingredients added".localized())
                                .foregroundColor(Color.appError)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
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

// MARK: - Summary Section
struct SummarySection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.accent)
                    .font(.body)
                
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            content
                .padding(.leading, 24)
        }
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let label: String
    let value: String
    var isValid: Bool = true
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            
            if isMultiline {
                Text(value)
                    .font(.body)
                    .foregroundColor(isValid ? .primary : Color.appError)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(value)
                    .font(.body)
                    .foregroundColor(isValid ? .primary : Color.appError)
            }
        }
    }
}

// Replaced by ChipView with ChipStyle

// MARK: - Ingredient Summary Row
struct IngredientSummaryRow: View {
    let ingredient: IngredientDetail
    let showWarning: Bool
    
    private var formattedQuantity: String {
        let quantity = ingredient.quantity
        if quantity == floor(quantity) {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
    
    var body: some View {
        HStack {
            if showWarning {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color.appWarning)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color.accent.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.product?.name ?? "Unknown Product".localized())
                    .font(.body)
                    .foregroundColor(.primary)
                
                if showWarning {
                    if let info = DataValidationHelper.unusualQuantityMessage(for: ingredient) {
                        Text(info.message)
                            .font(.caption)
                            .foregroundColor(.appWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Large quantity".localized())
                            .font(.caption)
                            .foregroundColor(.appWarning)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(formattedQuantity)
                    .font(.body.weight(.medium).monospacedDigit())
                    .foregroundColor(showWarning ? Color.appWarning : .primary)
                
                Text(ingredient.product?.unit?.name?.localized() ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Validation Card
struct ValidationCard: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    
    private var validationIssues: [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if viewModel.dish?.name?.isEmpty ?? true {
            issues.append(ValidationIssue(
                type: .error,
                message: "Dish name is required".localized(),
                suggestion: "Add a descriptive name for your dish".localized()
            ))
        }
        
        if viewModel.selectedMealTypes.isEmpty {
            issues.append(ValidationIssue(
                type: .error,
                message: "At least one meal type is required".localized(),
                suggestion: "Select when this dish is typically served".localized()
            ))
        }
        
        if viewModel.selectedIngredients.isEmpty {
            issues.append(ValidationIssue(
                type: .error,
                message: "At least one ingredient is required".localized(),
                suggestion: "Add the ingredients needed for this dish".localized()
            ))
        }
        
        // Check for ingredients without products
        let incompleteIngredients = viewModel.selectedIngredients.filter { $0.product == nil }
        if !incompleteIngredients.isEmpty {
            issues.append(ValidationIssue(
                type: .warning,
                message: "\(incompleteIngredients.count) ingredient(s) missing product selection".localized(),
                suggestion: "Complete product selection for all ingredients".localized()
            ))
        }
        
        // Per-ingredient unusual quantity details
        for ingredient in viewModel.selectedIngredients {
            if let info = DataValidationHelper.unusualQuantityMessage(for: ingredient) {
                issues.append(ValidationIssue(
                    type: .warning,
                    message: info.message,
                    suggestion: info.suggestion
                ))
            }
        }
        
        return issues
    }
    
    var body: some View {
        if validationIssues.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundColor(Color.appWarning)
                        .font(.title3)
                    
                    Text("Validation".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(validationIssues, id: \.message) { issue in
                        ValidationIssueRow(issue: issue)
                    }
                }
            }
            .padding(20)
            .background(Color.appSecondaryBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 8)
        }
    }
    
    private func hasUnusualQuantity(_ ingredient: IngredientDetail) -> Bool {
        guard let unit = ingredient.product?.unit?.name?.lowercased() else { return false }
        let quantity = ingredient.quantity
        
        switch unit {
        case "kg": return quantity > 5.0
        case "g": return quantity > 2000
        case "l": return quantity > 3.0
        case "ml": return quantity > 2000
        case "pcs", "pieces", "piece": return quantity > 20
        default: return false
        }
    }
}

// MARK: - Validation Issue Row
struct ValidationIssueRow: View {
    let issue: ValidationIssue
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.type.icon)
                .foregroundColor(issue.type.color)
                .font(.body)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.message)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(issue.suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(issue.type.color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(issue.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Edit Actions Card
struct QuickEditActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.circle")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Need to make changes?".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text("Use the Back button or swipe to return to previous steps and make any necessary changes.".localized())
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.accent.opacity(0.05), Color.accent.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 4)
    }
} 

