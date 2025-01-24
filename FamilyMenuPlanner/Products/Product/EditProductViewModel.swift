//
//  EditProductViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.01.25.
//

import Foundation
import SwiftUI
import Combine

class EditProductViewModel: ObservableObject {
    @Published var product: Product
    
    @Published var selectedUnit: Unit?
    @Published var currentAlert: AlertItem?
    
    var units: [Unit]
    
    private let editProductService: EditProductService
    private let alertManager = AlertQueueManager()
    
    init(product: Product, editProductService: EditProductService) {
        self.product = product
        self.editProductService = editProductService
        self.units = editProductService.fetchAllUnits()
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }
    
    func setupSelectedUnit() {
        selectedUnit = product.unit ?? units.first
    }
    
    func rollback() {
        editProductService.rollback()
    }
    
    func saveChanges(onSuccess: ()->Void) {
        do {
            guard let name = product.name, !name.isEmpty else {
                throw NSError(domain: "com.familymenuplanner.error",
                              code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Product name cannot be empty."])
            }
            try editProductService.saveChanges()
            onSuccess()
        } catch let error as NSError {
            enqueueAlert(title: "Error", message: error.localizedDescription)
        } catch {
            enqueueAlert(title: "Error", message: "Failed to save changes. Please try again.")
        }
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
    
    private func enqueueAlert(title: String, message: String) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: nil)
        alertManager.enqueue(alert: alert)
    }
}
