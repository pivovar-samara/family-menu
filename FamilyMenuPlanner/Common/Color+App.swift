//
//  Color+App.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 20.09.25.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Button/Chip State Color Tokens
    /// Unified color tokens for button and chip states
    struct ButtonState {
        // Primary button states
        static let primaryDefault       = Color.accent
        static let primaryPressed       = Color.accent.opacity(0.8)
        static let primaryDisabled     = Color.gray.opacity(0.3)
        static let primarySelected     = Color.accent
        
        // Secondary button states
        static let secondaryDefault     = Color.accent.opacity(0.1)
        static let secondaryPressed     = Color.accent.opacity(0.2)
        static let secondaryDisabled   = Color.gray.opacity(0.1)
        static let secondarySelected   = Color.accent.opacity(0.15)
        
        // Chip states
        static let chipDefault          = Color.appChipBackground
        static let chipPressed          = Color.appChipBackground.opacity(0.8)
        static let chipDisabled         = Color.gray.opacity(0.1)
        static let chipSelected         = Color.accent
        
        // Text colors for different states
        static let textDefault          = Color.primary
        static let textPressed          = Color.primary
        static let textDisabled         = Color.secondary
        static let textSelected         = Color.white
        
        // Border colors for different states
        static let borderDefault        = Color.appBorder
        static let borderPressed        = Color.appBorder
        static let borderDisabled       = Color.gray.opacity(0.2)
        static let borderSelected       = Color.clear
    }
    
    // MARK: - Utility Colors
    static let appSeparator             = Color.gray.opacity(0.08)
    static let appShadow                = Color.black.opacity(0.06)
}

