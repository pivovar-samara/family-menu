//
//  StylingHelper.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 28.01.25.
//

import SwiftUI

// MARK: - Styling Helper
/// Static utility class for styling and theming across the app
class StylingHelper {
    private init() {} // Prevent instantiation - use static methods only
}

// MARK: - Meal Type Styling
extension StylingHelper {
    /// Returns the appropriate icon for a meal type
    /// - Parameter mealType: The meal type object
    /// - Returns: SF Symbol name for the meal type icon
    static func mealTypeIcon(for mealType: MealType) -> String {
        guard let name = mealType.name?.lowercased() else { return "fork.knife" }
        return mealTypeIcon(for: name)
    }
    
    /// Returns the appropriate color for a meal type
    /// - Parameter mealType: The meal type object
    /// - Returns: Color for the meal type
    static func mealTypeColor(for mealType: MealType) -> Color {
        guard let name = mealType.name?.lowercased() else { return .orange }
        return mealTypeColor(for: name)
    }
    
    /// Returns the appropriate icon for a meal type string
    /// - Parameter mealTypeName: The meal type name string
    /// - Returns: SF Symbol name for the meal type icon
    static func mealTypeIcon(for mealTypeName: String) -> String {
        let name = mealTypeName.lowercased()
        switch name {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        default: return "fork.knife"
        }
    }
    
    /// Returns the appropriate color for a meal type string
    /// - Parameter mealTypeName: The meal type name string
    /// - Returns: Color for the meal type
    static func mealTypeColor(for mealTypeName: String) -> Color {
        let name = mealTypeName.lowercased()
        switch name {
        case "breakfast": return Color.appWarning
        case "lunch": return .yellow
        case "dinner": return .purple
        default: return Color.accent
        }
    }
}

// MARK: - Category Styling
extension StylingHelper {
    /// Returns the appropriate color for a dish category
    /// - Parameter categoryName: The category name
    /// - Returns: Color for the category
    static func categoryColor(for categoryName: String) -> Color {
        switch categoryName.lowercased() {
        case "main course", "main":
            return .blue
        case "garnish", "side":
            return .green
        case "dessert":
            return .orange
        case "appetizer", "starter":
            return .purple
        case "sauce", "dressing":
            return .red
        case "soup":
            return .brown
        case "salad":
            return .mint
        default:
            return .gray
        }
    }
    
    /// Returns the appropriate icon for a dish category
    /// - Parameter categoryName: The category name
    /// - Returns: SF Symbol name for the category icon
    static func categoryIcon(for categoryName: String) -> String {
        switch categoryName.lowercased() {
        case "main course", "main":
            return "fork.knife"
        case "garnish", "side":
            return "leaf"
        case "dessert":
            return "birthday.cake"
        case "appetizer", "starter":
            return "tray"
        case "sauce", "dressing":
            return "drop"
        case "soup":
            return "bowl"
        case "salad":
            return "leaf.circle"
        default:
            return "circle"
        }
    }
}

// MARK: - Unit Styling
extension StylingHelper {
    /// Returns the appropriate color for a unit of measurement
    /// - Parameter unitName: The unit name
    /// - Returns: Color for the unit
    static func unitColor(for unitName: String) -> Color {
        switch unitName.lowercased() {
        case "kg", "g":
            return .blue
        case "l", "ml":
            return .cyan
        case "pcs", "pieces", "piece":
            return .green
        case "tbsp", "tablespoon":
            return .orange
        case "tsp", "teaspoon":
            return .yellow
        case "cup", "cups":
            return .purple
        default:
            return Color.accent
        }
    }
    
    /// Returns the appropriate icon for a unit of measurement
    /// - Parameter unitName: The unit name
    /// - Returns: SF Symbol name for the unit icon
    static func unitIcon(for unitName: String) -> String {
        switch unitName.lowercased() {
        case "kg", "g":
            return "scalemass"
        case "l", "ml":
            return "drop"
        case "pcs", "pieces", "piece":
            return "number.circle"
        case "tbsp", "tablespoon":
            return "spoon"
        case "tsp", "teaspoon":
            return "spoon"
        case "cup", "cups":
            return "cup.and.saucer"
        default:
            return "ruler"
        }
    }
}

// MARK: - Status Styling
extension StylingHelper {
    /// Returns styling for validation status
    /// - Parameter isValid: Whether the validation passed
    /// - Returns: Tuple with color and icon
    static func validationStatus(isValid: Bool) -> (color: Color, icon: String) {
        if isValid {
            return (Color.appSuccess, "checkmark.circle.fill")
        } else {
            return (Color.appError, "xmark.circle.fill")
        }
    }
    
    /// Returns styling for completion status
    /// - Parameter isCompleted: Whether the item is completed
    /// - Returns: Tuple with color and icon
    static func completionStatus(isCompleted: Bool) -> (color: Color, icon: String) {
        if isCompleted {
            return (Color.appSuccess, "checkmark.circle.fill")
        } else {
            return (.gray, "circle")
        }
    }
}

// MARK: - Gradient Helpers
extension StylingHelper {
    /// Creates a subtle gradient for cards
    /// - Parameter baseColor: The base color for the gradient
    /// - Returns: A linear gradient
    static func cardGradient(baseColor: Color) -> LinearGradient {
        LinearGradient(
            colors: [baseColor.opacity(0.1), baseColor.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Creates a gradient for selected states
    /// - Parameter baseColor: The base color for the gradient
    /// - Returns: A linear gradient
    static func selectedGradient(baseColor: Color) -> LinearGradient {
        LinearGradient(
            colors: [baseColor, baseColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Animation Helpers
extension StylingHelper {
    /// Standard animation for UI interactions
    static let standardAnimation = Animation.easeInOut(duration: 0.2)
    
    /// Fast animation for immediate feedback
    static let fastAnimation = Animation.easeInOut(duration: 0.1)
    
    /// Slow animation for major transitions
    static let slowAnimation = Animation.easeInOut(duration: 0.4)
    
    /// Spring animation for bouncy effects
    static let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
} 
