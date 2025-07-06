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
    @Published var product: Product?
    @Published var isCreatingNewProduct: Bool = false
    
    @Published var selectedUnit: Unit?
    @Published var currentAlert: AlertItem?
    @Published var units: [Unit] = []
    
    private let editProductService: EditProductServiceProtocol
    private let alertManager = AlertQueueManager()
    private var cancellables = Set<AnyCancellable>()
    
    init(product: Product? = nil, editProductService: EditProductServiceProtocol) {
        self.product = product
        self.isCreatingNewProduct = product == nil
        self.editProductService = editProductService
        
        // Load initial units from service to ensure correct context
        self.units = editProductService.fetchAllUnits()
        
        // Observe cache manager for units updates and reload from service when needed
        StaticDataCacheManager.shared.$units
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reload units from service to ensure they're in the correct context
                self?.units = self?.editProductService.fetchAllUnits() ?? []
                self?.setupSelectedUnit()
            }
            .store(in: &cancellables)
        
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }
    
    func loadProduct() {
        guard product == nil else { return }
        
        do {
            try product = editProductService.createProduct()
        } catch {
            AppLogger.error("Failed to create a new product", error: error, category: AppLogger.viewModel)
        }
    }
    
    func setupSelectedUnit() {
        guard let product = product else { return }
        
        // If product has a unit, find the equivalent unit in our context
        if let currentUnit = product.unit {
            selectedUnit = findUnitInSameContext(unitName: currentUnit.name)
        } else {
            selectedUnit = units.first
        }
    }
    
    func updateProductUnit(_ newUnit: Unit?) {
        guard let product = product else { return }
        
        // Ensure the unit is in the same context as the product
        if let unit = newUnit {
            let unitInSameContext = findUnitInSameContext(unitName: unit.name)
            product.unit = unitInSameContext
        } else {
            product.unit = nil
        }
    }
    
    private func findUnitInSameContext(unitName: String?) -> Unit? {
        guard let unitName = unitName, let product = product, let context = product.managedObjectContext else {
            return nil
        }
        
        // Find unit by name in the same context as the product
        return units.first { $0.name == unitName && $0.managedObjectContext == context }
    }
    
    func rollback() {
        editProductService.rollback()
    }
    
    func saveChanges(onSuccess: ()->Void) {
        do {
            guard let name = product?.name, !name.isEmpty else {
                enqueueAlert(title: "Error", message: "Product name cannot be empty.")
                return
            }
            
            // Mark product as complete when successfully saved
            product?.isDraft = false
            
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
