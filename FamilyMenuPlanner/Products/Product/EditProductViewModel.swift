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
    private let onDismiss: ((Bool) -> Void)?
    private var shouldPreventAutoDismiss = false
    
    init(product: Product? = nil, editProductService: EditProductServiceProtocol, onDismiss: ((Bool) -> Void)? = nil) {
        self.product = product
        self.isCreatingNewProduct = product == nil
        self.editProductService = editProductService
        self.onDismiss = onDismiss
        
        // Load initial units from service to ensure correct context
        self.units = editProductService.fetchAllUnits()
        // Initialize selected unit right after loading units
        self.setupSelectedUnit()
        
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
            
            // For new products, apply the pre-selected unit if one was chosen
            // This ensures new products get a sensible default unit
            if let preSelectedUnit = selectedUnit {
                updateProductUnit(preSelectedUnit)
            }
        } catch {
            AppLogger.error("Failed to create a new product", error: error, category: AppLogger.viewModel)
        }
    }
    
    func setupSelectedUnit() {
        // Handle empty units case to prevent crashes
        guard !units.isEmpty else {
            selectedUnit = nil
            return
        }
        
        // When there's no product yet (adding a new one) just pick the first unit.
        guard let product = product else {
            selectedUnit = units.first
            return
        }
        
        // When editing, mirror the product's current unit if possible
        if let currentUnit = product.unit {
            selectedUnit = findUnitInSameContext(unitName: currentUnit.name)
        } else {
            // For existing products without a unit, don't automatically assign one
            // Only set the UI state to show the first unit as a suggestion
            selectedUnit = units.first
            // DO NOT call updateProductUnit here - viewing should not modify data
        }
    }
    
    func updateProductUnit(_ newUnit: Unit?) {
        guard let product = product else { return }
        
        // Ensure we never lose the user's selection due to a context mismatch.
        if let unit = newUnit {
            if unit.managedObjectContext == product.managedObjectContext {
                // Same context – assign directly
                product.unit = unit
            } else {
                // Different context – attempt to find an equivalent Unit in the product's context
                if let equivalent = findUnitInSameContext(unitName: unit.name) {
                    product.unit = equivalent
                } else {
                    // As a last-resort keep the previous value (don't overwrite with nil)
                    AppLogger.warning("Selected unit not found in product context – keeping previous value", category: AppLogger.viewModel)
                }
            }
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
        onDismiss?(false) // Indicate user dismissed without saving
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
            onDismiss?(true) // Indicate user saved successfully
            onSuccess()
        } catch let error as NSError {
            enqueueAlert(title: "Error", message: error.localizedDescription)
        } catch {
            enqueueAlert(title: "Error", message: "Failed to save changes. Please try again.")
        }
    }
    
    /// Called when user dismisses sheet without explicit cancel - ensures rollback happens
    func dismissWithoutSaving() {
        rollback()
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
    
    private func enqueueAlert(title: String, message: String) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: nil)
        alertManager.enqueue(alert: alert)
    }
    
    /// Prevents automatic view dismissal during critical operations like text editing
    func setAutoDismissPreventionState(_ prevent: Bool) {
        shouldPreventAutoDismiss = prevent
    }
    
    // Fallback cleanup when ViewModel is deallocated
    deinit {
        AppLogger.info("🟢 EditProductViewModel deinit called - cleaning up unsaved changes", category: AppLogger.viewModel)
        // Only auto-dismiss if not prevented (e.g., during active editing)
        if !shouldPreventAutoDismiss {
            dismissWithoutSaving()
        } else {
            // Just rollback without dismissing
            editProductService.rollback()
        }
    }
}
