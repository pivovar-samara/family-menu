//
//  ViewHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.12.24.
//

import SwiftUI

func createToolbarButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button {
        action()
    } label: {
        Label(title, systemImage: systemImage)
    }
    .foregroundColor(Color("AccentColor"))
    .tint(Color("AccentColor"))
}

struct EmptyStateModifier: ViewModifier {
    let message: String

    func body(content: Content) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            Spacer()
        }
        .listRowBackground(Color("BackgroundColor"))
        .background(Color("BackgroundColor").ignoresSafeArea())
    }
}

extension View {
    func emptyState(message: String) -> some View {
        self.modifier(EmptyStateModifier(message: message))
    }
    
    /// Prevents CoreGraphics NaN errors by validating frame dimensions
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let safeWidth = width?.isNaN == false && width?.isInfinite == false ? width : nil
        let safeHeight = height?.isNaN == false && height?.isInfinite == false ? height : nil
        
        return self.frame(
            width: safeWidth,
            height: safeHeight,
            alignment: alignment
        )
    }
}

extension List {
    func applyStyle() -> some View {
        return self
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundColor"))
    }
}

// MARK: - ViewHelper class for shared utilities
class ViewHelper {
    private init() {} // Prevent instantiation - use static methods only
}

// MARK: - Ingredient Validation Helpers
extension ViewHelper {
    /// Checks if an ingredient quantity seems unusually large based on its unit
    static func hasUnusualQuantity(_ ingredient: IngredientDetail) -> Bool {
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
    
    /// Formats ingredient quantity for display (removes decimal if whole number)
    static func formatQuantity(_ quantity: Double) -> String {
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
    
    /// Normalizes decimal separator in string for Double parsing
    /// Converts comma to period so both "1,5" and "1.5" can be parsed correctly
    static func normalizeDecimalString(_ input: String) -> String {
        return input.replacingOccurrences(of: ",", with: ".")
    }
}

// MARK: - Meal Type Styling Helpers
extension ViewHelper {
    /// Returns the appropriate icon for a meal type
    static func mealTypeIcon(for mealType: MealType) -> String {
        guard let name = mealType.name?.lowercased() else { return "fork.knife" }
        switch name {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "heart.fill"
        default: return "fork.knife"
        }
    }
    
    /// Returns the appropriate color for a meal type
    static func mealTypeColor(for mealType: MealType) -> Color {
        guard let name = mealType.name?.lowercased() else { return .orange }
        switch name {
        case "breakfast": return .orange
        case "lunch": return .yellow
        case "dinner": return .purple
        case "snack": return .pink
        default: return Color("AccentColor")
        }
    }
}


