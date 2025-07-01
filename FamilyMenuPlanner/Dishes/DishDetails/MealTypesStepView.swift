//
//  MealTypesStepView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct MealTypesStepView: View {
    @ObservedObject var viewModel: DishDetailsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                HeaderCard(
                    title: "When is this dish served?".localized(),
                    subtitle: "Select all meal types that apply".localized(),
                    icon: "clock"
                )
                
                // Meal Types Grid
                MealTypesGridCard(
                    mealTypes: viewModel.allMealTypes,
                    selectedMealTypes: viewModel.selectedMealTypes,
                    onToggle: viewModel.toggleMealTypeSelection
                )
            
                Spacer(minLength: 20) // Space for navigation controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color("BackgroundColor"))
    }
}

// MARK: - Header Card
struct HeaderCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color("AccentColor"))
            
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
        }
        .padding(24)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

// MARK: - Meal Types Grid Card
struct MealTypesGridCard: View {
    let mealTypes: [MealType]
    let selectedMealTypes: Set<MealType>
    let onToggle: (MealType) -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(Color("AccentColor"))
                    .font(.title3)
                
                Text("Meal Types".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Selection Counter
                Text(String.localizedStringWithFormat("%d selected".localized(), selectedMealTypes.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("AccentColor").opacity(0.1))
                    .cornerRadius(8)
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(mealTypes, id: \.self) { mealType in
                    MealTypeCard(
                        mealType: mealType,
                        isSelected: selectedMealTypes.contains(mealType),
                        onToggle: { onToggle(mealType) }
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

// MARK: - Meal Type Card
struct MealTypeCard: View {
    let mealType: MealType
    let isSelected: Bool
    let onToggle: () -> Void
    
    private var mealTypeIcon: String {
        guard let name = mealType.name?.lowercased() else { return "fork.knife" }
        switch name {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "heart.fill"
        default: return "fork.knife"
        }
    }
    
    private var mealTypeColor: Color {
        guard let name = mealType.name?.lowercased() else { return .orange }
        switch name {
        case "breakfast": return .orange
        case "lunch": return .yellow
        case "dinner": return .purple
        case "snack": return .pink
        default: return Color("AccentColor")
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(isSelected ? mealTypeColor : mealTypeColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: mealTypeIcon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : mealTypeColor)
                }
                
                // Text
                Text(mealType.name?.localized() ?? "")
                    .font(.body.weight(isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color("AccentColor"))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color("AccentColor").opacity(0.05) : Color("BackgroundColor"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color("AccentColor") : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(MealTypesScaleButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Local UI Styles
struct MealTypesScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
} 
