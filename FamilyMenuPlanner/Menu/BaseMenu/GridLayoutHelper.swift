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
    /// - Parameter availableWidth: The width available for the grid content (after paddings are applied).
    /// - Returns: An array of `GridItem` to be used in `LazyVGrid`.
    static func columns(for availableWidth: CGFloat) -> [GridItem] {
        // Choose a reasonable minimum width for a card. If cards have internal padding
        // and look best around ~300–360pt, pick a min value that preserves readability.
        // This value can be adjusted if there is a dedicated UIConstants value elsewhere.
        let minCardWidth: CGFloat = 320
        return [
            GridItem(.adaptive(minimum: minCardWidth), spacing: UIConstants.itemSpacing, alignment: .top)
        ]
    }
}
