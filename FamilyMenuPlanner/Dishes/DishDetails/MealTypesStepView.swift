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
        .background(Color.appBackground)
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
                .foregroundColor(Color.accent)
            
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
        .cardStyle(
            cornerRadius: 20,
            background: Color.appSecondaryBackground,
            shadowColor: .black.opacity(0.04),
            shadowRadius: 8,
            borderColor: Color.clear,
            borderWidth: 0,
            padding: 24
        )
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
                    .foregroundColor(Color.accent)
                    .font(.title3)
                
                Text("Meal Types".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                ChipView(
                    text: String.localizedStringWithFormat("%d selected".localized(), selectedMealTypes.count),
                    background: Color.accent.opacity(0.1),
                    font: .caption,
                    horizontalPadding: 8,
                    verticalPadding: 4,
                    cornerRadius: 8
                )
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
        default: return "fork.knife"
        }
    }
    
    private var mealTypeColor: Color {
        guard let name = mealType.name else { return Color.accent }
        return StylingHelper.mealTypeColor(for: name)
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
                    .lineLimit(1)
                    .allowsTightening(false)
                    .truncationMode(.tail)
                    .frame(minWidth: 100)
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color.accent)
                }
            }
            .cardStyle(
                cornerRadius: 16,
                background: isSelected ? Color.accent.opacity(0.05) : Color.appChipBackground,
                shadowColor: Color.clear,
                shadowRadius: 0,
                borderColor: isSelected ? Color.accent : Color.appBorder,
                borderWidth: isSelected ? 2 : 1,
                padding: 16
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("mealType" + (mealType.name?.replacingOccurrences(of: " ", with: "") ?? ""))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
} 

// MARK: - Preview

#if DEBUG
struct MealTypesGridCard_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MealTypesGridCard(mealTypes: generatePreviewMealTypes(), selectedMealTypes: Set()) { MealType in
                
            }
        }
    }
}

func generatePreviewMealTypes() -> [MealType] {
    let context = PersistenceController.preview.container.viewContext
    
    let breakfast = MealType(context: context)
    breakfast.name = "Breakfast"
    breakfast.sortOrder = 1
    
    let lunch = MealType(context: context)
    lunch.name = "Lunch"
    lunch.sortOrder = 2
    
    let dinner = MealType(context: context)
    dinner.name = "Dinner"
    dinner.sortOrder = 3
    
    return [breakfast, lunch, dinner]
}
#endif
