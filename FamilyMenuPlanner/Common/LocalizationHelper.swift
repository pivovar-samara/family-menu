//
//  LocalizationHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.12.24.
//

import SwiftUI

public extension String {
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}
