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
        .background(Color("BackgroundColor"))
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
                        .foregroundColor(Color("AccentColor"))
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
        .padding(24)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 12)
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
                    .foregroundColor(Color("AccentColor"))
                    .font(.title3)
                
                Text("Recipe".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Optional".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
        .padding(20)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8)
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
                    .foregroundColor(Color("AccentColor"))
                    .font(.title3)
                
                Text("Category".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 12)
            ], spacing: 12) {
                // No Category Option
                CategoryChip(
                    title: "No Category".localized(),
                    isSelected: selectedCategory == nil,
                    onTap: { onCategorySelected(nil) }
                )
                
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category.name?.localized() ?? "",
                        isSelected: selectedCategory == category,
                        onTap: { onCategorySelected(category) }
                    )
                }
            }
        }
        .padding(20)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

// MARK: - Category Chip Component
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.body.weight(isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color("AccentColor") : Color("BackgroundColor"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(BasicInfoScaleButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Local UI Styles
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color("BackgroundColor"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

struct BasicInfoScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


