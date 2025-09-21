//
//  Color+App.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 20.09.25.
//

import SwiftUI
import UIKit

extension Color {
    // Fallbacks for system tints when needed
    static let appSeparator             = Color.gray.opacity(0.08)
    static let appShadow                = Color.black.opacity(0.06)
}

// MARK: - Dynamic Color Helpers
extension Color {
    /// Creates a dynamic Color that switches between light and dark hex values
    /// - Parameters:
    ///   - lightHex: Hex string for light mode, e.g. "#E2A200"
    ///   - darkHex: Hex string for dark mode, e.g. "#FFD60A"
    /// - Returns: SwiftUI Color backed by a dynamic UIColor
    static func appDynamic(lightHex: String, darkHex: String) -> Color {
        let dynamic = UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor.fromHex(hex) ?? UIColor.label
        }
        return Color(dynamic)
    }
}

private extension UIColor {
    /// Creates UIColor from hex string like "#RRGGBB" or "RRGGBB"
    static func fromHex(_ hex: String, alpha: CGFloat = 1.0) -> UIColor? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let rgb = Int(cleaned, radix: 16) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: alpha)
    }
}


