//
//  DataValidationHelper.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 28.01.25.
//

import Foundation
import SwiftUI

// MARK: - Data Validation Helper
/// Static utility class for data validation across the app
class DataValidationHelper {
    private init() {} // Prevent instantiation - use static methods only
}

// MARK: - Validation Issue (Moved from ReviewStepView.swift)
struct ValidationIssue {
    enum IssueType {
        case error, warning
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            }
        }
    }
    
    let type: IssueType
    let message: String
    let suggestion: String
}

// MARK: - Ingredient Validation
extension DataValidationHelper {
    /// Checks if an ingredient quantity seems unusually large based on its unit
    /// - Parameter ingredient: The ingredient to validate
    /// - Returns: True if the quantity is unusually large for the given unit
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
    
    /// Validates if a dish has all required fields
    /// - Parameter dish: The dish to validate
    /// - Returns: Array of validation issues found
    static func validateDish(_ dish: Dish) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check required fields
        if dish.name?.isEmpty ?? true {
            issues.append(ValidationIssue(
                type: .error,
                message: "Dish name is required".localized(),
                suggestion: "Add a descriptive name for your dish".localized()
            ))
        }
        
        // Check meal types
        if let mealTypes = dish.mealTypes as? Set<MealType>, mealTypes.isEmpty {
            issues.append(ValidationIssue(
                type: .error,
                message: "At least one meal type is required".localized(),
                suggestion: "Select when this dish is typically served".localized()
            ))
        }
        
        // Check ingredients - use the correct property name
        if let ingredients = dish.ingredientDetails as? Set<IngredientDetail>, ingredients.isEmpty {
            issues.append(ValidationIssue(
                type: .error,
                message: "At least one ingredient is required".localized(),
                suggestion: "Add the ingredients needed for this dish".localized()
            ))
        }
        
        return issues
    }
    
    /// Validates if a product has all required fields
    /// - Parameter product: The product to validate
    /// - Returns: Array of validation issues found
    static func validateProduct(_ product: Product) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if product.name?.isEmpty ?? true {
            issues.append(ValidationIssue(
                type: .error,
                message: "Product name is required".localized(),
                suggestion: "Add a name for this product".localized()
            ))
        }
        
        return issues
    }
}

// MARK: - String Validation
extension DataValidationHelper {
    /// Validates if a string is not empty and contains meaningful content
    /// - Parameter text: The string to validate
    /// - Returns: True if the string is valid
    static func isValidText(_ text: String?) -> Bool {
        guard let text = text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Validates if a string represents a valid number
    /// - Parameter text: The string to validate
    /// - Returns: True if the string can be converted to a number
    static func isValidNumber(_ text: String) -> Bool {
        let normalized = normalizeDecimalString(text)
        return Double(normalized) != nil
    }
    
    /// Normalizes decimal separator in string for Double parsing
    /// Converts comma to period so both "1,5" and "1.5" can be parsed correctly
    /// - Parameter input: The input string to normalize
    /// - Returns: A normalized string with period as decimal separator
    static func normalizeDecimalString(_ input: String) -> String {
        return input.replacingOccurrences(of: ",", with: ".")
    }
}

// MARK: - Quantity Validation
extension DataValidationHelper {
    /// Validates if a quantity is within reasonable bounds for a given unit
    /// - Parameters:
    ///   - quantity: The quantity to validate
    ///   - unit: The unit of measurement
    /// - Returns: True if the quantity is reasonable
    static func isReasonableQuantity(_ quantity: Double, for unit: String) -> Bool {
        let unitLower = unit.lowercased()
        
        switch unitLower {
        case "kg":
            return quantity > 0 && quantity <= 50
        case "g":
            return quantity > 0 && quantity <= 10000
        case "l":
            return quantity > 0 && quantity <= 20
        case "ml":
            return quantity > 0 && quantity <= 10000
        case "pcs", "pieces", "piece":
            return quantity > 0 && quantity <= 100
        default:
            return quantity > 0
        }
    }
    
    /// Formats ingredient quantity for display (removes decimal if whole number)
    /// - Parameter quantity: The quantity to format
    /// - Returns: A formatted string representation of the quantity
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
} 