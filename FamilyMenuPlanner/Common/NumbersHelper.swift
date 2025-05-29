//
//  NumbersHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 21.12.24.
//

import Foundation

/// A formatter configured for consistent number formatting with 2 decimal places
private let formatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.roundingMode = .halfUp
    f.locale = Locale(identifier: "en_US")
    return f
}()

/// Formats a double value with exactly 2 decimal places using "half up" rounding
/// - Parameter value: The double value to format
/// - Returns: A string representation of the number with 2 decimal places, or "inf"/"nan" for special values
func formattedDoubleForUnits(_ value: Double) -> String {
    switch value {
    case _ where value.isInfinite, Double.greatestFiniteMagnitude:
        return "inf"
    case _ where value.isNaN:
        return "nan"
    default:
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
