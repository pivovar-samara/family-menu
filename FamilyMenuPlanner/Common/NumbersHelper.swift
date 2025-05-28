//
//  NumbersHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 21.12.24.
//

import Foundation

private let formatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.roundingMode = .halfUp
    f.locale = Locale(identifier: "en_US")
    return f
}()

func formattedDoubleForUnits(_ value: Double) -> String {
    if value.isInfinite || value == Double.greatestFiniteMagnitude {
        return "inf"
    }
    if value.isNaN {
        return "nan"
    }
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
}
