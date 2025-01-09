//
//  NumbersHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 21.12.24.
//

import Foundation

func formattedDoubleForUnits(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? ""
}
