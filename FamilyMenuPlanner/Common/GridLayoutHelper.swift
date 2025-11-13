//
//  GridLayoutHelper.swift
//  FamilyMenuPlanner
//
//  Created by AI Assistant on 09.11.25.
//

import SwiftUI

/// A small helper to determine grid columns for the menu based on the available width.
/// Uses an adaptive grid so cards flow naturally from 1 column on compact widths
/// to multiple columns on larger screens.
struct GridLayoutHelper {
    /// Returns grid columns for a given available width.
    /// - Returns: An array of `GridItem` to be used in `LazyVGrid`.
    static func columns() -> [GridItem] {
        return [
            GridItem(.adaptive(minimum: UIConstants.minCardWidth), spacing: UIConstants.itemSpacing, alignment: .top)
        ]
    }
}
