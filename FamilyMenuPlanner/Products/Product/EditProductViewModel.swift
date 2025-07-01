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
        
        // Load initial units
        self.units = StaticDataCacheManager.shared.getUnits()
        
        // Observe cache manager for units updates
        StaticDataCacheManager.shared.$units
            .receive(on: DispatchQueue.main)
            .assign(to: \.units, on: self)
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
        selectedUnit = product?.unit ?? units.first
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
