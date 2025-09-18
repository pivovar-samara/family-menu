//
//  StaticKeyHelper.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 10.09.25.
//

import Foundation

enum StaticKeyHelper {
    /// Generates a stable key from a human readable name.
    /// - The transformation is case-insensitive, diacritic-insensitive, and width-insensitive.
    /// - Non-alphanumeric characters are converted to '-'.
    /// - Consecutive '-' are collapsed.
    static func stableKey(from name: String) -> String {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let folded = lower.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let replaced: [Character] = folded.map { ch in
            let s = String(ch)
            return s.rangeOfCharacter(from: allowed.inverted) != nil ? "-" : ch
        }
        let key = String(replaced).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return key.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Generates a composite product key from product name and an optional unit key.
    /// If unitKey is nil or empty, falls back to just name-based key.
    static func productKey(name: String, unitKey: String?) -> String {
        let nameKey = stableKey(from: name)
        guard let unitKey, !unitKey.isEmpty else { return nameKey }
        return nameKey + "|" + unitKey
    }
}


