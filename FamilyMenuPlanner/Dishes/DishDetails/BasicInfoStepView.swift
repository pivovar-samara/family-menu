//
//  BasicInfoStepView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct BasicInfoStepView: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, description
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Card - Name
                HeroInfoCard(
                    name: Binding(
                        get: { viewModel.dish?.name ?? "" },
                        set: { newValue in 
                            viewModel.dish?.name = newValue
                            viewModel.objectWillChange.send()
                        }
                    ),
                    focusState: $focusedField,
                    focusValue: .name
                )
                
                // Description Card
                DescriptionCard(
                    description: $viewModel.descriptionText,
                    focusState: $focusedField,
                    focusValue: .description
                )
                .onChange(of: viewModel.descriptionText) { newValue in
                    viewModel.dish?.details = newValue
                    viewModel.objectWillChange.send()
                }
                
                // Category Selection Card
                CategorySelectionCard(
                    selectedCategory: $viewModel.selectedCategory,
                    categories: viewModel.allDishCategories,
                    onCategorySelected: viewModel.setDishCategory
                )
                
                Spacer(minLength: 20) // Space for navigation controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color.appBackground)
        .onAppear {
            viewModel.descriptionText = viewModel.dish?.details ?? ""
        }
    }
}

// MARK: - Hero Info Card
struct HeroInfoCard: View {
    @Binding var name: String
    var focusState: FocusState<BasicInfoStepView.Field?>.Binding
    let focusValue: BasicInfoStepView.Field
    
    var body: some View {
        VStack(spacing: 20) {
            // Name Input
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(Color.accent)
                        .font(.title3)
                    
                    Text("Dish Name".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                TextField("Enter dish name".localized(), text: $name)
                    .textFieldStyle(ModernTextFieldStyle())
                    .focused(focusState, equals: focusValue)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.words)
            }
        }
        .cardStyle(
            cornerRadius: 20,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.06),
            shadowRadius: 12,
            borderColor: Color.clear,
            borderWidth: 0,
            padding: 24
        )
    }
}

// MARK: - Description Card
struct DescriptionCard: View {
    @Binding var description: String
    var focusState: FocusState<BasicInfoStepView.Field?>.Binding
    let focusValue: BasicInfoStepView.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Recipe".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                ChipView(
                    text: "Optional".localized(),
                    background: Color.gray.opacity(0.2),
                    font: .caption,
                    horizontalPadding: 8,
                    verticalPadding: 4,
                    cornerRadius: 8
                )
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder, lineWidth: 1)
                    .background(Color.clear)
                
                TextEditor(text: $description)
                    .padding(12)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .focused(focusState, equals: focusValue)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.sentences)
            }
            .frame(minHeight: 100)
        }
        .cardStyle(
            cornerRadius: 16,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.04),
            shadowRadius: 8,
            borderColor: Color.clear,
            borderWidth: 0,
            padding: 20
        )
    }
}

// MARK: - Category Selection Card
struct CategorySelectionCard: View {
    @Binding var selectedCategory: DishCategory?
    let categories: [DishCategory]
    let onCategorySelected: (DishCategory?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Category".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 12)
            ], spacing: 12) {
                // No Category Option
                ChipView(
                    text: "No Category".localized(),
                    isSelected: selectedCategory == nil,
                        background: selectedCategory == nil ? Color.accent : Color.appChipBackground,
                    foregroundColor: selectedCategory == nil ? .white : .primary,
                    font: .body.weight(selectedCategory == nil ? .semibold : .medium),
                    horizontalPadding: 16,
                    verticalPadding: 10,
                    cornerRadius: 20,
                    onTap: { onCategorySelected(nil) }
                )
                
                ForEach(categories, id: \.self) { category in
                    ChipView(
                        text: category.name?.localized() ?? "",
                        isSelected: selectedCategory == category,
                        background: selectedCategory == category ? Color.accent : Color.appChipBackground,
                        foregroundColor: selectedCategory == category ? .white : .primary,
                        font: .body.weight(selectedCategory == category ? .semibold : .medium),
                        horizontalPadding: 16,
                        verticalPadding: 10,
                        cornerRadius: 20,
                        onTap: { onCategorySelected(category) }
                    )
                }
            }
        }
        .cardStyle(
            cornerRadius: 16,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.04),
            shadowRadius: 8,
            borderColor: Color.clear,
            borderWidth: 0,
            padding: 20
        )
    }
}

