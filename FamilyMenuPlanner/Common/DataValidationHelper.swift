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
            case .error: return .appError
            case .warning: return .appWarning
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
    /// Centralized thresholds for quantity validation to avoid duplicated constants across helpers
    private struct UnitQuantityThresholds {
        let canonicalUnit: String
        let typicalMin: Double
        let typicalMax: Double
        let unusualMax: Double
        let absoluteMax: Double
    }

    /// Maps a unit string to its consolidated quantity thresholds
    /// - Parameter unit: Raw unit string (any case, may include synonyms)
    /// - Returns: Thresholds for the canonicalized unit, or nil if unknown
    private static func thresholds(for unit: String) -> UnitQuantityThresholds? {
        let u = unit.lowercased()
        switch u {
        case "kg", "kilogram", "kilograms":
            // Typical 0.5–5.0 kg, unusual >= 5.0 kg, absolute max 50 kg
            return UnitQuantityThresholds(canonicalUnit: "kg", typicalMin: 0.5, typicalMax: 5.0, unusualMax: 5.0, absoluteMax: 50)
        case "g", "gram", "grams":
            // Typical 10–2000 g, unusual >= 2000 g, absolute max 10000 g
            return UnitQuantityThresholds(canonicalUnit: "g", typicalMin: 10, typicalMax: 2000, unusualMax: 2000, absoluteMax: 10000)
        case "l", "liter", "liters", "litre", "litres":
            // Typical 0.2–3.0 l, unusual >= 3.0 l, absolute max 20 l
            return UnitQuantityThresholds(canonicalUnit: "l", typicalMin: 0.2, typicalMax: 3.0, unusualMax: 3.0, absoluteMax: 20)
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            // Typical 10–2000 ml, unusual >= 2000 ml, absolute max 10000 ml
            return UnitQuantityThresholds(canonicalUnit: "ml", typicalMin: 10, typicalMax: 2000, unusualMax: 2000, absoluteMax: 10000)
        case "pcs", "pieces", "piece":
            // Typical 1–20 pcs, unusual >= 20 pcs, absolute max 100 pcs
            return UnitQuantityThresholds(canonicalUnit: "pcs", typicalMin: 1, typicalMax: 20, unusualMax: 20, absoluteMax: 100)
        default:
            return nil
        }
    }
    /// Checks if an ingredient quantity seems unusually large based on its unit
    /// - Parameter ingredient: The ingredient to validate
    /// - Returns: True if the quantity is unusually large for the given unit
    static func hasUnusualQuantity(_ ingredient: IngredientDetail) -> Bool {
        guard let unit = ingredient.product?.unit?.name,
              let t = thresholds(for: unit) else { return false }
        let quantity = ingredient.quantity
        return quantity > t.unusualMax || quantity <= 0
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

// MARK: - Detailed Ingredient Quantity Explanation
extension DataValidationHelper {
    /// Provides a typical range for a unit to help users calibrate quantities
    /// - Parameter unit: Unit name (case-insensitive), e.g. "g", "kg", "ml", "l", "pcs"
    /// - Returns: (min, max, displayUnit) typical range; nil if unknown
    static func typicalRange(for unit: String) -> (min: Double, max: Double, unit: String)? {
        guard let t = thresholds(for: unit) else { return nil }
        return (t.typicalMin, t.typicalMax, t.canonicalUnit)
    }

    /// Builds a specific validation message when quantity seems unusual
    /// - Parameter ingredient: Ingredient to evaluate
    /// - Returns: Localized message and suggestion if unusual; otherwise nil
    static func unusualQuantityMessage(for ingredient: IngredientDetail) -> (message: String, suggestion: String)? {
        guard let productName = ingredient.product?.name,
              let unitName = ingredient.product?.unit?.name else { return nil }

        let quantity = ingredient.quantity
        let unitLower = unitName.lowercased()
        guard let range = typicalRange(for: unitLower) else { return nil }
        guard hasUnusualQuantity(ingredient) else { return nil }

        let qtyText = formatQuantity(quantity)
        let minText = formatQuantity(range.min)
        let maxText = formatQuantity(range.max)

        // "Beef quantity unusually high (600 kg). Typical range: 500–800 g"
        let message = String(
            format: "ingredient_unusual_quantity_message".localized(),
            productName.localized(), qtyText, unitName.localized(), minText, maxText, range.unit.localized()
        )
        let suggestion = "ingredient_unusual_quantity_suggestion".localized()
        return (message, suggestion)
    }
}
