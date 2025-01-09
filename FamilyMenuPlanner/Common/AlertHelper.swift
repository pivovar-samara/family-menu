//
//  AlertHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct AlertHelper {
    static func presentAlert(title: LocalizedStringKey, message: LocalizedStringKey) -> Alert {
        Alert(
            title: Text(title),
            message: Text(message),
            dismissButton: .default(Text("OK"))
        )
    }
}



